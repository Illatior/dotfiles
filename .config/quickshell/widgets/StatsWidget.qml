// Stats: CPU / RAM / GPU gauges, disk usage (internal disks, then external
// drives with mount / eject), and the local Kubernetes cluster. Data from
// StatsService, polled only while this is open. R refreshes now.
//
// The cluster comes from local.json next to shell.qml (gitignored; see
// local.example.json). Until one is found the section says how to set it.
import QtQuick
import "../theme"
import "../services"
import "../components"

Item {
    id: root

    property bool active: false

    readonly property var host: StatsService.host
    readonly property var kube: StatsService.kube
    readonly property var gpus: host && host.ok ? host.gpus : []
    readonly property var internalDisks: host && host.ok ? host.disks.filter(function (d) { return !d.external }) : []
    readonly property var externalDisks: host && host.ok ? host.disks.filter(function (d) { return d.external }) : []

    readonly property int pad: 18

    implicitWidth: 620
    implicitHeight: column.implicitHeight + pad * 2

    focus: active
    onActiveChanged: {
        StatsService.watching = active
        if (active) root.forceActiveFocus()
    }
    Component.onDestruction: StatsService.watching = false

    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_R) {
            StatsService.refresh()
            event.accepted = true
        }
    }

    // ── Formatting ──────────────────────────────────────────────────────────
    // Binary units, like df and free: "763 GiB", "1.6 GiB", "24 MiB".
    function bytes(n) {
        var units = ["B", "KiB", "MiB", "GiB", "TiB"]
        var i = 0
        while (n >= 1024 && i < units.length - 1) { n /= 1024; i++ }
        return (n >= 100 || i === 0 ? Math.round(n) : n.toFixed(1)) + " " + units[i]
    }
    // "763 / 931 GiB" — the unit once, from the total.
    function usedOf(used, total) {
        var t = bytes(total)
        var unit = t.split(" ")[1]
        var scale = Math.pow(1024, ["B", "KiB", "MiB", "GiB", "TiB"].indexOf(unit))
        var u = used / scale
        if (u > 0 && u < 0.05) return bytes(used) + " / " + t
        return (u >= 100 || unit === "B" ? Math.round(u) : u.toFixed(1)) + " / " + t
    }
    function temp(c) { return c === null || c === undefined ? "" : Math.round(c) + "°C" }
    function cores(n) { return n >= 1 ? n.toFixed(n >= 10 ? 0 : 1) : Math.round(n * 1000) + "m" }
    function loadColor(p) {
        if (p >= 90) return Theme.urgent
        if (p >= 75) return Theme.warning
        return Theme.accent
    }
    function diskColor(f) {
        if (f >= 0.95) return Theme.urgent
        if (f >= 0.85) return Theme.warning
        return Theme.accent
    }

    // ── Pieces ──────────────────────────────────────────────────────────────
    component Caps: Text {
        color: Theme.subtext0
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall - 1
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.6
    }

    component Small: Text {
        color: Theme.subtext0
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        elide: Text.ElideRight
    }

    // A ring that fills to `percent` (null: no reading), with a caption.
    component Gauge: Item {
        id: gauge

        property var    percent: null
        property string label
        property string line1
        property string line2
        readonly property color tint: root.loadColor(percent || 0)

        property real shown: 0
        Behavior on shown { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        onPercentChanged: shown = percent || 0
        Component.onCompleted: shown = percent || 0

        width: (parent.width - parent.spacing * 2) / 3
        height: 164

        Canvas {
            id: ring
            width: 104
            height: 104
            anchors.horizontalCenter: parent.horizontalCenter

            property real value: Math.min(100, gauge.shown)
            property color tint: gauge.tint
            onValueChanged: requestPaint()
            onTintChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                var c = width / 2, r = c - 6, start = Math.PI * 0.75, sweep = Math.PI * 1.5
                ctx.reset()
                ctx.lineCap = "round"
                ctx.lineWidth = 8
                ctx.strokeStyle = Theme.hover
                ctx.beginPath()
                ctx.arc(c, c, r, start, start + sweep)
                ctx.stroke()
                if (value > 0) {
                    ctx.strokeStyle = tint
                    ctx.beginPath()
                    ctx.arc(c, c, r, start, start + sweep * value / 100)
                    ctx.stroke()
                }
            }

            Text {
                anchors.centerIn: parent
                text: gauge.percent === null ? "–" : Math.round(gauge.shown) + "%"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 24
                font.bold: true
            }
        }

        Column {
            anchors { top: ring.bottom; topMargin: -6; left: parent.left; right: parent.right }
            spacing: 1

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: gauge.label
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: true
                elide: Text.ElideRight
            }
            Small {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: gauge.line1
                visible: text !== ""
            }
            Small {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: gauge.line2
                visible: text !== ""
            }
        }
    }

    // A thin labelled bar.
    component Bar: Rectangle {
        property real  fraction: 0
        property color tint: Theme.accent

        height: 5
        radius: 3
        color: Theme.hover
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, parent.fraction))
            height: parent.height
            radius: 3
            color: parent.tint
            Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        }
    }

    // Icon tile, title + subtitle, value on the right, bar underneath; an
    // optional action button at the far right.
    component DiskRow: Item {
        id: row

        property string glyph
        property string title
        property string subtitle
        property string value
        property real   fraction: 0
        property bool   showBar: true
        property string actionGlyph
        property string actionTip
        property bool   actionBusy: false
        signal act()

        width: parent.width
        height: 46

        Rectangle {
            id: tile
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            height: 34
            radius: 10
            color: Theme.surface
            Icon {
                anchors.centerIn: parent
                text: row.glyph
                color_: Theme.subtext1
                font.pixelSize: 17
            }
        }

        Item {
            anchors { left: tile.right; leftMargin: 12; right: actionButton.visible ? actionButton.left : parent.right
                      rightMargin: actionButton.visible ? 10 : 0; verticalCenter: parent.verticalCenter }
            height: 38

            Text {
                id: titleText
                anchors { left: parent.left; top: parent.top }
                width: Math.min(implicitWidth, parent.width - valueText.implicitWidth - 12)
                text: row.title
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall + 1
                font.bold: true
                elide: Text.ElideRight
            }
            Small {
                anchors { left: titleText.right; leftMargin: 8; baseline: titleText.baseline
                          right: valueText.left; rightMargin: 12 }
                text: row.subtitle
                font.pixelSize: Theme.fontSizeSmall - 1
            }
            Small {
                id: valueText
                anchors { right: parent.right; baseline: titleText.baseline }
                text: row.value
                color: row.showBar ? Theme.subtext1 : Theme.subtext0
            }
            Bar {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 3 }
                visible: row.showBar
                fraction: row.fraction
                tint: root.diskColor(row.fraction)
            }
        }

        Rectangle {
            id: actionButton
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            visible: row.actionGlyph !== ""
            width: 30
            height: 30
            radius: 15
            color: actionArea.containsMouse ? Theme.hover : "transparent"
            opacity: row.actionBusy ? 0.4 : 1

            Icon {
                anchors.centerIn: parent
                text: row.actionGlyph
                color_: actionArea.containsMouse ? Theme.text : Theme.subtext0
                font.pixelSize: 15
            }
            MouseArea {
                id: actionArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: !row.actionBusy
                cursorShape: Qt.PointingHandCursor
                onClicked: row.act()
            }
        }
    }

    component Stat: Column {
        property string label
        property string value
        property color  tint: Theme.text

        width: (parent.width - parent.spacing * 3) / 4
        spacing: 2

        Caps { text: parent.label }
        Text {
            text: parent.value
            color: parent.tint
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLarge + 2
            font.bold: true
        }
    }

    component SectionHeader: Item {
        property string title
        property string note

        width: parent.width
        height: 18

        Caps {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: parent.title
        }
        Small {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: Math.min(implicitWidth, parent.width * 0.7)
            text: parent.note
            font.pixelSize: Theme.fontSizeSmall - 1
        }
    }

    // ── Layout ──────────────────────────────────────────────────────────────
    Column {
        id: column
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: root.pad }
        spacing: 14

        // Header
        Item {
            width: parent.width
            height: 36

            Text {
                id: heading
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: "Stats"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge + 2
                font.bold: true
            }
            Small {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: Math.min(implicitWidth, parent.width - heading.width - 20)
                text: SystemService.host !== "" ? SystemService.host + " · up " + SystemService.uptime : ""
            }
        }

        // ── CPU / RAM / GPU ─────────────────────────────────────────────────
        Row {
            width: parent.width
            spacing: 12

            Gauge {
                label: "CPU"
                percent: StatsService.cpuPercent
                line1: root.host && root.host.ok ? root.host.cpu.model : ""
                line2: root.host && root.host.ok
                       ? [root.host.cpu.threads + " threads", root.temp(root.host.cpu.temp)]
                             .filter(function (s) { return s !== "" }).join(" · ")
                       : ""
            }
            Gauge {
                label: "RAM"
                percent: MemoryService.totalKb > 0 ? MemoryService.percent : null
                line1: MemoryService.label
                line2: "used"
            }
            Gauge {
                readonly property var gpu: root.gpus.length > 0 ? root.gpus[0] : null
                label: "GPU"
                percent: gpu ? gpu.percent : null
                line1: gpu ? [gpu.name, root.temp(gpu.temp)].filter(function (s) { return s !== "" }).join(" · ")
                           : root.host ? "No GPU found" : ""
                line2: gpu && gpu.vram_total > 0 ? root.usedOf(gpu.vram_used, gpu.vram_total) + " VRAM" : ""
            }
        }

        Divider { width: parent.width }

        // ── Disks ───────────────────────────────────────────────────────────
        Column {
            width: parent.width
            spacing: 4

            SectionHeader { title: "Disks" }

            Small {
                visible: !!root.host && !root.host.ok
                text: root.host ? root.host.error || "" : ""
                color: Theme.urgent
            }
            Small { visible: !root.host; text: "Loading…" }

            Repeater {
                model: root.internalDisks
                DiskRow {
                    required property var modelData
                    glyph: modelData.tran === "nvme" ? "\u{f0a0}" : "\u{f02ca}"
                    title: modelData.model
                    subtitle: modelData.mounts.length ? modelData.mounts.join("  ·  ") : "not mounted"
                    value: modelData.total > 0 ? root.usedOf(modelData.used, modelData.total) : root.bytes(modelData.size)
                    fraction: modelData.total > 0 ? modelData.used / modelData.total : 0
                    showBar: modelData.total > 0
                }
            }
        }

        Column {
            width: parent.width
            spacing: 4

            SectionHeader {
                title: "External"
                note: StatsService.action && !StatsService.action.ok ? StatsService.action.error : ""
            }

            Small {
                visible: !!root.host && root.host.ok && root.externalDisks.length === 0
                text: "No external drives connected"
            }

            // Mount the first unmounted partition, or unmount + power off.
            Repeater {
                model: root.externalDisks
                DiskRow {
                    required property var modelData
                    readonly property bool mounted: modelData.mounts.length > 0
                    readonly property var unmountedPart: modelData.parts.filter(function (p) { return !p.mount })[0]

                    glyph: modelData.tran === "usb" ? "\u{f129e}" : "\u{f02ca}"
                    title: modelData.label || modelData.model
                    subtitle: (modelData.label ? modelData.model + "  ·  " : "")
                              + (mounted ? modelData.mounts.join("  ·  ") : root.bytes(modelData.size))
                    value: mounted ? root.usedOf(modelData.used, modelData.total) : "not mounted"
                    fraction: modelData.total > 0 ? modelData.used / modelData.total : 0
                    showBar: mounted
                    actionGlyph: mounted ? "\u{f01ea}" : unmountedPart ? "" : ""
                    actionBusy: StatsService.actionBusy
                    onAct: mounted ? StatsService.eject(modelData.path) : StatsService.mount(unmountedPart.path)
                }
            }
        }

        Divider { width: parent.width }

        // ── Kubernetes ──────────────────────────────────────────────────────
        Column {
            width: parent.width
            spacing: 10

            readonly property bool ready: !!root.kube && root.kube.ok

            SectionHeader {
                title: "Kubernetes"
                note: root.kube && root.kube.context
                      ? root.kube.context + "  ·  " + root.kube.server.replace(/^https?:\/\//, "") : ""
            }

            Small { visible: !root.kube; text: "Loading…" }

            // Not configured (or misconfigured): say what's wrong and where
            // to set it.
            Rectangle {
                visible: !!root.kube && !!root.kube.setup
                width: parent.width
                height: setupText.implicitHeight + 28
                radius: 14
                color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12)
                border.width: 1
                border.color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.35)

                Icon {
                    id: warnIcon
                    anchors { left: parent.left; top: parent.top; margins: 14; topMargin: 15 }
                    text: ""
                    color_: Theme.warning
                    font.pixelSize: 16
                }
                Text {
                    id: setupText
                    anchors { left: warnIcon.right; leftMargin: 12; right: parent.right; rightMargin: 14
                              verticalCenter: parent.verticalCenter }
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    lineHeight: 1.15
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    text: root.kube && root.kube.setup
                          ? "<b><font color='" + Theme.text + "'>Configure a local cluster</font></b><br>"
                            + root.kube.error + ".<br><br>"
                            + "Set <font color='" + Theme.text + "'>stats.kubeconfig</font> (and optionally "
                            + "<font color='" + Theme.text + "'>stats.context</font>) in "
                            + "<font color='" + Theme.text + "'>~/.config/quickshell/local.json</font>"
                            + " — copy <font color='" + Theme.text + "'>local.example.json</font> to start."
                          : ""
                }
            }

            // Configured, but the cluster didn't answer.
            Small {
                visible: !!root.kube && !root.kube.ok && !root.kube.setup
                width: parent.width
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                text: root.kube ? root.kube.error || "" : ""
                color: Theme.urgent
            }

            Row {
                visible: parent.ready
                width: parent.width
                spacing: 12

                readonly property var nodes: parent.ready ? root.kube.nodes : []
                readonly property int readyNodes: nodes.filter(function (n) { return n.ready }).length

                Stat {
                    label: "Nodes"
                    value: parent.readyNodes + " / " + parent.nodes.length
                    tint: parent.readyNodes < parent.nodes.length ? Theme.urgent : Theme.text
                }
                Stat { label: "Running";   value: parent.parent.ready ? String(root.kube.pods.running) : "" }
                Stat { label: "Completed"; value: parent.parent.ready ? String(root.kube.pods.succeeded) : "" }
                Stat {
                    label: "Problems"
                    value: parent.parent.ready ? String(root.kube.problem_count) : ""
                    tint: parent.parent.ready && root.kube.problem_count > 0 ? Theme.warning : Theme.success
                }
            }

            // Per-node CPU and memory, from metrics-server.
            Repeater {
                model: parent.ready && root.kube.metrics ? root.kube.nodes : []
                Row {
                    required property var modelData
                    width: parent.width
                    spacing: 12

                    Text {
                        width: 90
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name
                        color: modelData.ready ? Theme.text : Theme.urgent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Repeater {
                        model: [
                            { label: "CPU", pct: modelData.cpu, of: root.cores(modelData.cores) + " cores" },
                            { label: "Mem", pct: modelData.mem, of: root.bytes(modelData.memory) }
                        ]
                        Column {
                            required property var modelData
                            width: (parent.width - 90 - 24) / 2
                            spacing: 5
                            Item {
                                width: parent.width
                                height: cpuLabel.implicitHeight
                                Small {
                                    id: cpuLabel
                                    text: modelData.label + "  " + (modelData.pct === null ? "–" : modelData.pct + "%")
                                    color: Theme.subtext1
                                }
                                Small { anchors.right: parent.right; text: "of " + modelData.of }
                            }
                            Bar {
                                width: parent.width
                                fraction: (modelData.pct || 0) / 100
                                tint: root.loadColor(modelData.pct || 0)
                            }
                        }
                    }
                }
            }

            Small {
                visible: parent.ready && !root.kube.metrics
                text: "No metrics — kubectl top needs metrics-server"
            }
        }
    }
}
