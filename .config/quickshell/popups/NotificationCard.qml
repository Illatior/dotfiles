// One notification card.
//
// Nothing disappears on its own; the card stays until you remove it:
//   ✕        — dismiss it (the header's "Clear all" does every card)
//   actions  — invoke the notification's own buttons
//
// Restored (persisted) notifications have no live handle, so their actions
// are hidden rather than failing silently; ✕ works on every card.
import QtQuick
import Quickshell.Services.Notifications
import "../theme"
import "../services"
import "../components"

Item {
    id: card

    required property var entry        // plain object from NotificationService
    required property bool isLive

    readonly property bool unread: !entry.read

    signal remove()
    signal action(string actionId)

    implicitHeight: row.implicitHeight + 24

    // A card of its own; unread ones get an urgency-tinted outline.
    Rectangle {
        anchors.fill: parent
        radius: 14
        color: card.unread ? Qt.rgba(card.urgencyColor.r, card.urgencyColor.g, card.urgencyColor.b, 0.06)
                           : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.045)
        border.width: 1
        border.color: card.unread ? Qt.rgba(card.urgencyColor.r, card.urgencyColor.g, card.urgencyColor.b, 0.35)
                                  : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.06)
    }

    readonly property color urgencyColor: {
        switch (entry.urgency) {
            case NotificationUrgency.Critical: return Theme.urgent
            case NotificationUrgency.Low:      return Theme.inactive
            default:                           return Theme.accent
        }
    }

    Row {
        id: row
        anchors {
            left: parent.left;  leftMargin: 12
            right: parent.right; rightMargin: 8
            top: parent.top;    topMargin: 12
        }
        spacing: 10
        height: Math.max(iconArea.height, textCol.implicitHeight)

        // ── App icon or letter fallback ─────────────────────────────────────
        Item {
            id: iconArea
            width: 32
            height: 32

            Image {
                id: iconImg
                anchors.fill: parent
                source: {
                    var ic = card.entry.appIcon || ""
                    if (ic === "") return ""
                    if (ic.startsWith("/")) return "file://" + ic
                    return "image://icon/" + ic
                }
                sourceSize.width: 32
                sourceSize.height: 32
                fillMode: Image.PreserveAspectFit
                smooth: true
                visible: status === Image.Ready
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Theme.hover
                visible: iconImg.status !== Image.Ready

                Text {
                    anchors.centerIn: parent
                    text: (card.entry.appName || "?").charAt(0).toUpperCase()
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.bold: true
                }
            }
        }

        // ── Text ────────────────────────────────────────────────────────────
        Column {
            id: textCol
            width: row.width - iconArea.width - buttons.width - row.spacing * 2
            spacing: 3

            Text {
                width: parent.width
                visible: text !== ""
                text: card.entry.appName || ""
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: card.entry.summary || ""
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge
                font.bold: true
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: card.entry.body || ""
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                wrapMode: Text.WordWrap
                maximumLineCount: 4
                elide: Text.ElideRight
                textFormat: Text.StyledText
            }

            // Action buttons
            Row {
                spacing: 6
                visible: card.isLive && (card.entry.actions || []).length > 0

                Repeater {
                    model: card.isLive ? (card.entry.actions || []) : []

                    delegate: Rectangle {
                        required property var modelData
                        width:  actionLabel.width + 20
                        height: 22
                        radius: 4
                        color: actHover.hovered
                               ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.28)
                               : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)

                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: modelData.text || ""
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        HoverHandler { id: actHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: card.action(modelData.id) }
                    }
                }
            }
        }

        // ── Controls ────────────────────────────────────────────────────────
        Row {
            id: buttons
            spacing: 2

            CardButton {
                glyph: "\uf00d"
                tip: "Dismiss"
                danger: true
                onActivated: card.remove()
            }
        }
    }

    // ── Small round button ──────────────────────────────────────────────────
    component CardButton: Item {
        id: btn

        property string glyph
        property string tip
        property bool   danger: false

        signal activated()

        width: 24
        height: 24

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: btnHover.hovered
                   ? (btn.danger ? Qt.rgba(Theme.urgent.r, Theme.urgent.g, Theme.urgent.b, 0.22)
                                 : Theme.hover)
                   : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }
        }

        Text {
            anchors.centerIn: parent
            text: btn.glyph
            color: btn.danger && btnHover.hovered ? Theme.urgent : Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }

        HoverHandler { id: btnHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: btn.activated() }
    }

    HoverHandler { id: cardHover }
}
