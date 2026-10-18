// VPN page: the saved NetworkManager VPN / WireGuard profiles; clicking one
// connects or disconnects it.
import QtQuick
import "../theme"
import "../services"
import "../components"

Item {
    id: root

    // Shown as a control-center page rather than a standalone popup.
    property bool embedded: false

    implicitWidth: Theme.popupWidth
    implicitHeight: panel.implicitHeight

    PopupPanel {
        id: panel
        embedded: root.embedded
        title: "VPN"
        width: parent.width

        Column {
            width: parent.width
            spacing: 6
            topPadding: 12

            Repeater {
                model: NetworkService.vpns
                delegate: VpnRow {}
            }

            Text {
                visible: NetworkService.vpns.length === 0
                width: parent.width
                height: 80
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: "No saved VPNs"
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }
        }
    }

    // One saved VPN profile; clicking toggles it.
    component VpnRow: Rectangle {
        id: vrow

        required property var modelData
        readonly property bool current: modelData.active
        readonly property bool busy: NetworkService.vpnPending === modelData.uuid

        width: parent ? parent.width : 0
        height: 48
        radius: Theme.cornerRadiusSmall + 2
        color: vrow.current ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
             : vHover.hovered ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)
             : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.045)
        border.width: 1
        border.color: vrow.current ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)
                                   : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.06)

        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        CenteredIcon {
            id: vIcon
            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
            text: vrow.busy ? "\uf110" : "\uf023"              // spinner : lock
            size: 16
            color: vrow.current || vrow.busy ? Theme.accent : Theme.subtext0

            RotationAnimation on rotation {
                running: vrow.busy
                from: 0; to: 360
                duration: 900
                loops: Animation.Infinite
                onRunningChanged: if (!running) vIcon.rotation = 0
            }
        }

        Column {
            anchors {
                left: vIcon.right; leftMargin: 12
                right: parent.right; rightMargin: 14
                verticalCenter: parent.verticalCenter
            }
            spacing: 1

            Text {
                width: parent.width
                text: vrow.modelData.name
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: vrow.current
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: vrow.busy ? (NetworkService.vpnPendingUp ? "Connecting…" : "Disconnecting…")
                    : vrow.current ? "Connected — click to disconnect" : "Disconnected"
                color: vrow.current || vrow.busy ? Theme.accent : Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }
        }

        HoverHandler { id: vHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: if (!vrow.busy) NetworkService.toggleVpn(vrow.modelData.uuid, vrow.current) }
    }
}
