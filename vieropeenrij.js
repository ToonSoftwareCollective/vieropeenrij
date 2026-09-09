.pragma library

	// Vier op een rij: spelregels en de computerspeler (negamax met alpha-beta pruning).
	// The board is a flat array of ROWS * COLS cells, index = row * COLS + col, row 0 is the top row.

var ROWS = 6;
var COLS = 7;

var EMPTY = 0;
var HUMAN = 1;
var COMPUTER = 2;

	// game states
var RUNNING = 0;
var HUMAN_WON = 1;
var COMPUTER_WON = 2;
var DRAW = 3;

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
