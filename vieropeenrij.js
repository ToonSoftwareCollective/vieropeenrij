.pragma library

	// Vier op een rij: spelregels en de computerspeler (negamax met alpha-beta pruning).
	// The board is a flat array of ROWS * COLS cells, index = row * COLS + col, row 0 is the top row.

var ROWS = 6;
var COLS = 7;

var EMPTY = 0;
var RED = 1;		// the first colour; against the computer the human always plays red
var YELLOW = 2;
var HUMAN = RED;		// older names, still used by the computer player
var COMPUTER = YELLOW;

	// game states
var RUNNING = 0;
var RED_WON = 1;
var YELLOW_WON = 2;
var DRAW = 3;
var HUMAN_WON = RED_WON;
var COMPUTER_WON = YELLOW_WON;

	// opponent modes
var MODE_COMPUTER = 0;		// against Toon
var MODE_PEER = 1;			// against another Toon in the same network
var MODE_SERVER = 2;		// against anyone, via a relay server on the internet

	// name of the file each Toon publishes through its own lighttpd (document root /qmf/www)
var PEER_FILE = "vieropeenrij.json";

	// difficulty levels
var LEVEL_EASY = 1;
var LEVEL_NORMAL = 2;
var LEVEL_HARD = 3;

var WIN_SCORE = 1000000;

	// every possible line of four cells on the board (horizontal, vertical, both diagonals),
	// as arrays of cell indices. Built once when the library is loaded.
var WINDOWS = buildWindows();

function buildWindows() {
	var windows = [];
	for (var r = 0; r < ROWS; r++) {
		for (var c = 0; c < COLS; c++) {
			if (c + 3 < COLS) windows.push(line(r, c, 0, 1));
			if (r + 3 < ROWS) windows.push(line(r, c, 1, 0));
			if (r + 3 < ROWS && c + 3 < COLS) windows.push(line(r, c, 1, 1));
			if (r + 3 < ROWS && c - 3 >= 0) windows.push(line(r, c, 1, -1));
		}
	}
	return windows;
}

function line(row, col, dr, dc) {
	var cells = [];
	for (var i = 0; i < 4; i++) cells.push((row + dr * i) * COLS + (col + dc * i));
	return cells;
}

function newBoard() {
	var board = [];
	for (var i = 0; i < ROWS * COLS; i++) board.push(EMPTY);
	return board;
}

function other(player) {
	return (player === HUMAN) ? COMPUTER : HUMAN;
}

	// row the disc lands on when dropped in this column, -1 when the column is full
function dropRow(board, col) {
	for (var r = ROWS - 1; r >= 0; r--) {
		if (board[r * COLS + col] === EMPTY) return r;
	}
	return -1;
}

	// drops a disc in the column; returns the row it landed on, -1 when the column is full
function drop(board, col, player) {
	var row = dropRow(board, col);
	if (row >= 0) board[row * COLS + col] = player;
	return row;
}

function isFull(board) {
	for (var c = 0; c < COLS; c++) {
		if (board[c] === EMPTY) return false;
	}
	return true;
}

	// playable columns, centre first: trying the strongest columns first makes the pruning far more effective
function validMoves(board, order) {
	var moves = [];
	for (var i = 0; i < order.length; i++) {
		if (board[order[i]] === EMPTY) moves.push(order[i]);
	}
	return moves;
}

var CENTRE_FIRST = [3, 2, 4, 1, 5, 0, 6];

	// same as CENTRE_FIRST, but mirrored columns in random order, so the computer does not
	// always open identically in symmetric positions
function shuffledOrder() {
	var order = [3];
	var pairs = [[2, 4], [1, 5], [0, 6]];
	for (var i = 0; i < pairs.length; i++) {
		if (Math.random() < 0.5) {
			order.push(pairs[i][0]); order.push(pairs[i][1]);
		} else {
			order.push(pairs[i][1]); order.push(pairs[i][0]);
		}
	}
	return order;
}

	// the cells of a line of four (or more) through the disc at row/col, or null if there is none
function winningLine(board, row, col) {
	var player = board[row * COLS + col];
	if (player === EMPTY) return null;

	var dirs = [[0, 1], [1, 0], [1, 1], [1, -1]];
	for (var d = 0; d < dirs.length; d++) {
		var dr = dirs[d][0];
		var dc = dirs[d][1];
		var cells = [row * COLS + col];

		var r = row + dr;
		var c = col + dc;
		while (r >= 0 && r < ROWS && c >= 0 && c < COLS && board[r * COLS + c] === player) {
			cells.push(r * COLS + c);
			r += dr;
			c += dc;
		}
		r = row - dr;
		c = col - dc;
		while (r >= 0 && r < ROWS && c >= 0 && c < COLS && board[r * COLS + c] === player) {
			cells.push(r * COLS + c);
			r -= dr;
			c -= dc;
		}
		if (cells.length >= 4) return cells;
	}
	return null;
}

	// heuristic value of the position seen from 'player'; only used at the search horizon
