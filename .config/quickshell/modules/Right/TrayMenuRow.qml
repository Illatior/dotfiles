// One row of a tray menu: a label with its check mark or icon, and — when the
// entry has children — the submenu, which is a whole TrayMenu hanging off this
// row's right edge.
//
// Its own file rather than a delegate inside TrayMenu.qml because a type may
// not instantiate itself; the row needs its menu, and the menu needs its rows.
import QtQuick
import "../../theme"
import "../../state"
import "../../services"

Item {
    id: row

    required property var modelData

    // Whether the menu this row belongs to is up: its submenu only shows while
    // the parent menu does, plus while the pointer is on either of them.
    property bool menuOpen: false

    readonly property var entry:     row.modelData
    readonly property bool isSep:    !!entry.isSeparator
    readonly property bool kids:     !!entry.hasChildren
    readonly property bool off:      !entry.enabled
    readonly property int  check:    entry.checkState
    readonly property string iconUrl: String(entry.icon || "")
    readonly property bool iconOk:   TrayService.hasIconUrl(row.iconUrl)

    // `width` comes from the column instantiating this; the height and the
    // implicit width are the row's own — the implicit one is what makes the
    // menu as wide as its widest label.
    height: row.isSep ? 9 : 30
    implicitWidth: row.isSep ? 0 : body.implicitWidth + 20

    Rectangle {
        anchors.fill: parent
        visible: !row.isSep
        radius: 6
        color: hovRow.hovered && !row.off ? Theme.hover : "transparent"

        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 10
            rightMargin: 10
        }
        visible: row.isSep
        height: 1
        color: Theme.divider
    }

    Row {
        id: body
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        opacity: row.off ? 0.45 : 1

        // Leading slot: the entry's icon, or its check mark when it is a
        // toggle that ships no icon of its own.
        Item {
            width: 18
            height: 20
            visible: row.iconOk || row.check !== 0

            Image {
                id: img
                anchors.centerIn: parent
                width: 16
                height: 16
                visible: row.iconOk && img.status !== Image.Error
                source: row.iconOk ? row.iconUrl : ""
                sourceSize: Qt.size(32, 32)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }

            Text {
                anchors.centerIn: parent
                visible: !row.iconOk && row.check !== 0
                text: row.check === 2 ? "\u2713" : (row.check === 1 ? "\u2013" : "")
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }
        }

        Text {
            text: String(row.entry.text || "")
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }

        // Submenu marker, in a fixed slot so the labels stay in a column
        // whether or not the row opens one.
        Item {
            width: 12
            height: 20
            visible: row.kids

            Text {
                anchors.centerIn: parent
                text: "\u25B8"
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }
        }
    }

    HoverHandler {
        id: hovRow
        enabled: !row.isSep && !row.off
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        enabled: !row.isSep && !row.off

        onTapped: function (point, button) {
            // A row with children only opens its submenu, which hover has
            // already done by the time the click lands.
            if (row.kids)
                return
            row.entry.triggered()
            ShellState.closeAll()
        }
    }

    // The submenu of this row, kept up while either the row or the submenu
    // itself is under the pointer, so the pointer can travel between them.
    TrayMenu {
        id: kids
        subMenu: true
        open: row.menuOpen && row.kids && !row.off && (hovRow.hovered || kids.hovered)
        menu: row.kids ? row.entry : null
        anchorItem: row
    }
}
