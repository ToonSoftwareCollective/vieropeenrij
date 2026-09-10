<?php
/*
 * vieropeenrij.php - relay server for the Toon app "Vier op een rij" (opponent mode "Server").
 *
 * Put this file on any web server with PHP (5.4 or newer, no database needed) and enter its URL in
 * the app's settings on every Toon. Players who choose the same room name play against each other.
 *
 *   GET  vieropeenrij.php?room=<naam>          -> current game of the room as JSON ({} when empty)
 *   POST vieropeenrij.php?room=<naam>  <json>  -> merges the posted game into the room, answers with the result
 *
 * The merge rule is the same one the Toons use (see vieropeenrij.js): a game with a newer timestamp
 * replaces an older one, within a game a longer move list that extends the stored one is accepted,
 * and the free yellow seat goes to the first player who claims it. Rooms are files in ./rooms/.
 */

$ROWS = 6;
$COLS = 7;
$roomsDir = __DIR__ . '/rooms';
$roomMaxAge = 30 * 24 * 3600;		// rooms untouched for a month are removed

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('Access-Control-Allow-Origin: *');

$room = isset($_GET['room']) ? strtolower(preg_replace('/[^A-Za-z0-9_-]/', '', $_GET['room'])) : '';
if ($room === '' || strlen($room) > 32) {
	http_response_code(400);
	echo '{"error":"room ontbreekt"}';
	exit;
}

if (!is_dir($roomsDir)) {
	mkdir($roomsDir, 0775, true);
}

$file = "$roomsDir/$room.json";
$fp = fopen($file, 'c+');
if ($fp === false) {
	http_response_code(500);
	echo '{"error":"kan kamer niet opslaan"}';
	exit;
}
flock($fp, LOCK_EX);
$stored = sanitize(json_decode(stream_get_contents($fp), true));

$method = $_SERVER['REQUEST_METHOD'];
if ($method === 'POST' || $method === 'PUT') {
	$remote = json_decode(file_get_contents('php://input'), true);
	$merged = merge($stored, $remote);
	if ($merged !== null) {
		$stored = $merged;
		ftruncate($fp, 0);
		rewind($fp);
		fwrite($fp, json_encode($stored));
		fflush($fp);
	}
}
flock($fp, LOCK_UN);
fclose($fp);

echo ($stored === null) ? '{}' : json_encode($stored);

if (mt_rand(1, 50) === 1) {
	pruneRooms($roomsDir, $roomMaxAge);
}
exit;

// ---------------------------------------------------------------------------------------------

function cleanPlayer($p) {
	if (!is_array($p)) return array('id' => '', 'name' => '');
	return array(
		'id' => isset($p['id']) && is_string($p['id']) ? substr($p['id'], 0, 32) : '',
		'name' => isset($p['name']) && is_string($p['name']) ? substr($p['name'], 0, 32) : ''
	);
}

// plays the move string on an empty board; false when a move is impossible or follows a finished game
function replayValid($moves, $firstIsYellow) {
	global $ROWS, $COLS;
	$board = array_fill(0, $ROWS * $COLS, 0);
	$current = $firstIsYellow ? 2 : 1;
	$dirs = array(array(0, 1), array(1, 0), array(1, 1), array(1, -1));

	for ($i = 0; $i < strlen($moves); $i++) {
		$col = ord($moves[$i]) - 48;
		if ($col < 0 || $col >= $COLS) return false;
		$row = -1;
		for ($r = $ROWS - 1; $r >= 0; $r--) {
			if ($board[$r * $COLS + $col] === 0) { $row = $r; break; }
		}
		if ($row < 0) return false;
		$board[$row * $COLS + $col] = $current;

		// a win ends the game: any further move is invalid
		foreach ($dirs as $d) {
			$count = 1;
			for ($s = -1; $s <= 1; $s += 2) {
				$r = $row + $d[0] * $s;
				$c = $col + $d[1] * $s;
				while ($r >= 0 && $r < $ROWS && $c >= 0 && $c < $COLS && $board[$r * $COLS + $c] === $current) {
					$count++;
					$r += $d[0] * $s;
					$c += $d[1] * $s;
				}
			}
			if ($count >= 4) return $i === strlen($moves) - 1;
		}
		$current = 3 - $current;
	}
	return true;
}

function sanitize($raw) {
	global $ROWS, $COLS;
	if (!is_array($raw)) return null;
	if (!isset($raw['id']) || !is_string($raw['id']) || $raw['id'] === '' || strlen($raw['id']) > 40) return null;
	if (!isset($raw['ts']) || !is_numeric($raw['ts']) || $raw['ts'] <= 0) return null;
	if (!isset($raw['moves']) || !is_string($raw['moves']) || strlen($raw['moves']) > $ROWS * $COLS || !preg_match('/^[0-6]*$/', $raw['moves'])) return null;
	$first = (isset($raw['first']) && $raw['first'] === 'yellow') ? 'yellow' : 'red';
	if (!replayValid($raw['moves'], $first === 'yellow')) return null;
	return array(
		'v' => 1,
		'id' => $raw['id'],
		'ts' => (float)$raw['ts'],
		'red' => cleanPlayer(isset($raw['red']) ? $raw['red'] : null),
		'yellow' => cleanPlayer(isset($raw['yellow']) ? $raw['yellow'] : null),
		'first' => $first,
		'moves' => $raw['moves']
	);
}

function sameGame($a, $b) {
	return $a['id'] === $b['id'] && $a['ts'] == $b['ts'] && $a['red']['id'] === $b['red']['id'];
}

// returns the state to keep, or null when the posted state changes nothing
function merge($local, $remote) {
	$remote = sanitize($remote);
	if ($remote === null) return null;
	if ($local === null) return $remote;

	if (!sameGame($local, $remote)) {
		if ($remote['ts'] > $local['ts']) return $remote;
		if ($remote['ts'] == $local['ts'] && strcmp($remote['id'], $local['id']) > 0) return $remote;
		return null;
	}

	$changed = false;
	$result = $local;
	if ($local['yellow']['id'] === '' && $remote['yellow']['id'] !== '') {
		$result['yellow'] = $remote['yellow'];
		$changed = true;
	} else if ($local['yellow']['id'] !== '' && $remote['yellow']['id'] === $local['yellow']['id'] && $remote['yellow']['name'] !== $local['yellow']['name']) {
		$result['yellow'] = $remote['yellow'];
		$changed = true;
	}
	if ($remote['red']['id'] === $local['red']['id'] && $remote['red']['name'] !== $local['red']['name']) {
		$result['red'] = $remote['red'];
		$changed = true;
	}
	$ll = strlen($local['moves']);
	if (strlen($remote['moves']) > $ll && substr($remote['moves'], 0, $ll) === $local['moves']) {
		$result['moves'] = $remote['moves'];
		$changed = true;
	}
	return $changed ? $result : null;
}

function pruneRooms($dir, $maxAge) {
	$now = time();
	foreach (glob("$dir/*.json") as $f) {
		if ($now - filemtime($f) > $maxAge) @unlink($f);
	}
}