function evaluate(board, player) {
	var opp = other(player);
	var score = 0;

	for (var i = 0; i < WINDOWS.length; i++) {
		var w = WINDOWS[i];
		var mine = 0;
		var theirs = 0;
		for (var j = 0; j < 4; j++) {
			var v = board[w[j]];
			if (v === player) mine++;
			else if (v === opp) theirs++;
		}
		if (mine > 0 && theirs > 0) continue;		// blocked window, worthless for both

		if (mine === 3) score += 50;
		else if (mine === 2) score += 5;
		else if (mine === 1) score += 1;
		else if (theirs === 3) score -= 60;
		else if (theirs === 2) score -= 5;
		else if (theirs === 1) score -= 1;
	}

		// discs in the centre column take part in the most lines
	for (var r = 0; r < ROWS; r++) {
		var m = board[r * COLS + 3];
		if (m === player) score += 3;
		else if (m === opp) score -= 3;
	}
	return score;
}

function negamax(board, depth, alpha, beta, player) {
	var moves = validMoves(board, CENTRE_FIRST);
	if (moves.length === 0) return 0;						// board full: draw
	if (depth === 0) return evaluate(board, player);

	var best = -Infinity;
	for (var i = 0; i < moves.length; i++) {
		var col = moves[i];
		var row = dropRow(board, col);
		var cell = row * COLS + col;
		board[cell] = player;

		var value;
		if (winningLine(board, row, col)) value = WIN_SCORE + depth;	// prefer the quickest win
		else value = -negamax(board, depth - 1, -beta, -alpha, other(player));

		board[cell] = EMPTY;

		if (value > best) best = value;
		if (value > alpha) alpha = value;
		if (alpha >= beta) break;
	}
	return best;
}

	// best column for 'player' looking 'depth' half-moves ahead; -1 if there is no move
function bestMove(board, player, depth) {
	var work = board.slice();
	var moves = validMoves(work, shuffledOrder());
	if (moves.length === 0) return -1;

	var bestCol = moves[0];
	var alpha = -Infinity;
	for (var i = 0; i < moves.length; i++) {
		var col = moves[i];
		var row = dropRow(work, col);
		var cell = row * COLS + col;
		work[cell] = player;

		var value;
		if (winningLine(work, row, col)) value = WIN_SCORE + depth;
		else value = -negamax(work, depth - 1, -Infinity, -alpha, other(player));

		work[cell] = EMPTY;

		if (value > alpha) {
			alpha = value;
			bestCol = col;
		}
	}
	return bestCol;
}

function searchDepth(level) {
	switch (level) {
		case LEVEL_EASY: return 2;
		case LEVEL_HARD: return 6;
		default: return 4;
	}
}

function levelName(level) {
	switch (level) {
		case LEVEL_EASY: return "Makkelijk";
		case LEVEL_HARD: return "Moeilijk";
		default: return "Normaal";
	}
}

function modeName(mode) {
	switch (mode) {
		case MODE_PEER: return "Andere Toon";
		case MODE_SERVER: return "Server";
		default: return "Toon (computer)";
	}
}

	// the computer's move for the given difficulty level; -1 if the board is full
function chooseMove(board, player, level) {
	var moves = validMoves(board, CENTRE_FIRST);
	if (moves.length === 0) return -1;

		// on the easiest level the computer plays a random disc now and then
	if (level === LEVEL_EASY && Math.random() < 0.3) {
		return moves[Math.floor(Math.random() * moves.length)];
	}
	return bestMove(board, player, searchDepth(level));
}

	// ---------------------------------------------------------------------------------------------
	// A game as exchanged between two Toons (or a Toon and the relay server):
	//
	//   { v: 1, id: "1725970000000-4f2a", ts: 1725970000000,
	//     red: {id: "a1b2c3d4", name: "Toon woonkamer"}, yellow: {id: "...", name: "..."},
	//     first: "red" | "yellow",
	//     moves: "3341" }
	//
	// 'moves' is the column of every disc played so far, in order. Whose turn it is follows from the
	// length of that string and 'first'. The state is deliberately self-contained: both sides
	// replay it from scratch, so nothing can get out of step. Whoever presses "Nieuw spel"
	// creates a game (with a fresh id and timestamp) and plays red; the other side joins as yellow.
	// ---------------------------------------------------------------------------------------------

var PROTOCOL_VERSION = 1;

function firstPlayer(state) {
	return (state && state.first === "yellow") ? YELLOW : RED;
}

	// player whose turn it is after 'moves' when 'first' started
