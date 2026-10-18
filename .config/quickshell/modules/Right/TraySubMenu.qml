// The host for a tray menu one level down: the menu itself, wrapped in an Item
// so the Loader that builds it (see TrayMenu.qml) gets a handle to drive.
//
// The wrapper exists for two reasons. QML rejects a component that instantiates
// itself, so TrayMenu.qml cannot contain `TrayMenu {}` and has to create this
// file by URL instead. And Loader only reports `item` for Item roots, while
// TrayMenu is a window, so everything the owning row needs to set or read —
// which menu, where to anchor, whether it is up, whether the pointer is on it —
// is declared here and handed to the window inside.
import QtQuick

Item {
    id: host

    // The menu to draw, what it hangs off, and whether it should be up: all
    // driven by the row that owns this submenu.
    property var menu: null
    property var anchorItem: null
    property bool open: false

    // True while the pointer is on the menu itself, so the row can keep it up
    // while the pointer travels off the row and into it.
    readonly property bool hovered: win.hovered

    // No geometry of its own: the menu is a window, this is just its handle.
    implicitWidth: 0
    implicitHeight: 0

    TrayMenu {
        id: win
        subMenu: true
        menu: host.menu
        anchorItem: host.anchorItem
        open: host.open
    }
}
