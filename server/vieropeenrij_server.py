#!/usr/bin/env python3
"""
vieropeenrij_server.py - relay server for the Toon app "Vier op een rij" (opponent mode "Server").

Same protocol as vieropeenrij.php, for a Raspberry Pi or any machine with Python 3 (no packages needed):

    python3 vieropeenrij_server.py [--port 8642] [--dir rooms]

Enter http://<host>:8642/ as server address in the app on every Toon. Players who choose the same room
play against each other.

    GET  /?room=<naam>          -> current game of the room as JSON ({} when empty)
    POST /?room=<naam>  <json>  -> merges the posted game into the room, answers with the result

The merge rule is the one the Toons use themselves (see vieropeenrij.js): a game with a newer
timestamp replaces an older one, within a game a longer move list that extends the stored one is
accepted, and the free yellow seat goes to the first player who claims it.
"""

import argparse
import json
import os
import re
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

ROWS = 6
COLS = 7
ROOM_MAX_AGE = 30 * 24 * 3600

lock = threading.Lock()


def clean_player(p):
    if not isinstance(p, dict):
        return {"id": "", "name": ""}
    pid = p.get("id")
    name = p.get("name")
    return {
        "id": pid[:32] if isinstance(pid, str) else "",
        "name": name[:32] if isinstance(name, str) else "",
    }


def replay_valid(moves, first_is_yellow):
    board = [0] * (ROWS * COLS)
    current = 2 if first_is_yellow else 1
    dirs = ((0, 1), (1, 0), (1, 1), (1, -1))
    for i, ch in enumerate(moves):
        col = ord(ch) - 48
        if col < 0 or col >= COLS:
            return False
        row = next((r for r in range(ROWS - 1, -1, -1) if board[r * COLS + col] == 0), -1)
        if row < 0:
            return False
        board[row * COLS + col] = current
        for dr, dc in dirs:
            count = 1
            for s in (-1, 1):
                r, c = row + dr * s, col + dc * s
                while 0 <= r < ROWS and 0 <= c < COLS and board[r * COLS + c] == current:
                    count += 1
                    r += dr * s
                    c += dc * s
            if count >= 4:
                return i == len(moves) - 1
        current = 3 - current
    return True


def sanitize(raw):
    if not isinstance(raw, dict):
        return None
    gid = raw.get("id")
    if not isinstance(gid, str) or gid == "" or len(gid) > 40:
        return None
    try:
        ts = float(raw.get("ts"))
    except (TypeError, ValueError):
        return None
    if not ts > 0:
        return None
    moves = raw.get("moves")
    if not isinstance(moves, str) or len(moves) > ROWS * COLS or not re.match(r"^[0-6]*$", moves):
        return None
    first = "yellow" if raw.get("first") == "yellow" else "red"
    if not replay_valid(moves, first == "yellow"):
        return None
    return {
        "v": 1,
        "id": gid,
        "ts": ts,
        "red": clean_player(raw.get("red")),
        "yellow": clean_player(raw.get("yellow")),
        "first": first,
        "moves": moves,
    }


def same_game(a, b):
    return a["id"] == b["id"] and a["ts"] == b["ts"] and a["red"]["id"] == b["red"]["id"]


def merge(local, remote):
    remote = sanitize(remote)
    if remote is None:
        return None
    if local is None:
        return remote
    if not same_game(local, remote):
        if remote["ts"] > local["ts"]:
            return remote
        if remote["ts"] == local["ts"] and remote["id"] > local["id"]:
            return remote
        return None

    changed = False
    result = dict(local)
    if local["yellow"]["id"] == "" and remote["yellow"]["id"] != "":
        result["yellow"] = remote["yellow"]
        changed = True
    elif local["yellow"]["id"] != "" and remote["yellow"]["id"] == local["yellow"]["id"] and remote["yellow"]["name"] != local["yellow"]["name"]:
        result["yellow"] = remote["yellow"]
        changed = True
    if remote["red"]["id"] == local["red"]["id"] and remote["red"]["name"] != local["red"]["name"]:
        result["red"] = remote["red"]
        changed = True
    if len(remote["moves"]) > len(local["moves"]) and remote["moves"].startswith(local["moves"]):
        result["moves"] = remote["moves"]
        changed = True
    return result if changed else None


class Handler(BaseHTTPRequestHandler):
    rooms_dir = "rooms"

    def log_message(self, fmt, *args):
        pass

    def room_file(self):
        query = parse_qs(urlparse(self.path).query)
        room = query.get("room", [""])[0]
        room = re.sub(r"[^A-Za-z0-9_-]", "", room).lower()
        if room == "" or len(room) > 32:
            return None
        return os.path.join(self.rooms_dir, room + ".json")

    def load(self, path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                return sanitize(json.load(f))
        except (OSError, ValueError):
            return None

    def reply(self, code, obj):
        body = json.dumps(obj if obj is not None else {}).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        path = self.room_file()
        if path is None:
            return self.reply(400, {"error": "room ontbreekt"})
        with lock:
            self.reply(200, self.load(path))

    def do_POST(self):
        path = self.room_file()
        if path is None:
            return self.reply(400, {"error": "room ontbreekt"})
        length = int(self.headers.get("Content-Length") or 0)
        try:
            remote = json.loads(self.rfile.read(length).decode("utf-8")) if length else None
        except ValueError:
            remote = None
        with lock:
            stored = self.load(path)
            merged = merge(stored, remote)
            if merged is not None:
                stored = merged
                os.makedirs(self.rooms_dir, exist_ok=True)
                with open(path, "w", encoding="utf-8") as f:
                    json.dump(stored, f)
            self.reply(200, stored)
        prune_rooms(self.rooms_dir)

    do_PUT = do_POST


_last_prune = [0.0]


def prune_rooms(rooms_dir):
    now = time.time()
    if now - _last_prune[0] < 3600:
        return
    _last_prune[0] = now
    try:
        for name in os.listdir(rooms_dir):
            path = os.path.join(rooms_dir, name)
            if name.endswith(".json") and now - os.path.getmtime(path) > ROOM_MAX_AGE:
                os.remove(path)
    except OSError:
        pass


def main():
    parser = argparse.ArgumentParser(description="Relay server for the Toon app Vier op een rij")
    parser.add_argument("--port", type=int, default=8642)
    parser.add_argument("--dir", default="rooms", help="directory for the room files")
    parser.add_argument("--bind", default="0.0.0.0")
    args = parser.parse_args()

    Handler.rooms_dir = args.dir
    os.makedirs(args.dir, exist_ok=True)
    server = ThreadingHTTPServer((args.bind, args.port), Handler)
    print("vieropeenrij server op http://%s:%d/  (kamers in %s)" % (args.bind, args.port, args.dir))
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
