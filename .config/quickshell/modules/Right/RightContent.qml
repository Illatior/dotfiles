// Right notch: the system tray strip, and the status pill the control center
// grows out of.
//
// The pill on the right carries four readouts — the keyboard layout, the
// active link (ethernet or wifi), volume with its percentage, and
// notifications with an unread count —
// then the user's ~/.face avatar at the far right. That pill is the
// control-center trigger. The tray strip to its left is not: every icon in it
// is its own click target, so ControlCenter keeps its collapsed input mask and
// hover area on the pill alone (see RightContent.triggerRect), otherwise this
// window's mask would swallow the tray's clicks. Everything else lives in
// the control center, which opens when this corner is hovered. The control
// center draws a copy of this pill over the notch and fades it out as it
// morphs, so keep it free of per-instance state.
import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../theme"
import "../../state"
import "../../services"
import "../../components"

Item {
    id: root

    readonly property bool active: ShellState.controlCenterOpen

    // The control-center trigger's box, in this item's coordinates.
    //
    // `trigger` is parented to the Row below, so its x/y are the Row's; adding
    // the Row's offset puts the box back in this item's space, which is what a
    // host placing this item needs.
    //
    // Exposed as a rect rather than just a width because the trigger is not
    // flush with the right edge: this item pads its content by 10px on each
    // side, so the notch's padding alone does not give the trigger's x.
    readonly property rect triggerRect: Qt.rect(row.x + trigger.x, row.y + trigger.y,
                                                trigger.width, trigger.height)

    implicitWidth: row.implicitWidth + 20
    implicitHeight: 28

    // The notch reads as one object: tinted while the control center is open,
    // plain the rest of the time. Hover is on the trigger alone, since that is
    // the part that does something.
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
             : "transparent"

        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 14

        // ── System tray ─────────────────────────────────────────────────────
        Tray {
            id: tray
            anchors.verticalCenter: parent.verticalCenter
            // On the service, never on this item's own width: a Row lays out
            // only the children that are visible, so hiding the tray because it
            // is empty would take its icons out of its own layout and keep it
            // empty for good.
            visible: TrayService.all.length > 0
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: tray.visible
            width: 1
            height: 14
            color: Theme.divider
        }

        // ── Control-center trigger ──────────────────────────────────────────
        Item {
            id: trigger
            anchors.verticalCenter: parent.verticalCenter
            width: status.implicitWidth + 20
            height: 28

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: hover.hovered ? Theme.hover : "transparent"

                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            Row {
                id: status
                anchors.centerIn: parent
                spacing: 14

                // ── Keyboard layout: its kb_layout code, "US" / "UA" ────────
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: text !== ""
                    text: HyprlandService.kbLayout
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                // ── Network: ethernet or wifi glyph, dimmed when offline ────
                Glyph {
                    text: NetworkService.glyph
                    color_: NetworkService.color
                }

                // ── Volume + percentage ─────────────────────────────────────
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Glyph {
                        text: AudioService.glyph
                        color_: AudioService.muted ? Theme.inactive : Theme.text
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: AudioService.volumePercent + "%"
                        color: AudioService.muted ? Theme.inactive : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                }

                // ── Notifications, with unread count badge ───────────────────
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: bell.implicitWidth + (badge.visible ? badge.width - 6 : 0)
                    height: bell.implicitHeight

                    Glyph {
                        id: bell
                        anchors.left: parent.left
                        // \uF0F3 = bell, \uF186 = bell-o, the glyph the
                        // control center's Peace tile already uses for "off".
                        text: NotificationService.dnd ? "\uF186" : "\uF0F3"
                        color_: NotificationService.dnd ? Theme.inactive : Theme.text
                    }

                    Rectangle {
                        id: badge
                        readonly property int unread: NotificationService.unreadCount

                        visible: unread > 0
                        anchors { left: bell.right; leftMargin: -6; top: parent.top; topMargin: -4 }
                        width: Math.max(height, badgeText.implicitWidth + 8)
                        height: 14
                        radius: height / 2
                        color: Theme.urgent

                        Text {
                            id: badgeText
                            anchors.centerIn: parent
                            text: badge.unread > 99 ? "99+" : String(badge.unread)
                            color: Theme.crust
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.bold: true
                        }
                    }
                }

                // ── Avatar (~/.face), hidden if the file is missing ─────────
                ClippingRectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: face.status === Image.Ready
                    width: 22
                    height: 22
                    radius: width / 2
                    color: Theme.surface1
                    border.width: 1
                    border.color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.15)

                    Image {
                        id: face
                        anchors.fill: parent
                        source: "file://" + Quickshell.env("HOME") + "/.face"
                        sourceSize.width: 44          // 2x for crispness
                        sourceSize.height: 44
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        asynchronous: true
                        // Uncached, so a changed ~/.face shows up on the next reload.
                        cache: false
                    }
                }
            }

            HoverHandler {
                id: hover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: ShellState.toggle("controlCenter")
            }

            // Scroll anywhere on the pill for volume.
            WheelHandler {
                onWheel: function (e) { AudioService.adjustVolume(e.angleDelta.y > 0 ? 0.05 : -0.05) }
            }
        }
    }

    component Glyph: Icon {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        font.pixelSize: Theme.fontSizeLarge
    }
}