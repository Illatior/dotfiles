// Every widget the island can open. This list is the only place a widget is
// declared: the home grid renders the non-hidden ones, and
// `qs ipc call island open <id>` looks ids up here.
//
// Adding a widget:
//   1. Write widgets/<Name>Widget.qml following the contract in
//      WidgetHost.qml (implicit size, `active`, close via ShellState).
//   2. Set `source` on its entry below. Entries without a source open the
//      placeholder, so a widget can be listed before it is built.
//   3. Optional keybind: `qs ipc call island toggle <id>` in hypr's
//      keybinds.lua.
pragma Singleton
import QtQuick

QtObject {
    id: root

    // id:     stable name used by IPC, keybinds and ShellState.islandWidget
    // name:   label on the home grid
    // icon:   Nerd Font glyph
    // source: QML file in this directory, "" until the widget exists
    // hidden: (optional) left off the home grid — for widgets opened by
    //         something other than a pick: the shell itself (the polkit
    //         prompt), a keybind/IPC call (the clipboard, bound in hyprland.lua),
    //         or a button in the control center header (the power menu).
    //         `qs ipc call island toggle <id>` still opens it.
    // passive: (optional) shown without taking the keyboard or the rest of
    //          the screen — it doesn't interrupt typing, and clicks outside
    //          go through (e.g. the pomodoro alarm)
    readonly property var widgets: [
        { id: "theme",      name: "Themes",     icon: "\u{f03d8}", source: "ThemeWidget.qml" },   // wallpapers = themes
        { id: "settings",   name: "Settings",   icon: "\uf013", source: "SettingsWidget.qml" },
        { id: "clipboard",  name: "Clipboard",  icon: "\uf0ea", source: "ClipboardWidget.qml", hidden: true },
        { id: "pomodoro",   name: "Pomodoro",   icon: "\uf2f2", source: "PomodoroWidget.qml" },
        { id: "alarm",      name: "Alarms",     icon: "\uf0f3", source: "AlarmWidget.qml" },
        { id: "power",      name: "Power",      icon: "\uf011", source: "PowerWidget.qml", hidden: true },
        { id: "stats",      name: "Stats",      icon: "\u{f0128}", source: "StatsWidget.qml" },
        { id: "polkit",     name: "Authenticate", icon: "\uf023", source: "PolkitWidget.qml", hidden: true },
        { id: "pomodoro-alarm", name: "Pomodoro alarm", icon: "\uf0f3", source: "PomodoroAlarmWidget.qml", hidden: true, passive: true },
        { id: "alarm-ringing", name: "Alarm ringing", icon: "\uf0f3", source: "AlarmRingingWidget.qml", hidden: true, passive: true }
    ]

    // What the home grid shows.
    readonly property var pickable: widgets.filter(function (w) { return !w.hidden })

    // The grid of widgets itself; not listed above, so it never tiles itself.
    readonly property var home: ({ id: "home", name: "Widgets", icon: "\uf00a",
                                   source: "WidgetHome.qml" })

    function find(id) {
        if (id === "home") return root.home
        for (var i = 0; i < root.widgets.length; i++)
            if (root.widgets[i].id === id) return root.widgets[i]
        return null
    }
}
