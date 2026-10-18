// Notifications that persist until explicitly deleted or marked read.
//
// This is the piece with no off-the-shelf equivalent: the freedesktop spec
// lets a client expire a notification, and every shell honours that by
// default. Here nothing auto-dismisses.
//
// State lives in ~/.local/state/quickshell/notifications.json so a shell
// restart (or a Hyprland session restart) does not lose the panel.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

QtObject {
    id: root

    // ── Paths ───────────────────────────────────────────────────────────────
    readonly property string stateDir:
        Quickshell.env("HOME") + "/.local/state/quickshell"
    readonly property string storePath: stateDir + "/notifications.json"

    // ── Live vs. read ───────────────────────────────────────────────────────
    // `active`  — delivered, unread or read, still in the panel.
    // `history` — persisted copies, rehydrated on restart (text only; a
    //             restored notification has no live handle, so actions and
    //             dismiss cannot be invoked on it).
    property var active: []
    property var history: []

    // Unread = delivered and not yet marked read. Drives the bar badge.
    property int unreadCount: 0

    // Do Not Disturb: toasts are suppressed but notifications are still
    // recorded, so nothing is silently lost while DND is on.
    property bool dnd: false

    // Peace: notifications still pop up and land in the panel, they just
    // don't make a sound. (DND silences them too, since it hides the toast.)
    property bool peace: false

    readonly property string soundDir: "/usr/share/sounds/freedesktop/stereo"

    // Suppress toasts during the first moments after startup so a restart
    // doesn't replay a wall of toasts for already-recorded notifications.
    property bool _ready: false

    signal toastRequested(var notification)

    // Most recent live notification object.
    property var latest: null


    readonly property int maxHistory: 200

    // ── Server ──────────────────────────────────────────────────────────────
    property NotificationServer server: NotificationServer {
        id: server
        bodyMarkupSupported: true
        bodySupported: true
        actionsSupported: true

        // Survive a config reload rather than dropping everything on the floor.
        keepOnReload: true

        onNotification: function (n) { root.ingest(n) }
    }

    function ingest(n) {
        // Mandatory: without tracking, Quickshell will not keep the object
        // alive and the callbacks below never fire.
        n.tracked = true

        // NOTE: `expireTimeout` is READ-ONLY (assigning throws a TypeError,
        // which previously aborted this whole function before anything was
        // recorded — so nothing ever persisted). We cannot force "never
        // expire" on the incoming object.
        //
        // Persistence therefore comes from our own store: the entry is written
        // to disk the moment it arrives and is only removed by an explicit
        // delete. If the daemon later reports the notification closed, the
        // record still moves to `history` rather than vanishing.

        // Already known AND still live (re-delivered after a config reload)?
        //
        // Must not test against restored entries: the server restarts its id
        // counter at 1 on every launch, so a fresh notification regularly
        // reuses an id held by a persisted record. Deduping against those made
        // every new notification after a restart silently vanish.
        if (root._live[n.id] !== undefined)
            return


        var entry = root._toEntry(n)
        root.active = [entry].concat(root.active)
        root.unreadCount = root.unreadCount + 1

        // Keep a live handle so dismiss()/actions can be invoked, keyed by the
        // SERVER id.
        root._live[n.id] = n

        n.closed.connect(function () { root.forget(entry.id) })

        root.latest = n
        if (!root.dnd && root._ready) {
            root.toastRequested(n)
            root._showToast(Object.assign({ image: n.image || "" }, entry))
            root._chime(entry.urgency)
        }

        root.save()
    }

    // Raise a notification on our own behalf (Pomodoro completion, wallclock
    // reminders, ...). Unlike an incoming D-Bus notification there is no live
    // handle, so the card is text-only — but it still lands in the persistent
    // panel and survives a restart, which is the point.
    // `quiet`: record it without the island popping up (the caller shows its
    // own, e.g. the pomodoro alarm).
    function notify(summary, body, quiet) {
        var entry = {
            id:        "n" + (++root._uid) + "-" + Date.now(),
            nid:       0,
            appName:   "Quickshell",
            appIcon:   "",
            summary:   summary,
            body:      body || "",
            urgency:   1,
            timestamp: Date.now(),
            read:      false,
            actions:   []
        }
        root.active = [entry].concat(root.active)
        root.unreadCount = root.unreadCount + 1
        root.save()
        if (!quiet && !root.dnd && root._ready) {
            root._showToast(Object.assign({ image: "" }, entry))
            root._chime(entry.urgency)
        }
        return entry.id
    }

    // ── Sound ───────────────────────────────────────────────────────────────
    // freedesktop sound theme (sound-theme-freedesktop). A burst of arrivals
    // restarts the one player rather than stacking chimes.
    property Process _player: Process {}

    function _chime(urgency) {
        if (root.peace) return
        var file = urgency === NotificationUrgency.Critical
            ? "dialog-warning.oga" : "message-new-instant.oga"
        _player.running = false
        _player.command = ["pw-play", root.soundDir + "/" + file]
        _player.running = true
    }

    // ── Toasts ──────────────────────────────────────────────────────────────
    // The popups for new arrivals, stacked in the top-right corner (see
    // windows/NotificationToasts.qml), newest first. Hiding a toast only puts
    // the popup away: the notification stays in the panel.
    //
    // A ListModel rather than an array, so a new arrival inserts one card
    // instead of rebuilding the stack, and the countdowns live here rather
    // than in the cards: every monitor has a window showing this one model,
    // and hovering any of them (holdToasts) pauses them all. Each row is
    // { tid, remaining }; the entry itself, with its live `image` (never
    // persisted — it only resolves while the sender's notification is alive),
    // is toastEntry(tid). Critical notifications don't count down at all.
    readonly property int toastDuration: 6000
    readonly property int maxToasts: 5
    property ListModel toasts: ListModel {}
    property var _toastData: ({})
    property int _toastHolds: 0
    readonly property bool toastsHeld: _toastHolds > 0

    function toastEntry(tid) {
        return root._toastData[tid] || null
    }

    function _showToast(entry) {
        root._toastData[entry.id] = entry
        root.toasts.insert(0, { tid: entry.id, remaining: root.toastDuration })
        while (root.toasts.count > root.maxToasts)
            root.dropToast(root.toasts.get(root.toasts.count - 1).tid)
    }

    function dropToast(tid) {
        for (var i = 0; i < root.toasts.count; i++) {
            if (root.toasts.get(i).tid === tid) {
                root.toasts.remove(i)
                break
            }
        }
        delete root._toastData[tid]
        // Nothing left to hold open: drop any hold a window that went away
        // mid-hover never got to release.
        if (root.toasts.count === 0)
            root._toastHolds = 0
    }

    function holdToasts(on) {
        root._toastHolds = Math.max(0, root._toastHolds + (on ? 1 : -1))
    }

    // Wall-clock steps rather than a fixed decrement, so a stalled frame (or
    // a suspend) still counts the time that went by.
    property real _lastTick: 0

    property Timer _toastTick: Timer {
        interval: 100
        repeat: true
        running: root.toasts.count > 0
        onRunningChanged: root._lastTick = Date.now()
        onTriggered: {
            var now = Date.now()
            var step = now - root._lastTick
            root._lastTick = now
            if (root._toastHolds > 0)
                return
            for (var i = root.toasts.count - 1; i >= 0; i--) {
                var row = root.toasts.get(i)
                var e = root._toastData[row.tid]
                if (e && e.urgency === 2)
                    continue
                var left = row.remaining - step
                if (left <= 0) root.dropToast(row.tid)
                else root.toasts.setProperty(i, "remaining", left)
            }
        }
    }

    function _indexOf(id) {
        for (var i = 0; i < root.active.length; i++)
            if (root.active[i].id === id)
                return i
        return -1
    }

    // Entry identity is independent of the server's numeric id: that counter
    // restarts at 1 on every launch, so persisted entries and new arrivals
    // would collide. `id` is ours (unique forever); `nid` is the server's and
    // is only used to find the live handle.
    property int _uid: 0

    function _toEntry(n) {
        var acts = []
        var list = n.actions || []
        for (var i = 0; i < list.length; i++)
            acts.push({ id: list[i].identifier, text: list[i].text })

        return {
            id:         "n" + (++root._uid) + "-" + Date.now(),
            nid:        n.id,
            appName:    n.appName || "",
            appIcon:    n.appIcon || "",
            summary:    n.summary || "",
            body:       n.body || "",
            urgency:    n.urgency,
            timestamp:  Date.now(),
            read:       false,
            actions:    acts
        }
    }

    // Ephemeral map of live handles, keyed by notification id.
    property var _live: ({})

    // ── Mutations ───────────────────────────────────────────────────────────
    // Two ways out of the panel: the ✕ on one card (dismiss), and "Clear all"
    // for every card plus the saved history. Acting on a notification (its
    // default action or a button) dismisses it too.

    // Out of the panel. Dismissing the live object tells the sending app it
    // was closed, so it can un-highlight.
    function dismiss(id) {
        var n = root._findLive(id)
        if (n) {
            try { n.dismiss() } catch (e) { /* already gone */ }
            delete root._live[id]
        }
        root.forget(id)
    }

    function clearAll() {
        var list = root.active.slice()
        for (var i = 0; i < list.length; i++)
            root.dismiss(list[i].id)
        root.clearHistory()
    }

    function clearHistory() {
        root.history = []
        root.save()
    }

    // Called when the daemon reports the notification closed, and by
    // dismiss(). Moves the entry to history rather than dropping it, so
    // "delete" is the only destructive action.
    function forget(id) {
        var idx = root._indexOf(id)
        if (idx === -1)
            return
        var entry = root.active[idx]
        var rest = root.active.slice()
        rest.splice(idx, 1)
        root.active = rest
        root.dropToast(id)

        if (!entry.read)
            root.unreadCount = Math.max(0, root.unreadCount - 1)

        root.history = [entry].concat(root.history).slice(0, root.maxHistory)

        // A still-live entry that got dismissed externally is no longer live.
        if (entry.nid !== undefined && root._live[entry.nid])
            delete root._live[entry.nid]

        root.save()
    }

    function invoke(id, actionId) {
        var n = root._findLive(id)
        if (!n)
            return
        var list = n.actions || []
        for (var i = 0; i < list.length; i++) {
            if (list[i].identifier === actionId) {
                list[i].invoke()
                return
            }
        }
    }

    function isLive(id) {
        return root._findLive(id) !== null
    }

    // Resolve an entry id to its live server handle, or null.
    function _findLive(id) {
        var idx = root._indexOf(id)
        if (idx === -1)
            return null
        var nid = root.active[idx].nid
        if (nid === undefined)
            return null
        return root._live[nid] || null
    }

    // ── Persistence ─────────────────────────────────────────────────────────
    function save() {
        var payload = JSON.stringify({
            active:  root.active,
            history: root.history,
            unread:  root.unreadCount,
            dnd:     root.dnd,
            peace:   root.peace
        })
        _writer.command = ["bash", "-c",
            "mkdir -p '" + root.stateDir + "' && " +
            "cat > '" + root.storePath + "' <<'QSJSONEOF'\n" +
            payload + "\nQSJSONEOF"]
        _writer.running = true
    }

    property Process _writer: Process {
        onExited: function (code) {
            if (code !== 0)
                console.warn("notifications: save failed", code)
        }
    }

    property FileView _store: FileView {
        path: root.storePath
        watchChanges: false
        onLoaded: root._restore(text())
    }

    function _restore(raw) {
        if (!raw || raw.trim() === "")
            return
        try {
            var obj = JSON.parse(raw)

            // Drop the persisted server ids: the counter restarts at 1 on every
            // launch, so keeping them would alias new notifications onto stale
            // restored entries (making isLive()/dismiss() hit the
            // wrong card). Restored entries are display-only until re-delivered.
            function scrub(list) {
                var out = []
                for (var i = 0; i < list.length; i++) {
                    var e = list[i]
                    delete e.nid
                    out.push(e)
                }
                return out
            }

            // Seed the counter past any restored id so a fresh entry can never
            // reuse a persisted one within the same launch.
            var all = (obj.active || []).concat(obj.history || [])
            for (var j = 0; j < all.length; j++) {
                var m = /^n(\d+)-/.exec(all[j].id || "")
                if (m && Number(m[1]) > root._uid)
                    root._uid = Number(m[1])
            }

            root.active = scrub(obj.active || [])
            root.history = scrub(obj.history || [])
            root.unreadCount = obj.unread || root.active.filter(function (e) {
                return !e.read
            }).length
            root.dnd = obj.dnd === true
            root.peace = obj.peace === true
        } catch (e) {
            console.warn("notifications: restore failed:", e)
        }
    }

    // ── Startup ─────────────────────────────────────────────────────────────
    property Timer _startup: Timer {
        interval: 800
        running: true
        onTriggered: root._ready = true
    }

    Component.onCompleted: _store.reload()
}
