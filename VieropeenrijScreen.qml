import QtQuick 2.1
import qb.components 1.0
import "vieropeenrij.js" as Game

Screen {
	id: vieropeenrijScreen

	screenTitle: "Vier op een rij"
	screenTitleIconUrl: "qrc:/tsc/vieropeenrij.png"

	property int cellSize : isNxt ? 66 : 52
	property int discMargin : isNxt ? 7 : 5

	property color boardColor : "#1f4e9c"
	property color humanColor : "#e2001a"
	property color computerColor : "#f7c600"
	property color emptyColor : "#f4f4f4"
	property color textColor : "#565656"

	onCustomButtonClicked: {
		app.newGame();
	}

	function discColor(value) {
		if (value === Game.HUMAN) return humanColor;
		if (value === Game.COMPUTER) return computerColor;
		return emptyColor;
	}

	// the board

	Rectangle {
		id: boardRect
		width: Game.COLS * cellSize
		height: Game.ROWS * cellSize
		radius: isNxt ? 10 : 8
		color: boardColor
		anchors {
			top: parent.top
			topMargin: isNxt ? 20 : 16
			left: parent.left
			leftMargin: isNxt ? 32 : 24
		}

		Grid {
			columns: Game.COLS
			anchors.fill: parent

			Repeater {
				model: Game.ROWS * Game.COLS

				Item {
					width: cellSize
					height: cellSize
					property int cellValue : app.board[index]
					property bool isWinCell : app.winCells.indexOf(index) >= 0
					property bool isLastCell : (index === app.lastCell)

					Rectangle {
						anchors.centerIn: parent
						width: cellSize - 2 * discMargin
						height: width
						radius: width / 2
						color: discColor(cellValue)
						border.width: isWinCell ? (isNxt ? 5 : 4) : (isLastCell ? 3 : 0)
						border.color: isWinCell ? "#ffffff" : "#333333"
					}
				}
			}
		}

			// one touch area per column; a tap anywhere in the column drops the disc

		Row {
			anchors.fill: parent

			Repeater {
				model: Game.COLS

				MouseArea {
					width: cellSize
					height: boardRect.height
					onClicked: app.humanMove(index)
				}
			}
		}
	}

	// status and controls to the right of the board

	Rectangle {
		id: turnDisc
		width: isNxt ? 36 : 28
		height: width
		radius: width / 2
		color: (app.gameState === Game.COMPUTER_WON || (app.gameState === Game.RUNNING && app.currentPlayer === Game.COMPUTER)) ? computerColor : humanColor
		visible: app.gameState !== Game.DRAW
		anchors {
			verticalCenter: statusText.verticalCenter
			left: boardRect.right
			leftMargin: isNxt ? 40 : 30
		}
	}

	Text {
		id: statusText
		text: app.statusText
		color: textColor
		anchors {
			top: boardRect.top
			topMargin: isNxt ? 4 : 2
			left: turnDisc.right
			leftMargin: isNxt ? 14 : 10
		}
		font {
			family: qfont.bold.name
			pixelSize: isNxt ? 26 : 21
		}
	}

	Text {
		id: legendText
		text: "Jij speelt rood, Toon speelt geel"
		color: textColor
		anchors {
			top: statusText.bottom
			topMargin: isNxt ? 8 : 6
			left: turnDisc.left
		}
		font {
			family: qfont.regular.name
			pixelSize: isNxt ? 18 : 15
		}
	}

	Rectangle {
		id: scoreRect
		width: isNxt ? 400 : 305
		height: isNxt ? 56 : 46
		radius: 3
		color: "#f0f0f0"
		anchors {
			top: legendText.bottom
			topMargin: isNxt ? 20 : 14
			left: turnDisc.left
		}

		Text {
			anchors.centerIn: parent
			text: "Jij " + app.wins + "  -  Toon " + app.losses + "  -  Gelijk " + app.draws
			color: textColor
			font {
				family: qfont.semiBold.name
				pixelSize: isNxt ? 22 : 18
			}
		}
	}

	StandardButton {
		id: btnNewGame
		width: scoreRect.width
		text: "Nieuw spel"
		anchors {
			top: scoreRect.bottom
			topMargin: isNxt ? 20 : 14
			left: scoreRect.left
		}
		onClicked: app.newGame()
	}

	StandardButton {
		id: btnLevel
		width: scoreRect.width
		text: "Niveau: " + app.levelName
		anchors {
			top: btnNewGame.bottom
			topMargin: 10
			left: scoreRect.left
		}
		onClicked: app.cycleLevel()
	}

	StandardButton {
		id: btnStarter
		width: scoreRect.width
		text: app.humanStarts ? "Volgend spel begint: jij" : "Volgend spel begint: Toon"
		anchors {
			top: btnLevel.bottom
			topMargin: 10
			left: scoreRect.left
		}
		onClicked: app.toggleStarter()
	}

	StandardButton {
		id: btnResetScore
		width: scoreRect.width
		text: "Score wissen"
		anchors {
			top: btnStarter.bottom
			topMargin: 10
			left: scoreRect.left
		}
		onClicked: app.resetScore()
	}
}
