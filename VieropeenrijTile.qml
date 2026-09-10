import QtQuick 2.1
import qb.components 1.0
import "vieropeenrij.js" as Game

Tile {
	id: vieropeenrijTile

	property bool dimState: screenStateController.dimmedColors
	property int miniCell : isNxt ? 18 : 14

	onClicked: {
		if (app.vieropeenrijScreen) app.vieropeenrijScreen.show();
	}

	Text {
		id: tileTitle
		text: (app.networkMode && app.myTurn) ? "Jouw beurt!" : "Vier op een rij"
		anchors {
			baseline: parent.top
			baselineOffset: isNxt ? 32 : 25
			horizontalCenter: parent.horizontalCenter
		}
		font {
			family: qfont.bold.name
			pixelSize: isNxt ? 22 : 18
		}
		color: (typeof dimmableColors !== 'undefined') ? dimmableColors.clockTileColor : colors.clockTileColor
	}

		// small copy of the board; hidden in dim mode so the bright discs don't light up the room at night

	Rectangle {
		id: miniBoard
		width: Game.COLS * miniCell
		height: Game.ROWS * miniCell
		radius: 3
		color: "#1f4e9c"
		visible: !dimState
		anchors {
			top: tileTitle.baseline
			topMargin: isNxt ? 14 : 10
			horizontalCenter: parent.horizontalCenter
		}

		Grid {
			columns: Game.COLS
			anchors.fill: parent

			Repeater {
				model: Game.ROWS * Game.COLS

				Item {
					width: miniCell
					height: miniCell
					property int cellValue : app.board[index]

					Rectangle {
						anchors.centerIn: parent
						width: miniCell - 4
						height: width
						radius: width / 2
						color: (cellValue === Game.RED) ? "#e2001a" : (cellValue === Game.YELLOW) ? "#f7c600" : "#f4f4f4"
					}
				}
			}
		}
	}


	Text {
		id: tileScore
		text: app.scoreText
		anchors {
			baseline: parent.bottom
			baselineOffset: isNxt ? -14 : -12
			horizontalCenter: parent.horizontalCenter
		}
		font {
			family: qfont.regular.name
			pixelSize: isNxt ? 18 : 15
		}
		color: (typeof dimmableColors !== 'undefined') ? dimmableColors.clockTileColor : colors.clockTileColor
	}
}
