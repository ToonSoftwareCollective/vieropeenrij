import QtQuick 2.1
import qb.components 1.0
import BasicUIControls 1.0
import "vieropeenrij.js" as Game

Screen {
	id: vieropeenrijSettingsScreen

	screenTitle: "Instellingen Vier op een rij"
	screenTitleIconUrl: "qrc:/tsc/vieropeenrij.png"

	property color textColor : "#565656"
	property string localIp : ""

	onShown: {
		addCustomTopRightButton("Sluiten");
		nameLabel.inputText = app.playerName;
		peerLabel.inputText = app.peerAddress;
		serverLabel.inputText = app.serverUrl;
		roomLabel.inputText = app.roomName;
		localIp = app.localAddress();
	}

	onCustomButtonClicked: {
		hide();
	}

	function saveName(text) {
		app.setPlayerName(text);
		nameLabel.inputText = app.playerName;
	}

	function savePeer(text) {
		app.setPeerAddress(text);
		peerLabel.inputText = app.peerAddress;
	}

	function saveServer(text) {
		app.setServerUrl(text);
		serverLabel.inputText = app.serverUrl;
	}

	function saveRoom(text) {
		app.setRoomName(text);
		roomLabel.inputText = app.roomName;
	}

	Text {
		id: modeTitle
		text: "Tegen wie wil je spelen?"
		color: textColor
		anchors {
			top: parent.top
			topMargin: isNxt ? 24 : 18
			left: parent.left
			leftMargin: isNxt ? 38 : 30
		}
		font {
			family: qfont.semiBold.name
			pixelSize: isNxt ? 22 : 18
		}
	}

	StandardButton {
		id: btnMode
		width: isNxt ? 460 : 370
		text: "Tegenstander: " + app.modeName
		anchors {
			top: modeTitle.bottom
			topMargin: isNxt ? 10 : 8
			left: modeTitle.left
		}
		onClicked: app.cycleOpponentMode()
	}

	Text {
		id: modeHelp
		text: {
			if (app.opponentMode === Game.MODE_PEER) return "Twee Toons in hetzelfde netwerk spelen tegen elkaar. Vul hieronder het IP adres van de andere Toon in, en op de andere Toon dit adres: " + (localIp ? localIp : "(onbekend)");
			if (app.opponentMode === Game.MODE_SERVER) return "Speel via een server op internet tegen iedereen die dezelfde kamer kiest. Zet vieropeenrij.php (of de python server) op een webserver en vul het adres hieronder in.";
			return "Je speelt tegen Toon. Het niveau kies je op het spelscherm.";
		}
		color: textColor
		width: isNxt ? 920 : 740
		wrapMode: Text.WordWrap
		anchors {
			top: btnMode.bottom
			topMargin: isNxt ? 10 : 8
			left: modeTitle.left
		}
		font {
			family: qfont.regular.name
			pixelSize: isNxt ? 18 : 15
		}
	}

	EditTextLabel4421 {
		id: nameLabel
		width: isNxt ? 600 : 480
		height: isNxt ? 44 : 35
		leftTextAvailableWidth: isNxt ? 260 : 210
		leftText: "Mijn naam:"
		anchors {
			top: modeHelp.bottom
			topMargin: isNxt ? 20 : 14
			left: modeTitle.left
		}
		onClicked: qkeyboard.open("Naam die de tegenstander ziet", nameLabel.inputText, saveName)
	}

	IconButton {
		width: isNxt ? 50 : 40
		iconSource: "qrc:/tsc/edit.png"
		anchors {
			left: nameLabel.right
			leftMargin: 6
			top: nameLabel.top
		}
		bottomClickMargin: 3
		onClicked: qkeyboard.open("Naam die de tegenstander ziet", nameLabel.inputText, saveName)
	}

	EditTextLabel4421 {
		id: peerLabel
		visible: app.opponentMode === Game.MODE_PEER
		width: nameLabel.width
		height: nameLabel.height
		leftTextAvailableWidth: nameLabel.leftTextAvailableWidth
		leftText: "IP adres andere Toon:"
		anchors {
			top: nameLabel.bottom
			topMargin: 6
			left: nameLabel.left
		}
		onClicked: qkeyboard.open("IP adres van de andere Toon (bijv. 192.168.1.20)", peerLabel.inputText, savePeer)
	}

	IconButton {
		visible: peerLabel.visible
		width: isNxt ? 50 : 40
		iconSource: "qrc:/tsc/edit.png"
		anchors {
			left: peerLabel.right
			leftMargin: 6
			top: peerLabel.top
		}
		bottomClickMargin: 3
		onClicked: qkeyboard.open("IP adres van de andere Toon (bijv. 192.168.1.20)", peerLabel.inputText, savePeer)
	}

	EditTextLabel4421 {
		id: serverLabel
		visible: app.opponentMode === Game.MODE_SERVER
		width: nameLabel.width
		height: nameLabel.height
		leftTextAvailableWidth: nameLabel.leftTextAvailableWidth
		leftText: "Server adres:"
		anchors {
			top: nameLabel.bottom
			topMargin: 6
			left: nameLabel.left
		}
		onClicked: qkeyboard.open("Adres van de server (bijv. https://mijnsite.nl/vieropeenrij.php)", serverLabel.inputText, saveServer)
	}

	IconButton {
		visible: serverLabel.visible
		width: isNxt ? 50 : 40
		iconSource: "qrc:/tsc/edit.png"
		anchors {
			left: serverLabel.right
			leftMargin: 6
			top: serverLabel.top
		}
		bottomClickMargin: 3
		onClicked: qkeyboard.open("Adres van de server (bijv. https://mijnsite.nl/vieropeenrij.php)", serverLabel.inputText, saveServer)
	}

	EditTextLabel4421 {
		id: roomLabel
		visible: app.opponentMode === Game.MODE_SERVER
		width: nameLabel.width
		height: nameLabel.height
		leftTextAvailableWidth: nameLabel.leftTextAvailableWidth
		leftText: "Kamer:"
		anchors {
			top: serverLabel.bottom
			topMargin: 6
			left: nameLabel.left
		}
		onClicked: qkeyboard.open("Naam van de kamer (spelers in dezelfde kamer spelen tegen elkaar)", roomLabel.inputText, saveRoom)
	}

	IconButton {
		visible: roomLabel.visible
		width: isNxt ? 50 : 40
		iconSource: "qrc:/tsc/edit.png"
		anchors {
			left: roomLabel.right
			leftMargin: 6
			top: roomLabel.top
		}
		bottomClickMargin: 3
		onClicked: qkeyboard.open("Naam van de kamer (spelers in dezelfde kamer spelen tegen elkaar)", roomLabel.inputText, saveRoom)
	}

	Text {
		id: statusLine
		visible: app.networkMode
		text: app.netStatus !== "" ? app.netStatus : (app.netConfigured ? "Verbinding in orde" : "")
		color: app.netStatus !== "" ? "#b0301c" : "#3c8a3c"
		width: nameLabel.width
		wrapMode: Text.WordWrap
		anchors {
			top: (app.opponentMode === Game.MODE_SERVER) ? roomLabel.bottom : peerLabel.bottom
			topMargin: isNxt ? 16 : 12
			left: nameLabel.left
		}
		font {
			family: qfont.regular.name
			pixelSize: isNxt ? 18 : 15
		}
	}
}
