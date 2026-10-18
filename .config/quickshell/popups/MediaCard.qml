// The control center's audio-sources card: every media player with something
// loaded (Spotify, a browser on YouTube or Twitch, YouTube Music …), each with
// its own track info, its own transport and its own volume bar. Other audio —
// games, calls, notification sounds — is left to the system mixer, which the
// card's title opens.
//
// Capped at a bit over two rows and scrolling past that. A heavy audio day
// would otherwise push the notifications list below off the page, and losing
// notifications to see what is playing is the wrong trade — so the list scrolls
// instead. Rows are MPRIS players (see MediaService); the volume bar moves the
// player app's PipeWire streams, so it always changes real output.
import QtQuick
import Quickshell
import "../theme"
import "../state"
import "../services"
import "../components"

Item {
    id: card

    // Which source has its volume bar open, by MPRIS bus name. Keyed by id
    // rather than by the row object so the open bar survives the list being
    // rebuilt whenever a player, a track or a stream comes or goes.
    property string openId: ""

    // Roughly two and a half collapsed rows. A row grows by the height of its
    // volume bar while that bar is open.
    readonly property int maxListHeight: 150

    // Nothing playing means no card at all. Column skips invisible children
    // (verified), so everything below closes up rather than leaving a gap.
    visible: MediaService.sources.length > 0
    implicitHeight: visible ? body.implicitHeight : 0

    function toggleOpen(id) {
        openId = openId === id ? "" : id
    }

    // The full system mixer, for everything this card leaves out. The control
    // center goes away so the window it opens isn't hidden under it.
    function openMixer() {
        Quickshell.execDetached(["pavucontrol"])
        ShellState.closeAll()
    }

    Column {
        id: body
        width: parent.width
        spacing: 6

        // The title doubles as the way into the mixer (pavucontrol).
        Row {
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Audio sources"
                color: titleHover.hovered ? Theme.text : Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall

                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            CenteredIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf1de"                           // sliders
                size: 9
                color: titleHover.hovered ? Theme.accent : Theme.overlay1

                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            HoverHandler {
                id: titleHover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: card.openMixer()
            }
        }

        ListView {
            id: list
            width: parent.width
            height: Math.min(contentHeight, card.maxListHeight)
            clip: true
            spacing: 8
            boundsBehavior: Flickable.StopAtBounds
            model: MediaService.sources

            delegate: MediaRow {
                width: list.width
                open: card.openId === modelData.id
                onToggleRequested: function (id) { card.toggleOpen(id) }
            }
        }
    }

    // ── One source ───────────────────────────────────────────────────────────
    //
    // Everything the row shows is read live off `player` and `streams`, which
    // are the MPRIS player and its tracked PipeWire nodes rather than copied
    // values, so the title, artwork and volume stay current.

    component MediaRow: Rectangle {
        id: row

        required property var modelData

        readonly property var source: modelData
        readonly property var player: source.player
        // A player can be up with no stream of its own (paused long enough for
        // the app to close it): it keeps its row and transport, minus volume.
        readonly property bool hasStreams: source.streams.length > 0
        readonly property var stream: hasStreams ? source.streams[0] : null
        readonly property var audio: stream ? stream.audio : null
        readonly property bool muted: audio ? audio.muted : false

        readonly property string iconName:
            ((stream && stream.properties) || {})["application.icon_name"] || ""

        // Which bar is open is the card's decision: it owns the single open id.
        property bool open: false
        signal toggleRequested(int id)

        height: body.implicitHeight + 16
        radius: 12
        color: hover.containsMouse || open
               ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.07)
               : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.045)
        border.width: 1
        border.color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.06)

        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        Column {
            id: body
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
            spacing: 6

            Item {
                width: parent.width
                height: 34

                // Declared first so the transport buttons below sit on top and
                // keep their own clicks; this catches the rest of the row and
                // opens or closes its volume bar, when it has one.
                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: row.hasStreams ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: if (row.hasStreams) row.toggleRequested(row.source.id)
                }

                Cover {
                    id: art
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    width: 34
                    height: 34
                    radius: 8
                    placeholder: ""                      // music note
                    // Artwork when the player offers it, else the app's icon.
                    source: row.player.trackArtUrl
                            || (row.iconName !== "" ? "image://icon/" + row.iconName : "")
                }

                Column {
                    anchors {
                        left: art.right; leftMargin: 10
                        right: transport.left; rightMargin: 6
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 1

                    Text {
                        width: parent.width
                        text: row.player.trackTitle
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        visible: text !== ""
                        // The artist, or the app when the track has none (a
                        // browser tab, often).
                        text: row.player.trackArtist || row.source.name
                        color: Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                    }
                }

                Row {
                    id: transport
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 2

                    IconButton {
                        size: 26
                        glyph: ""                          // step back
                        glyphSize: 10
                        opacity: row.player.canGoPrevious ? 1 : 0.35
                        onActivated: MediaService.previousSource(row.source)
                    }

                    IconButton {
                        size: 26
                        glyph: row.player.isPlaying ? "" : ""
                        glyphSize: 10
                        active: row.player.isPlaying
                        onActivated: MediaService.toggleSource(row.source)
                    }

                    IconButton {
                        size: 26
                        glyph: ""                          // step forward
                        glyphSize: 10
                        opacity: row.player.canGoNext ? 1 : 0.35
                        onActivated: MediaService.nextSource(row.source)
                    }
                }
            }

            // Volume, revealed by clicking the row. Toggled with `visible`
            // rather than an animated height: Column drops invisible children
            // outright, so an animated collapse would still leave its spacing.
            Row {
                width: parent.width
                spacing: 8
                visible: row.open && row.hasStreams

                IconButton {
                    size: 26
                    glyph: row.muted ? "" : ""
                    glyphSize: 10
                    active: row.muted
                    onActivated: MediaService.toggleSourceMute(row.source)
                }

                Slider {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 26 - 8 - 8 - 42
                    value: row.audio ? row.audio.volume : 0
                    fillColor: row.muted ? Theme.overlay1 : Theme.accent
                    onMoved: function (v) { MediaService.setSourceVolume(row.source, v) }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 42
                    horizontalAlignment: Text.AlignRight
                    text: row.audio ? Math.round(row.audio.volume * 100) + "%" : ""
                    color: Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }
    }
}
