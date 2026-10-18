// Hyprland-facing helpers: workspace lists per screen, the active keyboard
// layout, and runtime settings writes for the Customise tab.
//
// Note (Chunk 0 finding F2): Hyprland 0.56 with a Lua config uses the
// non-legacy parser, so `hyprctl keyword` fails and everything must go through
// `hyprctl eval` with Lua. Hyprland.usingLua tells us which mode we are in.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

QtObject {
    id: root

    readonly property bool usingLua: Hyprland.usingLua

    // Workspaces belonging to a given Quickshell screen, sorted by id.
    // Hyprland.monitorFor() maps a ShellScreen to its HyprlandMonitor, and
    // workspace.monitor is that same object, so identity comparison is safe.
    function workspacesFor(screen) {
        if (!screen)
            return []

        var mon = Hyprland.monitorFor(screen)
        if (!mon)
            return []

        var out = []
        var ws = Hyprland.workspaces.values
        for (var i = 0; i < ws.length; i++) {
            if (ws[i].monitor === mon)
                out.push(ws[i])
        }
        out.sort(function (a, b) { return a.id - b.id })
        return out
    }

    // True when `screen` is the monitor Hyprland currently has focused.
    //
    // Popups are instantiated per monitor (one PopupLayer per Scope), so
    // without this check every popup would appear on BOTH displays at once.
    function isFocused(screen) {
        if (!screen)
            return false
        var mon = Hyprland.monitorFor(screen)
        if (!mon)
            return false
        var focused = Hyprland.focusedMonitor
        return focused ? focused === mon : false
    }

    // ── Keyboard layout ─────────────────────────────────────────────────────
    // The main keyboard's active layout as its code from kb_layout, upper-
    // cased ("US", "UA"), for the bar. The `activelayout` event only carries
    // the layout's display name ("English (US)"), so each one re-reads
    // `hyprctl devices` for the index into kb_layout instead.
    property string kbLayout: ""
    property bool _kbAgain: false

    function refreshKbLayout() {
        if (_kb.running) root._kbAgain = true
        else _kb.running = true
    }

    function _parseKb(raw) {
        try {
            var kbs = JSON.parse(raw).keyboards || []
            var main = kbs.filter(function (k) { return k.main })[0] || kbs[0]
            if (!main) return
            var codes = String(main.layout || "").split(",")
            var code = codes[main.active_layout_index] || codes[0] || ""
            root.kbLayout = code.trim().toUpperCase()
        } catch (e) {
            console.warn("HyprlandService: bad devices output:", e)
        }
    }

    property Process _kb: Process {
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector { onStreamFinished: root._parseKb(text) }
        // A switch that landed mid-read gets a fresh read, so the last one wins.
        onExited: if (root._kbAgain) { root._kbAgain = false; running = true }
    }

    property Connections _kbEvents: Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout") root.refreshKbLayout()
        }
    }

    Component.onCompleted: refreshKbLayout()

    // ── Runtime config writes ───────────────────────────────────────────────
    // A SINGLE Process with a real queue.
    //
    // The obvious implementation (reassign `command` then restart) is lossy:
    // applyHyprland() issues ~10 writes back to back, each assignment
    // overwrites the previous command before it has run, and only the last one
    // ever executes. So writes go into `_queue` and the next one is only
    // started from onExited.
    property var _queue: []
    property bool _busy: false

    property Process _proc: Process {
        onExited: function (code) {
            if (code !== 0)
                console.warn("hyprctl failed:", code)
            root._busy = false
            root._drain()
        }
    }

    function _enqueue(argv) {
        root._queue.push(argv)
        root._drain()
    }

    function _drain() {
        if (root._busy || root._queue.length === 0)
            return
        root._busy = true
        var next = root._queue.shift()
        root._proc.command = next
        root._proc.running = true
    }

    // Emit Lua for the non-legacy parser, falling back to keywords for
    // hyprlang configs so this file works on either setup.
    function evalLua(code) {
        _enqueue(["hyprctl", "eval", code])
    }

    function keyword(name, value) {
        _enqueue(["hyprctl", "keyword", name, value])
    }

    // ── Named setters used by the Customise tab ─────────────────────────────
    function setDecoration(field, value) {
        if (usingLua)
            evalLua("hl.config({ decoration = { " + field + " = " + value + " } })")
        else
            keyword("decoration:" + field, String(value))
    }

    function setBlur(field, value) {
        if (usingLua)
            evalLua("hl.config({ decoration = { blur = { " + field + " = " + value + " } } })")
        else
            keyword("decoration:blur:" + field, String(value))
    }

    function setGeneral(field, value) {
        if (usingLua)
            evalLua("hl.config({ general = { " + field + " = " + value + " } })")
        else
            keyword("general:" + field, String(value))
    }

    function setAnimationsEnabled(enabled) {
        if (usingLua)
            evalLua("hl.config({ animations = { enabled = " + (enabled ? "true" : "false") + " } })")
        else
            keyword("animations:enabled", enabled ? "true" : "false")
    }

    // Re-apply the layerrule for our own surfaces (blur behind the bar/popups).
    function setLayerBlur(enabled) {
        if (usingLua)
            evalLua('hl.layer_rule({ match = { namespace = "quickshell" }, blur = ' +
                    (enabled ? "true" : "false") + ", ignore_alpha = 0.0 })")
    }
}
