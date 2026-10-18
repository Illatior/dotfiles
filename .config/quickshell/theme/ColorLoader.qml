// Watches the active theme's quickshell palette and exposes it as colours.
//
// Not a singleton — instantiated as a property inside Colors.qml. This keeps
// the file-watching machinery out of the singleton itself, which is the same
// split Brain_Shell uses between ColorLoader.qml and Colors.qml.
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // ── Palette (fallback = Catppuccin Mocha) ────────────────────────────────
    // Defaults matter: the shell must render something sane before the theme
    // file is read, and must keep rendering if the file is missing entirely.
    property color rosewater: "#f5e0dc"
    property color flamingo:  "#f2cdcd"
    property color pink:      "#f5c2e7"
    property color mauve:     "#cba6f7"
    property color red:       "#f38ba8"
    property color maroon:    "#eba0ac"
    property color peach:     "#fab387"
    property color yellow:    "#f9e2af"
    property color green:     "#a6e3a1"
    property color teal:      "#94e2d5"
    property color sky:       "#89dceb"
    property color sapphire:  "#74c7ec"
    property color blue:      "#89b4fa"
    property color lavender:  "#b4befe"
    property color text:      "#cdd6f4"
    property color subtext1:  "#bac2de"
    property color subtext0:  "#a6adc8"
    property color overlay2:  "#9399b2"
    property color overlay1:  "#7f849c"
    property color overlay0:  "#6c7086"
    property color surface2:  "#585b70"
    property color surface1:  "#45475a"
    property color surface0:  "#313244"
    property color base:      "#1e1e2e"
    property color mantle:    "#181825"
    property color crust:     "#11111b"

    property string mode: "dark"

    // True once a theme file has been successfully parsed. The Customise tab
    // uses this to tell "no theme loaded" from "theme is genuinely Mocha".
    property bool loaded: false

    // ── File watcher ────────────────────────────────────────────────────────
    // theme-set.sh repoints ~/.config/theme/current, so the path itself is
    // stable and only the contents change — watchChanges is enough.
    property FileView file: FileView {
        path: Quickshell.env("HOME") + "/.config/theme/current/quickshell-colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parse(text())
        onLoadFailed: root.loaded = false
    }

    // theme-set.sh repoints the `current` symlink instead of editing this file
    // in place, so the watched inode never changes and no change event fires.
    // The shell calls this over IPC after a switch. Reloading the FileView by
    // toggling the path forces a fresh read of the new target.
    function forceReload() {
        if (!file.path)
            return
        file.path = ""
        file.path = Quickshell.env("HOME") + "/.config/theme/current/quickshell-colors.json"
    }

    function parse(raw) {
        if (!raw || raw.trim() === "")
            return

        var obj
        try {
            obj = JSON.parse(raw)
        } catch (e) {
            // Malformed JSON — keep the current palette rather than flashing
            // the fallback over a live theme.
            console.warn("quickshell-colors.json: parse failed:", e)
            return
        }

        // Only overwrite keys actually present, so a partial theme file still
        // leaves sensible values for the rest.
        for (var key in obj) {
            if (key === "mode") {
                root.mode = obj[key]
                continue
            }
            if (root[key] !== undefined && typeof obj[key] === "string")
                root[key] = obj[key]
        }

        root.loaded = true
    }
}
