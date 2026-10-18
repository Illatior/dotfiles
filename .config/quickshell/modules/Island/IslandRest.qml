// The island at rest: the time (with seconds), with EQ bars beside it while music plays,
// and the pomodoro countdown (a small progress ring + mm:ss) while a session
// is underway — dimmed, with a pause glyph, when paused.
import QtQuick
import "../../theme"
import "../../services"
import "../../components"

Row {
    id: root

    property date now: new Date()

    spacing: 8

    EqBars {
        anchors.verticalCenter: parent.verticalCenter
        visible: MediaService.playing && !pomodoro.visible
        playing: visible
    }

    // ── Pomodoro ────────────────────────────────────────────────────────────
    Row {
        id: pomodoro
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        visible: PomodoroService.active || PomodoroService.ringing
        opacity: PomodoroService.running || PomodoroService.ringing ? 1 : 0.6

        readonly property color tint: PomodoroService.phase === "work" ? Theme.accent : Theme.success

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16

            Canvas {
                anchors.fill: parent
                visible: PomodoroService.running
                property real value: PomodoroService.progress
                property color tint: pomodoro.tint
                onValueChanged: requestPaint()
                onTintChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d")
                    var c = width / 2, r = c - 2
                    ctx.reset()
                    ctx.lineWidth = 2.5
                    ctx.strokeStyle = Theme.hover
                    ctx.beginPath(); ctx.arc(c, c, r, 0, Math.PI * 2); ctx.stroke()
                    ctx.strokeStyle = tint
                    ctx.lineCap = "round"
                    ctx.beginPath()
                    ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.max(0.02, value))
                    ctx.stroke()
                }
            }
            Icon {
                anchors.centerIn: parent
                visible: !PomodoroService.running
                text: PomodoroService.ringing ? "" : ""
                color_: pomodoro.tint
                font.pixelSize: 10
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: PomodoroService.clock
            color: pomodoro.tint
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLarge
            font.bold: true
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 14
            color: Theme.divider
        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Qt.formatDateTime(root.now, "HH:mm:ss")
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLarge
        font.bold: true
    }
}
