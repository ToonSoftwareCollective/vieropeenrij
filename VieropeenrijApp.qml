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
	property url settingsScreenUrl : "VieropeenrijSettingsScreen.qml"
	property VieropeenrijScreen vieropeenrijScreen
	property VieropeenrijSettingsScreen vieropeenrijSettingsScreen

		// The game, in every mode, is the object described in vieropeenrij.js: who plays red and yellow,
		// who started and the list of columns played. The board below is replayed from it, so a game
		// received from another Toon or the server is shown exactly like a local one.
	property var netGame : Game.emptyNetGame()

		// derived from netGame by applyState(); 'board' is a flat array of 42 cells, row 0 is the top row
	property var board : Game.newBoard()
	property int currentPlayer : Game.RED
	property int gameState : Game.RUNNING
	property var winCells : []
	property int lastCell : -1
	property bool computerThinking : false

		// settings, kept in the user settings file
	property int opponentMode : Game.MODE_COMPUTER
	property int level : Game.LEVEL_NORMAL
	property bool humanStarts : true		// applies to the next game
	property string playerId : ""			// random, generated once, identifies this Toon in a network game
	property string playerName : "Speler"
	property string peerAddress : ""		// IP address of the other Toon (MODE_PEER)
	property string serverUrl : ""			// URL of vieropeenrij.php or the python server (MODE_SERVER)
	property string roomName : "toon"		// players in the same room on the server play each other

		// score against Toon and score against people, and the game that was last counted
	property int wins : 0
	property int losses : 0
	property int draws : 0
	property int netWins : 0
	property int netLosses : 0
	property int netDraws : 0
	property string scoredGameId : ""

		// network status shown on the screen: "" when all is well
	property string netStatus : ""
	property bool screenVisible : false

	property bool networkMode : opponentMode !== Game.MODE_COMPUTER
	property string levelName : Game.levelName(level)
	property string modeName : Game.modeName(opponentMode)

		// colour this Toon plays: red against the computer, in a network game whichever seat we hold (0 = none)
	property int myColor : {
		if (!networkMode) return Game.RED;
		if (netGame.red.id === playerId && playerId !== "") return Game.RED;
		if (netGame.yellow.id === playerId && playerId !== "") return Game.YELLOW;
		return 0;
	}

	property string opponentName : {
		if (!networkMode) return "Toon";
		var seat = (myColor === Game.YELLOW) ? netGame.red : netGame.yellow;
		return seat.name ? seat.name : "tegenstander";
	}

	property bool opponentJoined : !networkMode || (netGame.red.id !== "" && netGame.yellow.id !== "")

	property bool myTurn : gameState === Game.RUNNING && !computerThinking && myColor !== 0 && currentPlayer === myColor && netGame.id !== ""

	property string statusText : {
		if (gameState === Game.RED_WON || gameState === Game.YELLOW_WON) {
			var winner = (gameState === Game.RED_WON) ? Game.RED : Game.YELLOW;
			if (winner === myColor) return "Je hebt gewonnen!";
			if (myColor === 0) return (winner === Game.RED ? netGame.red.name : netGame.yellow.name) + " heeft gewonnen";
			return opponentName + " heeft gewonnen";
		}
		if (gameState === Game.DRAW) return "Gelijkspel";
		if (computerThinking) return "Toon denkt na...";
		if (networkMode && netGame.id === "") return "Druk op Nieuw spel";
		if (networkMode && myColor === 0) return "Je kijkt mee";
		if (myTurn) return "Jouw beurt";
		if (networkMode && !opponentJoined) return "Wachten op tegenstander...";
		return "Wachten op " + opponentName;
	}

	property string legendText : {
		if (!networkMode) return "Jij speelt rood, Toon speelt geel";
		if (netGame.id === "") return "Nog geen spel";
		if (myColor === Game.RED) return "Jij speelt rood, " + opponentName + " speelt geel";
		if (myColor === Game.YELLOW) return "Jij speelt geel, " + opponentName + " speelt rood";
		return netGame.red.name + " (rood) tegen " + netGame.yellow.name + " (geel)";
	}

	property string scoreText : networkMode
		? ("Jij " + netWins + "  -  Anderen " + netLosses + "  -  Gelijk " + netDraws)
		: ("Jij " + wins + "  -  Toon " + losses + "  -  Gelijk " + draws)

	readonly property string settingsFilePath : "file:///mnt/data/tsc/vieropeenrij.userSettings.json"

		// in peer mode each Toon publishes its game through its own web server: /qmf/www is the
		// document root of lighttpd, so this file is reachable as http://<toon>/vieropeenrij.json
	readonly property string peerFilePath : "file:///qmf/www/" + Game.PEER_FILE

	FileIO {
		id: settingsFile
		source: settingsFilePath
	}

	FileIO {
		id: routeFile
		source: "file:///proc/net/fib_trie"
	}

	function init() {
		registry.registerWidget("tile", tileUrl, this, null, {thumbLabel: "Vier op een rij", thumbIcon: thumbnailIcon, thumbCategory: "general", thumbWeight: 30, baseTileWeight: 10, thumbIconVAlignment: "center"});
		registry.registerWidget("screen", screenUrl, this, "vieropeenrijScreen");
		registry.registerWidget("screen", settingsScreenUrl, this, "vieropeenrijSettingsScreen");
	}

	Component.onCompleted: {
		loadSettings();
		if (playerId === "") {
			playerId = Game.randomId(8);
			saveSettings();
		}
		if (networkMode) {
			applyState();
			publish();
		} else {
			newGame();
		}
	}

	function loadSettings() {
		try {
			var settings = JSON.parse(settingsFile.read());
			if (settings['level']) level = settings['level'];
			if (typeof settings['humanStarts'] === 'boolean') humanStarts = settings['humanStarts'];
			if (settings['wins']) wins = settings['wins'];
			if (settings['losses']) losses = settings['losses'];
			if (settings['draws']) draws = settings['draws'];
			if (settings['netWins']) netWins = settings['netWins'];
			if (settings['netLosses']) netLosses = settings['netLosses'];
			if (settings['netDraws']) netDraws = settings['netDraws'];
			if (typeof settings['opponentMode'] === 'number') opponentMode = settings['opponentMode'];
			if (typeof settings['playerId'] === 'string') playerId = settings['playerId'];
			if (typeof settings['playerName'] === 'string' && settings['playerName'] !== "") playerName = settings['playerName'];
			if (typeof settings['peerAddress'] === 'string') peerAddress = settings['peerAddress'];
			if (typeof settings['serverUrl'] === 'string') serverUrl = settings['serverUrl'];
			if (typeof settings['roomName'] === 'string' && settings['roomName'] !== "") roomName = settings['roomName'];
			if (typeof settings['scoredGameId'] === 'string') scoredGameId = settings['scoredGameId'];

				// the network game is kept too, so a restart of the Toon does not lose a game in progress
			var saved = Game.sanitize(settings['netGame']);
			if (saved && opponentMode !== Game.MODE_COMPUTER) netGame = saved;
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
			"draws": draws,
			"netWins": netWins,
			"netLosses": netLosses,
			"netDraws": netDraws,
			"opponentMode": opponentMode,
			"playerId": playerId,
			"playerName": playerName,
			"peerAddress": peerAddress,
			"serverUrl": serverUrl,
			"roomName": roomName,
			"scoredGameId": scoredGameId,
			"netGame": networkMode ? netGame : null
		}

		var saveFile = new XMLHttpRequest();
		saveFile.open("PUT", settingsFilePath);
		saveFile.send(JSON.stringify(tmpUserSettingsJson));
	}

	function me() {
		return {id: playerId, name: playerName};
	}

		// ---- the game ----

	function newGame() {
		thinkTimer.stop();
		computerThinking = false;

		if (networkMode) {
			netGame = Game.newNetGame(me(), humanStarts);
		} else {
			var now = Date.now();
			netGame = {
				v: Game.PROTOCOL_VERSION,
				id: "local-" + now,
				ts: now,
				red: me(),
				yellow: {id: "toon", name: "Toon"},
				first: humanStarts ? "red" : "yellow",
				moves: ""
			};
		}
		applyState();
		saveSettings();
		if (networkMode) {
			publish();
		} else if (currentPlayer === Game.YELLOW) {
			startComputerMove();
		}
	}

		// rebuilds the board from the move list in netGame and updates the score when the game just ended
	function applyState() {
		var r = Game.replay(netGame.moves, Game.firstPlayer(netGame));
		if (!r.valid) {
				// cannot happen for a sanitized state; start over rather than show nonsense
			netGame = Game.emptyNetGame();
			r = Game.replay("", Game.RED);
		}
		board = r.board;
		lastCell = r.lastCell;
		winCells = r.winCells;
		gameState = r.state;
		currentPlayer = r.current;

		if (gameState !== Game.RUNNING && netGame.id !== "" && scoredGameId !== netGame.id && myColor !== 0) {
			var won = (gameState === Game.RED_WON && myColor === Game.RED) || (gameState === Game.YELLOW_WON && myColor === Game.YELLOW);
			if (gameState === Game.DRAW) { if (networkMode) netDraws++; else draws++; }
			else if (won) { if (networkMode) netWins++; else wins++; }
			else { if (networkMode) netLosses++; else losses++; }
			scoredGameId = netGame.id;
			saveSettings();
		}
	}

		// appends a move to the game; the object is copied so QML sees the change
	function appendMove(col) {
		if (Game.dropRow(board, col) < 0) return false;
		netGame = {v: netGame.v, id: netGame.id, ts: netGame.ts, red: netGame.red, yellow: netGame.yellow, first: netGame.first, moves: netGame.moves + col};
		applyState();
		return true;
	}

		// called from the screen when a column is tapped
	function humanMove(col) {
		if (!myTurn) return;
		if (!appendMove(col)) return;
		if (networkMode) {
			saveSettings();
			publish();
		} else if (gameState === Game.RUNNING) {
			startComputerMove();
		}
	}

		// the reply is delayed a little so the player sees their own disc land first
	function startComputerMove() {
		computerThinking = true;
		thinkTimer.start();
	}

	function computerMove() {
		if (!networkMode && gameState === Game.RUNNING && currentPlayer === Game.YELLOW) {
			var col = Game.chooseMove(board, Game.YELLOW, level);
			if (col >= 0) appendMove(col);
		}
		computerThinking = false;
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
		if (networkMode) {
			netWins = 0;
			netLosses = 0;
			netDraws = 0;
		} else {
			wins = 0;
			losses = 0;
			draws = 0;
		}
		saveSettings();
	}

		// ---- settings ----

	function setOpponentMode(mode) {
		if (mode === opponentMode) return;
		thinkTimer.stop();
		computerThinking = false;
		netStatus = "";
		opponentMode = mode;
		if (networkMode) {
				// wait for the other side; it may already have a game running that we then join
			netGame = Game.emptyNetGame();
			applyState();
			saveSettings();
			publish();
			pollNow();
		} else {
			newGame();
		}
	}

	function cycleOpponentMode() {
		setOpponentMode((opponentMode >= Game.MODE_SERVER) ? Game.MODE_COMPUTER : opponentMode + 1);
	}

	function setPlayerName(name) {
		name = String(name).replace(/[\r\n"\\]/g, "").substring(0, 20);
		if (name === "" || name === playerName) return;
		playerName = name;
			// a seated player carries the new name into the running game
		if (networkMode && netGame.id !== "" && myColor !== 0) {
			var g = {v: netGame.v, id: netGame.id, ts: netGame.ts, red: netGame.red, yellow: netGame.yellow, first: netGame.first, moves: netGame.moves};
			if (myColor === Game.RED) g.red = me(); else g.yellow = me();
			netGame = g;
		}
		saveSettings();
		if (networkMode) publish();
	}

	function setPeerAddress(address) {
		peerAddress = String(address).replace(/\s|^https?:\/\/|\/.*$/g, "");
		netStatus = "";
		saveSettings();
		if (networkMode) pollNow();
	}

	function setServerUrl(url) {
		url = String(url).replace(/\s/g, "");
		if (url !== "" && url.indexOf("http://") !== 0 && url.indexOf("https://") !== 0) url = "http://" + url;
		serverUrl = url;
		netStatus = "";
		saveSettings();
		if (networkMode) pollNow();
	}

	function setRoomName(room) {
		room = String(room).replace(/[^A-Za-z0-9_-]/g, "").substring(0, 32).toLowerCase();
		if (room === "" || room === roomName) return;
		roomName = room;
		netGame = Game.emptyNetGame();
		applyState();
		saveSettings();
		if (networkMode) pollNow();
	}

		// the IPv4 address of this Toon, to show in the settings so the other Toon can be pointed at it
	function localAddress() {
		try {
			var lines = routeFile.read().split("\n");
			for (var i = 1; i < lines.length; i++) {
				if (lines[i].indexOf("/32 host") >= 0) {
					var m = lines[i - 1].match(/(\d+\.\d+\.\d+\.\d+)/);
					if (m && m[1].indexOf("127.") !== 0) return m[1];
				}
			}
		} catch(e) {
		}
		return "";
	}

		// ---- network ----

	property bool netConfigured : (opponentMode === Game.MODE_PEER && peerAddress !== "") || (opponentMode === Game.MODE_SERVER && serverUrl !== "")
	property int requestSeq : 0
	property bool requestBusy : false
	property double requestStarted : 0

	function serverRoomUrl() {
		return serverUrl + (serverUrl.indexOf("?") >= 0 ? "&" : "?") + "room=" + encodeURIComponent(roomName);
	}

	function remoteName() {
		return (opponentMode === Game.MODE_PEER) ? peerAddress : "de server";
	}

		// makes our game visible to the other side
	function publish() {
		if (!networkMode) return;
		var body = JSON.stringify(netGame);

		if (opponentMode === Game.MODE_PEER) {
			var file = new XMLHttpRequest();
			file.open("PUT", peerFilePath);
			file.send(body);
		} else if (serverUrl !== "") {
				// the server answers with the merged room state, which may already contain the other player
			request("POST", serverRoomUrl(), body);
		}
	}

	function pollNow() {
		pollTimer.restart();
		poll();
	}

	function poll() {
		if (!networkMode || !netConfigured) return;
		if (opponentMode === Game.MODE_PEER) {
			request("GET", "http://" + peerAddress + "/" + Game.PEER_FILE + "?t=" + Date.now(), null);
		} else {
			request("GET", serverRoomUrl() + "&t=" + Date.now(), null);
		}
	}

		// one request at a time; a request that never answers is abandoned after 20 seconds
	function request(method, url, body) {
		var now = Date.now();
		if (requestBusy && now - requestStarted < 20000) return;
		requestBusy = true;
		requestStarted = now;
		var seq = ++requestSeq;

		var xhr = new XMLHttpRequest();
		xhr.onreadystatechange = function() {
			if (xhr.readyState !== XMLHttpRequest.DONE) return;
			if (seq !== requestSeq) return;			// superseded
			requestBusy = false;
			if (xhr.status === 200) {
				netStatus = "";
				var remote = null;
				try { remote = JSON.parse(xhr.responseText); } catch(e) { remote = null; }
				if (remote) handleRemote(remote);
			} else if (xhr.status === 404 && opponentMode === Game.MODE_PEER) {
				netStatus = "De andere Toon heeft nog geen spel gepubliceerd";
			} else {
				netStatus = "Geen verbinding met " + remoteName();
			}
		}
		xhr.open(method, url);
		if (body !== null) xhr.setRequestHeader("Content-Type", "application/json");
		xhr.send(body);
	}

	function handleRemote(remote) {
		var merged = Game.merge(netGame, remote);
		if (!merged) return;

		netGame = merged;
			// a free yellow seat in someone else's game: take it
		if (netGame.red.id !== playerId && netGame.yellow.id === "") {
			netGame = {v: netGame.v, id: netGame.id, ts: netGame.ts, red: netGame.red, yellow: me(), first: netGame.first, moves: netGame.moves};
		}
		applyState();
		saveSettings();
		publish();
	}

	Timer {
		id: pollTimer
		interval: screenVisible ? 2000 : 15000
		running: networkMode && netConfigured
		repeat: true
		triggeredOnStart: true
		onTriggered: poll()
	}

	Timer {
		id: thinkTimer
		interval: 400
		running: false
		repeat: false
		onTriggered: computerMove()
	}
}
