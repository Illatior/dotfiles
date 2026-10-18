// System tray strip for the right notch: one icon per tray item, to the left of
// the control-center trigger.
//
// Left click runs the item's primary action, middle click its secondary one,
// right click opens the app's own menu, and scrolling goes to the item (which is
// how the mixers in the tray handle volume). Items asking for attention get a
// dot so they stand out from the idle ones.
//
// Sized to its content, and empty — therefore zero width, and hidden by
// RightContent — while nothing is registered. Overflowing icons are counted in
// TrayService and drawn as "+N" rather than clipped by the notch.
import QtQuick
import "../../theme"
import "../../services"
import "../../state"

Row {
    id: root

    spacing: Theme.traySpacing

    Repeater {
        model: TrayService.items

        delegate: Item {
            id: slot

            required property var modelData

            readonly property var item:  slot.modelData
            readonly property bool alert: TrayService.needsAttention(slot.item)
            readonly property bool hasIcon: TrayService.hasIcon(slot.item)

            width: Theme.trayIconSize
            height: Theme.trayIconSize

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: hover.hovered ? Theme.hover : "transparent"

                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            // The item's icon. `icon` is already an image:// url built by
            // quickshell from the theme name and the app's own icon theme path,
            // so it goes straight into the source — when it names something that
            // exists at all (TrayService.hasIcon), since a name that does not
            // resolves to a magenta checkerboard that no status reports.
            Image {
                id: icon
                anchors.centerIn: parent
                width: Theme.trayIconSize
                height: Theme.trayIconSize
                visible: slot.hasIcon && icon.status !== Image.Error
                source: slot.hasIcon ? slot.item.icon : ""
                sourceSize.width: Theme.trayIconSize * 2    // 2x for crispness
                sourceSize.height: Theme.trayIconSize * 2
                fillMode: Image.PreserveAspectFit
                smooth: true
                asynchronous: true
            }

            // Fallback for the items with no icon to show: they advertise none,
            // or name one that is in no icon theme (Solaar's "battery-080").
            // Same fallback as the notification card — the item's initial. Kept
            // off until the icon is known bad, so it never flickers over an
            // icon that merely loaded.
            Text {
                anchors.centerIn: parent
                visible: !slot.hasIcon || icon.status === Image.Error
                text: TrayService.label(slot.item)
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge
                font.bold: true
            }

            Rectangle {
                anchors { right: parent.right; top: parent.top }
                visible: slot.alert
                width: 5
                height: 5
                radius: width / 2
                color: Theme.urgent
                border.width: 1
                border.color: Theme.barBg
            }

            HoverHandler {
                id: hover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                onTapped: function (point, button) {
                    // Any click dismisses a menu that is up — including this
                    // icon's own, which right click then reopens as a toggle.
                    var wasOpen = ShellState.trayMenuOpen
                        && ShellState.trayMenuAnchor === slot
                    if (ShellState.trayMenuOpen)
                        ShellState.closeAll()

                    // Items with no menu fall back to the primary action, so
                    // right click is never a dead gesture.
                    if (button === Qt.RightButton && slot.item.hasMenu) {
                        if (!wasOpen)
                            ShellState.openTrayMenu(slot.item, slot)
                    } else if (button === Qt.MiddleButton) {
                        TrayService.secondaryActivate(slot.item)
                    } else {
                        TrayService.activate(slot.item)
                    }
                }
            }

            WheelHandler {
                onWheel: function (event) {
                    TrayService.scroll(slot.item, event.angleDelta.y)
                }
            }

            // This item's own menu, hanging off the icon. One per item rather
            // than a shared window because each anchors to its own icon — and
            // because a window can only hold one menu at a time anyway. Keyed
            // on the icon, not the item: the same item sits in every tray.
            TrayMenu {
                open: ShellState.trayMenuOpen && ShellState.trayMenuAnchor === slot
                menu: slot.item.hasMenu ? slot.item.menu : null
                anchorItem: slot
            }
        }
    }

    // ── Overflow ────────────────────────────────────────────────────────────
    // More items than the notch has room for. Not clickable: the icons it stands
    // for have no room either, and a chip that pretends otherwise would be a
    // worse lie than the count.
    Text {
        visible: TrayService.overflow > 0
        anchors.verticalCenter: parent.verticalCenter
        text: "+" + TrayService.overflow
        color: Theme.subtext0
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
    }
}