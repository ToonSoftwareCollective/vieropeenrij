import QtQuick 2.1
import qb.components 1.0
import qb.base 1.0
import FileIO 1.0
import "vieropeenrij.js" as Game

App {
	id: vieropeenrijApp
	objectName: "VieropeenrijApp"

	property url tileUrl : "VieropeenrijTile.qml"
	property url thumbnailIcon: "qrc:/tsc/vieropeenrij.png"
	property url screenUrl : "VieropeenrijScreen.qml"
	property VieropeenrijScreen vieropeenrijScreen

		// game state. 'board' is a flat array of 42 cells, row 0 is the top row (see vieropeenrij.js)
	property var board : Game.newBoard()
	property int currentPlayer : Game.HUMAN
	property int gameState : Game.RUNNING
	property var winCells : []
	property int lastCell : -1
	property bool computerThinking : false

		// settings and score, kept in the user settings file
	property int level : Game.LEVEL_NORMAL
	property bool humanStarts : true
	property int wins : 0
	property int losses : 0
	property int draws : 0

	property string levelName : Game.levelName(level)

	property string statusText : {
		if (gameState === Game.HUMAN_WON) return "Je hebt gewonnen!";
		if (gameState === Game.COMPUTER_WON) return "Toon heeft gewonnen";
		if (gameState === Game.DRAW) return "Gelijkspel";
		if (computerThinking) return "Toon denkt na...";
		return "Jouw beurt";
	}

	readonly property string settingsFilePath : "file:///mnt/data/tsc/vieropeenrij.userSettings.json"

	FileIO {
		id: settingsFile
		source: settingsFilePath
	}

	function init() {
		registry.registerWidget("tile", tileUrl, this, null, {thumbLabel: "Vier op een rij", thumbIcon: thumbnailIcon, thumbCategory: "general", thumbWeight: 30, baseTileWeight: 10, thumbIconVAlignment: "center"});
		registry.registerWidget("screen", screenUrl, this, "vieropeenrijScreen");
	}

	Component.onCompleted: {
		loadSettings();
		newGame();
	}

	function loadSettings() {
		try {
			var settings = JSON.parse(settingsFile.read());
			if (settings['level']) level = settings['level'];
			if (typeof settings['humanStarts'] === 'boolean') humanStarts = settings['humanStarts'];
			if (settings['wins']) wins = settings['wins'];
			if (settings['losses']) losses = settings['losses'];
			if (settings['draws']) draws = settings['draws'];
		} catch(e) {
			// no settings file yet: keep the defaults
		}
	}

	function saveSettings() {
		var tmpUserSettingsJson = {
			"level": level,
			"humanStarts": humanStarts,
			"wins": wins,
			"losses": losses,
			"draws": draws
		}

		var saveFile = new XMLHttpRequest();
		saveFile.open("PUT", settingsFilePath);
		saveFile.send(JSON.stringify(tmpUserSettingsJson));
	}

	function newGame() {
		thinkTimer.stop();
		computerThinking = false;
		board = Game.newBoard();
		winCells = [];
		lastCell = -1;
		gameState = Game.RUNNING;
		currentPlayer = humanStarts ? Game.HUMAN : Game.COMPUTER;
		if (currentPlayer === Game.COMPUTER) startComputerMove();
	}

		// called from the screen when a column is tapped
	function humanMove(col) {
		if (gameState !== Game.RUNNING || currentPlayer !== Game.HUMAN || computerThinking) return;
		if (!placeDisc(col, Game.HUMAN)) return;
		if (gameState === Game.RUNNING) startComputerMove();
	}

		// the reply is delayed a little so the player sees their own disc land first
	function startComputerMove() {
		computerThinking = true;
		thinkTimer.start();
	}

	function computerMove() {
		var col = Game.chooseMove(board, Game.COMPUTER, level);
		if (col >= 0) placeDisc(col, Game.COMPUTER);
		computerThinking = false;
	}

		// drops a disc and updates the game state; returns false when the column is full
	function placeDisc(col, player) {

			// work on a copy: mutating the array in place would not change the property's
			// value reference, so QML would emit no change signal and the board would not redraw

		var work = board.slice();
		var row = Game.drop(work, col, player);
		if (row < 0) return false;

		board = work;
		lastCell = row * Game.COLS + col;

		var cells = Game.winningLine(board, row, col);
		if (cells) {
			winCells = cells;
			if (player === Game.HUMAN) {
				gameState = Game.HUMAN_WON;
				wins++;
			} else {
				gameState = Game.COMPUTER_WON;
				losses++;
			}
			saveSettings();
		} else if (Game.isFull(board)) {
			gameState = Game.DRAW;
			draws++;
			saveSettings();
		} else {
			currentPlayer = Game.other(player);
		}
		return true;
	}

	function cycleLevel() {
		level = (level >= Game.LEVEL_HARD) ? Game.LEVEL_EASY : level + 1;
		saveSettings();
	}

		// applies to the next game
	function toggleStarter() {
		humanStarts = !humanStarts;
		saveSettings();
	}

	function resetScore() {
		wins = 0;
		losses = 0;
		draws = 0;
		saveSettings();
	}

	Timer {
		id: thinkTimer
		interval: 400
		running: false
		repeat: false
		onTriggered: computerMove()
	}
}
