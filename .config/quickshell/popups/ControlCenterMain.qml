// Control center main page: header, quick tiles, volume, and the
// notifications list.
//
// Tiles either toggle their thing (the round glyph) or open the matching page
// (the rest of the tile); tiles with no page (Peace, Night Light) toggle from
// anywhere. Pages are opened through ShellState, so the morph to the new page
// size is driven by the same state the IPC/keybinds use.
import QtQuick
import QtQuick.Effects
import "../theme"
import "../state"
import "../services"
import "../components"

Item {
    id: root

    // The control center gives this page a fixed height; the notifications
    // list takes whatever the rows above leave, and scrolls.
    implicitWidth: Theme.ccWidth
    implicitHeight: Theme.ccHeight

    // ── Power menu ──────────────────────────────────────────────────────────
    // The header's power button opens the session actions in place. Reboot
    // and power off take two clicks, like the island's Power widget: the
    // first arms the button, any other action (or closing the menu) disarms.
    property bool   powerOpen: false
    property string armed: ""
    property string hoveredAction: ""

    readonly property var powerActions: [
        { id: "lock",      label: "Lock",      glyph: "" },
        { id: "logout",    label: "Log Out",   glyph: "" },
        { id: "reboot",    label: "Reboot",    glyph: "", confirm: "reboot" },
        { id: "power-off", label: "Power Off", glyph: "", confirm: "power off" }
    ]

    readonly property int  powerGap: 8
    readonly property int  powerSpan: powerActions.length * (power.size + powerGap)

    property real powerProgress: powerOpen ? 1 : 0
    Behavior on powerProgress { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }

    // The header title: the hovered action's name, else the armed action's
    // prompt, else the panel's own title.
    readonly property var  hoveredInfo: powerOpen && hoveredAction !== "" && hoveredAction !== armed
                                        ? actionById(hoveredAction) : null
    readonly property bool prompting: armed !== "" && hoveredInfo === null

    onPowerOpenChanged: { armed = ""; hoveredAction = "" }

    // Starts closed every time the panel opens, and on every page switch.
    Connections {
        target: ShellState
        function onControlCenterOpenChanged() { root.powerOpen = false }
        function onCcPageChanged() { root.powerOpen = false }
    }

    function actionById(id) {
        for (var i = 0; i < powerActions.length; i++)
            if (powerActions[i].id === id) return powerActions[i]
        return null
    }

    function invokePower(id) {
        if (actionById(id).confirm && armed !== id) {
            armed = id
            return
        }
        ShellState.closeAll()
        if (id === "lock")        PowerService.lock()
        else if (id === "logout") PowerService.logout()
        else if (id === "reboot") PowerService.reboot()
        else                      PowerService.powerOff()
    }

    Column {
        id: column
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: Theme.ccPadding
        }
        spacing: 10

        // Tile grid: Wi-Fi and Bluetooth share the wider left column; to their
        // right, Audio spans both cells, then Peace + Night Light.
        readonly property real sideWidth: Math.round((width - spacing) * 0.38)
        readonly property real cellWidth: (width - sideWidth - spacing * 2) / 2

        // ── Header ──────────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 36

            IconButton {
                id: close
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                size: 34
                glyph: ""
                glyphSize: 11
                color: hovered ? Theme.hover : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.06)
                onActivated: ShellState.closeAll()
            }

            // The power menu's buttons are glyphs only, so while it is open
            // the title names the one under the pointer, or asks to confirm.
            Text {
                anchors { left: close.right; leftMargin: 12; right: power.left
                          rightMargin: 12 + root.powerSpan * root.powerProgress
                          verticalCenter: parent.verticalCenter }
                text: root.hoveredInfo ? root.hoveredInfo.label
                    : root.prompting ? "Click again to " + root.actionById(root.armed).confirm
                    : "Control Center"
                color: root.prompting ? Theme.success : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 17
                elide: Text.ElideRight
            }

            // Session power menu, in the header's right corner. The actions
            // slide out leftwards from behind the power button; clipped at
            // its left edge so they appear from under it, and opaque so the
            // fanned-out stack reads as cards rather than overlapping tints.
            Item {
                id: powerMenu
                anchors { right: power.left; top: parent.top; bottom: parent.bottom }
                width: root.powerSpan
                clip: true

                Repeater {
                    model: root.powerActions

                    delegate: IconButton {
                        required property var modelData
                        required property int index
                        readonly property bool armed: root.armed === modelData.id
                        // Slot 1 sits next to the power button.
                        readonly property int slot: root.powerActions.length - index

                        x: powerMenu.width - slot * (size + root.powerGap) * root.powerProgress
                        anchors.verticalCenter: parent.verticalCenter
                        size: power.size
                        glyph: armed ? "\uf00c" : modelData.glyph
                        glyphSize: 11
                        glyphColor: armed ? Theme.crust : Theme.text
                        color: armed ? Theme.success
                             : Qt.tint(Theme.barBg, hovered ? Theme.hover : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.06))
                        opacity: Math.min(1, root.powerProgress * 1.5)
                        visible: opacity > 0
                        enabled: root.powerOpen

                        onHoveredChanged: {
                            if (hovered) root.hoveredAction = modelData.id
                            else if (root.hoveredAction === modelData.id) root.hoveredAction = ""
                        }
                        onActivated: root.invokePower(modelData.id)
                    }
                }
            }

            IconButton {
                id: power
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                size: 34
                // Open, it points right: the way the actions fold back in.
                glyph: root.powerOpen ? "\uf054" : "\uf011"
                glyphSize: 11
                glyphColor: root.powerOpen ? Theme.accent : Theme.text
                color: root.powerOpen ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                     : hovered ? Theme.hover : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.06)
                onActivated: root.powerOpen = !root.powerOpen
            }
        }

        // ── Quick tiles ─────────────────────────────────────────────────────
        Row {
            width: parent.width
            spacing: 10

            QuickTile {
                id: wifi
                width: column.sideWidth
                glyph: NetworkService.glyph
                title: NetworkService.kind === "ethernet" ? "Ethernet" : "Wi-Fi"
                subtitle: {
                    if (NetworkService.kind === "ethernet")
                        return NetworkService.ip !== "" ? NetworkService.ip : "Connected"
                    if (!NetworkService.wifiEnabled) return "Off"
                    return NetworkService.connected ? NetworkService.ssid : "Not connected"
                }
                active: NetworkService.connected
                onToggled: NetworkService.toggleWifi()
                onOpened: ShellState.showPage("network")
            }

            QuickTile {
                width: parent.width - column.sideWidth - parent.spacing
                glyph: AudioService.glyph
                title: "Audio"
                subtitle: AudioService.muted ? "Muted" : (AudioService.sinkName || "No output")
                active: !AudioService.muted
                onToggled: AudioService.toggleMute()
                onOpened: ShellState.showPage("audio")
            }
        }

        Row {
            id: row2
            width: parent.width
            spacing: 10

            QuickTile {
                width: column.sideWidth
                glyph: BluetoothService.glyph
                title: "Bluetooth"
                subtitle: {
                    if (!BluetoothService.powered) return "Off"
                    var c = BluetoothService.connected
                    if (c.length === 0) return "On"
                    return c[0].name + (c.length > 1 ? " +" + (c.length - 1) : "")
                }
                active: BluetoothService.powered
                onToggled: BluetoothService.togglePower()
                onOpened: ShellState.showPage("bluetooth")
            }

            // Notifications still show, without their sound.
            QuickTile {
                width: column.cellWidth
                glyph: ""
                title: "Peace"
                subtitle: NotificationService.peace ? "On" : "Off"
                active: NotificationService.peace
                onToggled: root.togglePeace()
                onOpened: root.togglePeace()
            }

            QuickTile {
                width: column.cellWidth
                glyph: ""
                title: "Night Light"
                subtitle: !NightLightService.available ? "Unavailable"
                        : NightLightService.on ? "On" : "Off"
                active: NightLightService.on
                onToggled: NightLightService.toggle()
                onOpened: NightLightService.toggle()
            }
        }

        QuickTile {
            width: parent.width
            glyph: NetworkService.vpnPending !== "" ? "\uf110" : "\uf023"   // spinner : lock
            title: "VPN"
            spinning: NetworkService.vpnPending !== ""
            subtitle: {
                if (NetworkService.vpnPending !== "")
                    return NetworkService.vpnPendingUp ? "Connecting…" : "Disconnecting…"
                if (NetworkService.vpns.length === 0) return "No saved VPNs"
                var a = NetworkService.vpns.filter(function (v) { return v.active })
                if (a.length === 0) return "Off"
                return a[0].name + (a.length > 1 ? " +" + (a.length - 1) : "")
            }
            active: NetworkService.vpnActive
            onToggled: NetworkService.toggleAnyVpn()
            onOpened: ShellState.showPage("vpn")
        }

        // ── Media ───────────────────────────────────────────────────────────
        // Every app sending audio, with its own volume. Collapses to nothing
        // when the system is silent.
        MediaCard { width: parent.width }

        // ── Volume ──────────────────────────────────────────────────────────
        PillSlider {
            width: parent.width
            height: 40
            glyph: AudioService.glyph
            value: AudioService.volume
            fillColor: AudioService.muted ? Theme.overlay1 : Theme.accent
            onMoved: function (v) { AudioService.setVolume(v) }
            onGlyphClicked: AudioService.toggleMute()
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)
        }
    }

    // ── Notifications ───────────────────────────────────────────────────────
    Item {
        id: notifHeader
        anchors { top: column.bottom; topMargin: 6; left: column.left; right: column.right }
        height: 26

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                text: "Notifications"
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }

            Text {
                visible: NotificationService.unreadCount > 0
                text: NotificationService.unreadCount + " new"
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 2

            TextAction {
                visible: NotificationService.active.length > 0
                label: "Clear all"
                accent: true
                onActivated: NotificationService.clearAll()
            }
        }
    }

    // Empty state, centred in the space the list would take.
    Column {
        anchors.centerIn: list
        visible: NotificationService.active.length === 0
        spacing: 10

        CenteredIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "\uf1f6"
            size: 32
            color: Theme.overlay1
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Notifications Empty"
            color: Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLarge
        }
    }

    ListView {
        id: list
        anchors {
            top: notifHeader.bottom
            topMargin: 6
            left: column.left
            right: column.right
            bottom: parent.bottom
            bottomMargin: Theme.ccPadding
        }
        clip: true
        spacing: 8
        boundsBehavior: Flickable.StopAtBounds
        model: NotificationService.active

        delegate: NotificationCard {
            required property var modelData

            width: list.width
            entry: modelData
            isLive: NotificationService.isLive(modelData.id)

            onRemove:   NotificationService.dismiss(modelData.id)
            onAction: function (actionId) {
                NotificationService.invoke(modelData.id, actionId)
            }
        }
    }

    function togglePeace() {
        NotificationService.peace = !NotificationService.peace
        NotificationService.save()
    }

    // ── Pieces ──────────────────────────────────────────────────────────────

    component TextAction: Rectangle {
        id: act

        property string label
        property bool   accent: false
        signal activated()

        width: actText.width + 16
        height: 22
        radius: height / 2
        color: actHover.hovered ? Theme.hover : "transparent"

        Text {
            id: actText
            anchors.centerIn: parent
            text: act.label
            color: act.accent ? Theme.accent : Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        HoverHandler { id: actHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: act.activated() }
    }
}
