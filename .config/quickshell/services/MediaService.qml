// Now playing, and per-source volume, for the control center's media card.
//
// A "source" is a media player — an MPRIS player with a track loaded: Spotify,
// a browser playing YouTube or Twitch, YouTube Music. Audio from anything that
// is not a media player (a game, a call, notification sounds) is deliberately
// left out; it is still in the system mixer, which the card's title opens.
//
// The rows come from the players rather than from the PipeWire streams because
// a browser registers one player but can hold several streams, and nothing
// says which stream is the one playing: pairing them stream-first gave a
// paused YouTube tab the Twitch track that was actually playing, and left the
// Twitch stream with no player at all.
//
// Volume still goes through PipeWire, on the streams of the player's app, never
// through MPRIS `volume`: that is the player's own internal gain, and Firefox
// accepts writes to it without touching the audio (verified — set 0.5 over
// MPRIS and `wpctl` on the matching stream stayed at 0.79), so a slider bound
// to it would move and change nothing. Spotify is the opposite case: there
// MPRIS volume *is* the stream volume. Going through the streams makes one
// slider mean the same thing everywhere.
//
// Replaces waybar's custom/playback module and its current_playback.sh /
// should_show_playback.sh scripts.
pragma Singleton
import QtQuick
import Quickshell.Services.Mpris
import "."

QtObject {
    id: root

    // Every media player with a track loaded, as plain snapshots:
    // { player, id, name, streams }. `player` and `streams` are the live
    // objects, never copied values: a delegate reads title, artwork and volume
    // straight off them so its bindings stay reactive. `id` is the player's
    // bus name; `streams` may be empty (a player that has gone quiet).
    //
    // Sorted by name and then by id rather than by playback state, so rows
    // never jump out from under a volume bar that is being dragged.
    readonly property var sources: {
        var streams = AudioService.playbackStreams     // re-runs as streams come and go
        var players = Mpris.players.values             // and as players register
        var out = []
        for (var i = 0; i < players.length; i++) {
            var p = players[i]
            if (!p || p.trackTitle === "")
                continue
            var own = _streamsOf(p, streams)
            out.push({
                player: p,
                id: p.dbusName,
                // PipeWire's app name ("Zen") reads better than MPRIS's
                // identity ("Mozilla zen"), when there is a stream to ask.
                name: own.length > 0 ? AudioService.streamName(own[0])
                                     : (p.identity || p.desktopEntry || "Player"),
                streams: own
            })
        }
        out.sort(function (a, b) {
            var byName = String(a.name).localeCompare(String(b.name))
            return byName !== 0 ? byName : String(a.id).localeCompare(String(b.id))
        })
        return out
    }

    // The playback streams of a player's app, matched by name: `desktopEntry`
    // is the app's real name ("zen", "spotify") and lines up with PipeWire's
    // application.name; `identity` is a display string ("Mozilla zen") that
    // only sometimes does. When the app has several streams and some are
    // named after the track — browsers name a tab's stream after the tab —
    // just those, so two players of one browser don't share a slider.
    function _streamsOf(player, streams) {
        var names = [_norm(player.desktopEntry), _norm(player.identity)]
        var app = streams.filter(function (s) {
            var keys = _keysOf(s)
            for (var i = 0; i < names.length; i++)
                if (names[i] !== "" && keys.indexOf(names[i]) !== -1)
                    return true
            return false
        })
        var title = _norm(player.trackTitle)
        if (app.length > 1 && title !== "") {
            var named = app.filter(function (s) {
                return _norm(((s.properties || {})["media.name"])).indexOf(title) !== -1
            })
            if (named.length > 0)
                return named
        }
        return app
    }

    // The names a stream can be recognised by, most specific first.
    function _keysOf(stream) {
        var props = (stream && stream.properties) || {}
        var raw = [props["application.id"], props["application.name"],
                   stream.name, stream.description]
        var out = []
        for (var i = 0; i < raw.length; i++) {
            var k = _norm(raw[i])
            if (k !== "" && out.indexOf(k) === -1)
                out.push(k)
        }
        return out
    }

    function _norm(s) {
        return String(s === undefined || s === null ? "" : s)
            .toLowerCase().trim().replace(/\.desktop$/, "")
    }

    // ── Per-source actions ───────────────────────────────────────────────────
    // Volume and mute act on every stream of the source, so a browser's tabs
    // move together; the first stream is the one the card reads back.

    function setSourceVolume(source, v) {
        if (!source) return
        for (var i = 0; i < source.streams.length; i++)
            AudioService.setStreamVolume(source.streams[i], v)
    }

    function toggleSourceMute(source) {
        if (!source || source.streams.length === 0) return
        var first = source.streams[0].audio
        var mute = !(first && first.muted)
        for (var i = 0; i < source.streams.length; i++)
            AudioService.setStreamMuted(source.streams[i], mute)
    }

    function toggleSource(source) {
        var p = source && source.player
        if (p && p.canTogglePlaying) p.togglePlaying()
    }

    function nextSource(source) {
        var p = source && source.player
        if (p && p.canGoNext) p.next()
    }

    function previousSource(source) {
        var p = source && source.player
        if (p && p.canGoPrevious) p.previous()
    }

    // ── A single source, for the `media` IPC target ──────────────────────────
    // Read from MPRIS rather than from `sources`, so `media toggle` still works
    // for a player that is registered but is not currently sending audio.

    // Prefer a player that is actually playing, so a paused browser tab doesn't
    // hide a playing one.
    readonly property var player: {
        var players = Mpris.players.values
        if (players.length === 0)
            return null
        for (var i = 0; i < players.length; i++)
            if (players[i].isPlaying)
                return players[i]
        for (var j = 0; j < players.length; j++)
            if (players[j].trackTitle !== "")
                return players[j]
        return players[0]
    }

    readonly property bool active: !!player && player.trackTitle !== ""

    readonly property string title:  player ? (player.trackTitle  || "") : ""
    readonly property string artist: player ? (player.trackArtist || "") : ""
    readonly property string album:  player ? (player.trackAlbum  || "") : ""
    readonly property string artUrl: player ? (player.trackArtUrl || "") : ""

    readonly property bool playing: player ? player.isPlaying : false

    readonly property bool canToggle: player ? player.canTogglePlaying : false
    readonly property bool canNext:   player ? player.canGoNext       : false
    readonly property bool canPrev:   player ? player.canGoPrevious   : false

    function toggle() {
        if (player && player.canTogglePlaying)
            player.togglePlaying()
    }

    function next() {
        if (player && player.canGoNext)
            player.next()
    }

    function previous() {
        if (player && player.canGoPrevious)
            player.previous()
    }
}