function playerToMove(moves, first) {
	return (moves.length % 2 === 0) ? first : other(first);
}

	// plays the move string on an empty board. Returns {valid, board, lastCell, winCells, state, current}.
	// 'valid' is false when a move is out of range, drops in a full column or follows a finished game.
function replay(moves, first) {
	var board = newBoard();
	var result = {valid: true, board: board, lastCell: -1, winCells: [], state: RUNNING, current: first};

	for (var i = 0; i < moves.length; i++) {
		var col = moves.charCodeAt(i) - 48;
		if (result.state !== RUNNING || col < 0 || col >= COLS) {
			result.valid = false;
			return result;
		}
		var row = drop(board, col, result.current);
		if (row < 0) {
			result.valid = false;
			return result;
		}
		result.lastCell = row * COLS + col;

		var cells = winningLine(board, row, col);
		if (cells) {
			result.winCells = cells;
			result.state = (result.current === RED) ? RED_WON : YELLOW_WON;
		} else if (isFull(board)) {
			result.state = DRAW;
		} else {
			result.current = other(result.current);
		}
	}
	return result;
}

function randomId(length) {
	var chars = "abcdefghijklmnopqrstuvwxyz0123456789";
	var id = "";
	for (var i = 0; i < length; i++) id += chars.charAt(Math.floor(Math.random() * chars.length));
	return id;
}

	// a fresh game created by player {id, name}, who plays red
function newNetGame(creator, creatorStarts, now) {
	var ts = now || Date.now();
	return {
		v: PROTOCOL_VERSION,
		id: ts + "-" + randomId(4),
		ts: ts,
		red: {id: creator.id, name: creator.name},
		yellow: {id: "", name: ""},
		first: creatorStarts ? "red" : "yellow",
		moves: ""
	};
}

function emptyNetGame() {
	return {v: PROTOCOL_VERSION, id: "", ts: 0, red: {id: "", name: ""}, yellow: {id: "", name: ""}, first: "red", moves: ""};
}

function cleanPlayer(p) {
	if (!p || typeof p !== "object") return {id: "", name: ""};
	return {
		id: (typeof p.id === "string") ? p.id.substring(0, 32) : "",
		name: (typeof p.name === "string") ? p.name.substring(0, 32) : ""
	};
}

	// checks a state received from the network and returns a clean copy, or null when it is unusable
function sanitize(raw) {
	if (!raw || typeof raw !== "object") return null;
	if (typeof raw.id !== "string" || raw.id.length === 0 || raw.id.length > 40) return null;
	var ts = Number(raw.ts);
	if (!isFinite(ts) || ts <= 0) return null;
	if (typeof raw.moves !== "string" || raw.moves.length > ROWS * COLS || !/^[0-6]*$/.test(raw.moves)) return null;
	var first = (raw.first === "yellow") ? "yellow" : "red";
	if (!replay(raw.moves, (first === "yellow") ? YELLOW : RED).valid) return null;
	return {
		v: PROTOCOL_VERSION,
		id: raw.id,
		ts: ts,
		red: cleanPlayer(raw.red),
		yellow: cleanPlayer(raw.yellow),
		first: first,
		moves: raw.moves
	};
}

function sameGame(a, b) {
	return a && b && a.id === b.id && a.ts === b.ts && a.red.id === b.red.id;
}

	// Decides what to keep when 'local' (what we have) meets 'remote' (what the other side or the
	// server has). Returns the state to continue with, or null when nothing changes. The same rule
	// runs on the relay server, so all parties converge:
	//   - a game with a newer timestamp replaces an older one (someone pressed "Nieuw spel")
	//   - within a game, a move list that extends ours is accepted (the other side has moved)
	//   - within a game, the yellow seat is filled by the first one to claim it
function merge(local, remote) {
	remote = sanitize(remote);
	if (!remote) return null;
	if (!local || !local.id) return remote;

	if (!sameGame(local, remote)) {
		if (remote.ts > local.ts) return remote;
		if (remote.ts === local.ts && remote.id > local.id) return remote;	// tie-break, both created at the same ms
		return null;
	}

	var changed = false;
	var result = {v: PROTOCOL_VERSION, id: local.id, ts: local.ts, red: local.red, yellow: local.yellow, first: local.first, moves: local.moves};

	if (!local.yellow.id && remote.yellow.id) {
		result.yellow = remote.yellow;
		changed = true;
	} else if (local.yellow.id && remote.yellow.id === local.yellow.id && remote.yellow.name !== local.yellow.name) {
		result.yellow = remote.yellow;
		changed = true;
	}
	if (remote.red.id === local.red.id && remote.red.name !== local.red.name) {
		result.red = remote.red;
		changed = true;
	}
	if (remote.moves.length > local.moves.length && remote.moves.substring(0, local.moves.length) === local.moves) {
		result.moves = remote.moves;
		changed = true;
	}
	return changed ? result : null;
}
