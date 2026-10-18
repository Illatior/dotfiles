// System tray: the icons running apps put in the tray (network manager,
// Bluetooth, Discord, Steam, ...).
//
// Quickshell hosts the StatusNotifierWatcher itself, so there is nothing to
// start next to this config — but the watcher only exists once something
// references the SystemTray singleton, which is why the bar's tray strip binds
// to this service rather than to SystemTray directly.
//
// `items` is what the bar draws: sorted, deduped and capped. The cap is a
// consequence of the bar, not of the tray — the right notch is width-clamped,
// so a long tray would be cut mid-icon; whatever does not fit is counted in
// `overflow` and shown as "+N".
//
// Items register in bursts (an app usually registers itself and one entry per
// window), so the list is sorted here rather than left in the model's order:
// an icon must not hop to another position while it is being clicked.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../theme"
import "../state"

QtObject {
    id: root

    // Every registered item, live objects and not copies, so delegates keep
    // reacting to icon and status changes without a refresh here.
    readonly property var all: {
        var out = []
        var seen = ({})
        var items = SystemTray.items.values
        for (var i = 0; i < items.length; i++) {
            var item = items[i]
            if (!item)
                continue
            // Some apps register the same icon twice under different service
            // names. Items without an id are kept: they can't be compared.
            var id = String(item.id || "")
            if (id !== "" && seen[id] === true)
                continue
            seen[id] = true
            out.push(item)
        }
        out.sort(function (a, b) {
            var byName = String(a.title).localeCompare(String(b.title))
            return byName !== 0 ? byName : String(a.id).localeCompare(String(b.id))
        })
        return out
    }

    readonly property var items:   all.slice(0, Theme.trayMaxIcons)
    readonly property int overflow: Math.max(0, all.length - items.length)

    // An app whose menu is open has gone away — it quit, or a new icon pushed
    // it out of the capped strip. Drop the open state with it, or the dismiss
    // layer would stay up over the whole screen with nothing behind it.
    onItemsChanged: {
        if (!ShellState.trayMenuOpen)
            return
        for (var i = 0; i < root.items.length; i++) {
            if (root.items[i] === ShellState.trayMenuItem)
                return
        }
        ShellState.closeAll()
    }

    // ── Icons ────────────────────────────────────────────────────────────────
    // Whether an item has an icon that will actually draw.
    //
    // The url comes as `image://icon/<name>`, with `?path=<dir>` when the app
    // ships its own icons. When the name is in neither that dir nor the icon
    // theme, Qt paints a magenta checkerboard and still reports the image as
    // ready — so Image.status cannot see it, and neither can the painted size,
    // which falls back to the box. The theme is therefore asked directly.
    //
    // An app's own icon dir is taken on trust; a theme icon only when the theme
    // really has it. Solaar advertises "battery-080", which is in no theme here
    // (breeze ships "battery-080-charging-symbolic" and friends), so it gets the
    // label fallback instead of a magenta box.
    function hasIcon(item) {
        if (!item)
            return false
        return hasIconUrl(item.icon)
    }

    // The same check for anything that hands over an icon url — a tray item or
    // an entry in its menu. Anything that is not an image://icon/ name (an app
    // shipping the pixels itself, say) is taken on trust: only a theme *name*
    // can be missing while still looking like a url.
    function hasIconUrl(url) {
        var u = String(url || "")
        if (u === "")
            return false
        if (u.indexOf("image://icon/") === -1)
            return true
        if (u.indexOf("?path=") !== -1)
            return true
        return Quickshell.hasThemeIcon(iconName(u))
    }

    // The bare icon name out of an image://icon/<name>[?…] url.
    function iconName(url) {
        var rest = String(url).substring(String(url).indexOf("icon/") + 5)
        var query = rest.indexOf("?")
        return query === -1 ? rest : rest.substring(0, query)
    }

    // ── Item actions ─────────────────────────────────────────────────────────
    // Left click: open the window, toggle the mute, whatever the app calls its
    // primary action.
    function activate(item) {
        if (item)
            item.activate()
    }

    // Middle click: the app's secondary action, e.g. "pause" on a player.
    function secondaryActivate(item) {
        if (item)
            item.secondaryActivate()
    }

    // Scroll over an icon, for the mixers that take volume this way.
    function scroll(item, degrees) {
        if (item && degrees !== 0)
            item.scroll(Math.round(degrees / 120), false)
    }

    // A short label for an item, used as the icon's fallback.
    function label(item) {
        if (!item)
            return ""
        return String(item.title || item.id || "?").charAt(0).toUpperCase()
    }

    // Items that need something from the user — a flat battery, a connection
    // that dropped. The status enum only exists in the service module, so the
    // meaning of it is kept here rather than in the tray strip.
    function needsAttention(item) {
        return !!item && item.status === Status.NeedsAttention
    }
}