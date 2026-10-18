// An app's own tray menu, drawn here rather than by the platform.
//
// quickshell's native path (StatusNotifierItem.display()) hands the menu to Qt
// as a QMenu and asks for a popup under the icon; on this machine that popup
// is never mapped — the Wayland QPA plugin implements no platform menus, and
// the gtk3 theme has no dbusmenu server behind it either — so the call reports
// success and nothing ever appears. The menu itself is fully readable, though:
// QsMenuOpener loads the D-Bus layout, and emitting QsMenuEntry::triggered is
// exactly what the native path does when an action is clicked (DBusMenuItem
// answers it with a "clicked" Event), so this menu reaches the app the way the
// native one would.
//
// Recursive: a row with children opens a second TrayMenu hanging off its right
// edge, one level per submenu. Every instance is hidden again by ShellState
// (which the dismiss layer and Escape close through), so there is one owner of
// "what is open" and no way to stack two of them.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../theme"
import "../../state"
import "../../services"

PopupWindow {
    id: root

    // The menu to draw: the tray item's handle at the top level, the submenu
    // entry itself one level down. No handle, nothing to show.
    property var menu: null

    // What the menu hangs off — the icon at the top level, the row that owns a
    // submenu below it. The anchor window follows the item's own window, so a
    // submenu is always positioned inside the window holding its row.
    property var anchorItem: null

    // Whether this menu should be up. The top level binds it to ShellState, a
    // submenu to the hover on its row *and* on itself, so the pointer can
    // travel into the menu without it closing on the way.
    property bool open: false

    // A menu hung off a row rather than off an icon: same window, same code,
    // anchored to the row's right edge instead of the icon's bottom.
    property bool subMenu: false

    // The layout is fetched only while shown: opening refs the handle (the app
    // is told "opened"), closing unrefs it — the pairing the native path gets
    // from QsMenuAnchor.
    QsMenuOpener {
        id: opener
        menu: root.open ? root.menu : null
    }

    readonly property int count: opener.children.values.length

    // Mapped only once there is something to draw: the layout lands a few
    // milliseconds after the open, and mapping an empty panel first would
    // flash a blank box. A menu with no entries has nothing to show anyway.
    visible: root.open && root.count > 0
    color: "transparent"

    // Breathing room around the rows.
    readonly property int pad: 8

    implicitWidth: list.implicitWidth + pad * 2
    implicitHeight: list.implicitHeight + pad * 2

    // True while the pointer is on the surface: a submenu binds to it so the
    // row that opened it can stop being hovered without the menu vanishing.
    readonly property bool hovered: hov.hovered

    // The top level hangs from the icon's bottom-right corner, a submenu from
    // its row's right edge; Flip/Slide keep either end of it on screen.
    anchor.item: root.anchorItem
    anchor.edges: root.subMenu ? (Edges.Right | Edges.Top) : (Edges.Bottom | Edges.Right)
    anchor.gravity: root.subMenu ? (Edges.Bottom | Edges.Right) : (Edges.Bottom | Edges.Left)
    anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide

    // Escape, for when this window rather than the dismiss layer has focus.
    Shortcut {
        sequence: "Escape"
        enabled: root.open
        onActivated: ShellState.closeAll()
    }

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: Theme.cornerRadiusSmall
        color: Theme.popupBgSolid
        border.width: 1
        border.color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.07)

        HoverHandler { id: hov }

        // The rows set the menu's size: the widest label, plus the padding
        // this window adds around the column. A layout rather than a Column:
        // the rows stretch to the widest one, and a Column sizes itself off
        // its rows' widths — which would be its own, i.e. nothing at all.
        ColumnLayout {
            id: list
            x: root.pad
            y: root.pad
            spacing: 0

            Repeater {
                model: opener.children.values

                delegate: Item {
                    id: row

                    required property var modelData

                    readonly property var entry:     row.modelData
                    readonly property bool isSep:    !!entry.isSeparator
                    readonly property bool kids:     !!entry.hasChildren
                    readonly property bool off:      !entry.enabled
                    readonly property int  check:    entry.checkState
                    readonly property string iconUrl: String(entry.icon || "")
                    readonly property bool iconOk:   TrayService.hasIconUrl(row.iconUrl)

                    Layout.fillWidth: true
                    implicitHeight: row.isSep ? 9 : 30
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

                        // Leading slot: the entry's icon, or its check mark
                        // when it is a toggle without one.
                        Item {
                            width: 18
                            height: 20
                            visible: row.iconOk || row.check !== 0

                            Image {
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                visible: row.iconOk
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

                        // Submenu marker, in a fixed slot so labels stay in a
                        // column whether or not the row opens one.
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
                            // A row with children only opens its submenu,
                            // which hover has already done by now.
                            if (row.kids)
                                return
                            row.entry.triggered()
                            ShellState.closeAll()
                        }
                    }

                    // The submenu of this row, kept up while either the row or
                    // the submenu itself is under the pointer.
                    //
                    // Built by URL through a Loader rather than written as
                    // `TrayMenu {}`: QML rejects a component that instantiates
                    // itself, so the nested menu has to be created dynamically.
                    Loader {
                        id: kids
                        active: root.open && row.kids && !row.off
                                && (hovRow.hovered || (kids.item && kids.item.hovered))
                        source: Qt.resolvedUrl("TraySubMenu.qml")

                        Binding { target: kids.item; property: "menu";       value: row.kids ? row.entry : null }
                        Binding { target: kids.item; property: "anchorItem"; value: row }
                        Binding { target: kids.item; property: "open";       value: kids.active }
                    }
                }
            }
        }
    }
}
