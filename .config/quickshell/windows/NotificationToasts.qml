// New-notification popups: a stack of cards in the top-right corner, just
// below the right notch the control center grows out of, newest on top. Up to
// NotificationService.maxToasts at once; each counts down and slides away on
// its own, and resting the pointer anywhere on the stack pauses them all.
//
// Only the focused monitor's stack shows. It hides while the control center
// is open: the panel then covers this corner, and its main page lists every
// notification anyway.
//
// The surface runs down the monitor's right edge so adding a card never
// resizes it; the input mask is just the cards, so the rest of that strip
// clicks through to the windows below.
import Quickshell
import QtQuick
import "../theme"
import "../state"
import "../services"
import "../popups"

PanelWindow {
    id: root

    readonly property bool active: HyprlandService.isFocused(root.screen)
    readonly property int gap: 8

    anchors {
        top: true
        right: true
        bottom: true
    }

    // Below the bar's notch and inside the frame's right edge.
    margins.top: Theme.notchHeight
    margins.right: Theme.borderWidth

    implicitWidth: Theme.popupWidth + gap * 2

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    // Stays mapped a moment after the last card goes, so its slide-out plays.
    visible: active && !ShellState.controlCenterOpen
             && (NotificationService.toasts.count > 0 || linger.running)

    Timer {
        id: linger
        interval: 300
    }

    Connections {
        target: NotificationService.toasts
        function onCountChanged() {
            if (NotificationService.toasts.count === 0) linger.restart()
        }
    }

    mask: Region {
        x: list.x
        y: list.y
        width: list.width
        height: list.height
    }

    // Pausing goes through the window's own visibility too: a stack that
    // unmaps under the pointer never sees the hover end.
    readonly property bool held: hover.hovered && root.visible
    onHeldChanged: NotificationService.holdToasts(held)
    Component.onDestruction: if (held) NotificationService.holdToasts(false)

    ListView {
        id: list

        anchors { top: parent.top; right: parent.right; topMargin: root.gap; rightMargin: root.gap }
        width: Theme.popupWidth
        height: Math.min(contentHeight, root.height - root.gap * 2)
        spacing: root.gap
        interactive: false
        model: NotificationService.toasts

        delegate: NotificationToast {
            width: list.width
        }

        HoverHandler { id: hover }

        // Cards slide in from the screen edge and back out to it; the rest of
        // the stack eases into the gap.
        add: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
                NumberAnimation { property: "x"; from: Theme.popupWidth / 3; duration: 280; easing.type: Easing.OutCubic }
            }
        }

        remove: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; to: 0; duration: 200 }
                NumberAnimation { property: "x"; to: Theme.popupWidth / 3; duration: 240; easing.type: Easing.InCubic }
            }
        }

        displaced: Transition {
            NumberAnimation { property: "y"; duration: 240; easing.type: Easing.OutCubic }
        }
    }
}
