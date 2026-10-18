// One newly arrived notification in the top-right stack (see
// windows/NotificationToasts.qml). The countdown is NotificationService's:
// this only draws what is left of it.
//
// Hiding only puts the toast away — the notification itself stays in the
// notifications panel until you act on it there.
//
// Click: runs the sender's default action if it has one (e.g. focus the
// chat), otherwise opens the notifications panel.
import QtQuick
import Quickshell
import "../theme"
import "../state"
import "../services"
import "../components"

Item {
    id: root

    // Model roles of NotificationService.toasts.
    required property string tid
    required property real remaining

    readonly property var  n: NotificationService.toastEntry(tid)
    readonly property bool live: !!n && NotificationService.isLive(n.id)
    readonly property bool critical: !!n && n.urgency === 2
    readonly property var  buttons: live && n.actions
                                    ? n.actions.filter(function (a) { return a.id !== "default" && a.text })
                                    : []
    readonly property bool hasDefault: live && !!n.actions
                                       && n.actions.some(function (a) { return a.id === "default" })

    readonly property int pad: 14

    implicitHeight: column.implicitHeight + pad * 2 + 4

    Rectangle {
        anchors.fill: parent
        radius: Theme.ccCardRadius
        color: Theme.barBg
        border.width: 1
        border.color: root.critical ? Qt.rgba(Theme.urgent.r, Theme.urgent.g, Theme.urgent.b, 0.5)
                                    : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.07)
    }

    TapHandler {
        onTapped: {
            if (!root.n) return
            if (root.hasDefault) {
                NotificationService.invoke(root.n.id, "default")
                NotificationService.dismiss(root.n.id)
            } else {
                ShellState.open("notifications")
            }
        }
    }

    // ── Content ─────────────────────────────────────────────────────────────
    Column {
        id: column
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: root.pad }
        spacing: 10

        Row {
            width: parent.width
            spacing: 12

            // Image hint (avatar, album art), else the app icon, else its
            // initial.
            Item {
                width: 42
                height: 42

                Image {
                    id: art
                    anchors.fill: parent
                    source: {
                        var n = root.n
                        if (!n) return ""
                        if (n.image) return n.image
                        var ic = n.appIcon || ""
                        if (ic === "") return ""
                        if (ic.startsWith("/")) return "file://" + ic
                        if (ic.startsWith("file://") || ic.startsWith("image://")) return ic
                        return Quickshell.iconPath(ic, true)
                    }
                    sourceSize.width: 84
                    sourceSize.height: 84
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: art.status === Image.Ready ? "transparent"
                         : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: art.source
                        sourceSize: art.sourceSize
                        fillMode: art.fillMode
                        visible: art.status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: art.status !== Image.Ready
                        text: root.n ? (root.n.appName || "?").charAt(0).toUpperCase() : "?"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 17
                        font.bold: true
                    }
                }
            }

            Column {
                width: parent.width - 42 - 12 - close.width - 12
                spacing: 3

                Row {
                    spacing: 6

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.critical
                        width: 6
                        height: 6
                        radius: 3
                        color: Theme.urgent
                    }
                    Text {
                        text: root.n ? (root.n.appName || "Notification") : ""
                        color: Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                    Text {
                        text: "· now"
                        color: Theme.overlay1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }

                Text {
                    width: parent.width
                    text: root.n ? (root.n.summary || "") : ""
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 1
                    font.bold: true
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    width: parent.width
                    visible: text !== ""
                    text: root.n ? (root.n.body || "") : ""
                    textFormat: Text.StyledText
                    color: Theme.subtext1
                    linkColor: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    maximumLineCount: 3
                    onLinkActivated: function (link) { Qt.openUrlExternally(link) }
                }
            }

            // Hide (the notification stays in the panel).
            Rectangle {
                id: close
                width: 26
                height: 26
                radius: 13
                color: closeHover.hovered ? Theme.hover : "transparent"

                Icon {
                    anchors.centerIn: parent
                    text: ""
                    color_: closeHover.hovered ? Theme.text : Theme.subtext0
                    font.pixelSize: 12
                }

                // MouseArea, not TapHandler: it takes the press, so the card's
                // own tap doesn't fire too.
                MouseArea {
                    id: closeHover
                    readonly property bool hovered: containsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotificationService.dropToast(root.tid)
                }
            }
        }

        // ── Actions ─────────────────────────────────────────────────────────
        Row {
            anchors.right: parent.right
            visible: root.buttons.length > 0
            spacing: 8

            Repeater {
                model: root.buttons

                Rectangle {
                    required property var modelData

                    width: label.implicitWidth + 24
                    height: 28
                    radius: 14
                    color: actHover.hovered ? Theme.accent : Theme.surface

                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: modelData.text
                        color: actHover.hovered ? Theme.crust : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    MouseArea {
                        id: actHover
                        readonly property bool hovered: containsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            NotificationService.invoke(root.n.id, modelData.id)
                            NotificationService.dismiss(root.n.id)
                        }
                    }
                }
            }
        }
    }

    // ── Countdown ───────────────────────────────────────────────────────────
    // Stepped by the service every 100 ms; the Behavior smooths the steps.
    Rectangle {
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
        anchors.bottomMargin: 5
        visible: !root.critical
        width: (parent.width - 60) * Math.max(0, root.remaining / NotificationService.toastDuration)
        height: 2
        radius: 1
        color: Theme.accent
        opacity: NotificationService.toastsHeld ? 0.25 : 0.6

        Behavior on width { NumberAnimation { duration: 100 } }
    }
}
