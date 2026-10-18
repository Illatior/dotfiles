// A filled tile with an optional icon and a label (plus an optional small
// caption under it), for the island's hover calendar: the day cells of the
// month grid and the weather detail chips.
//
// Ported from serpantinum's reusables/buttons/ClickButton.qml
// (github.com/ilyamiro/serpantinum, AGPL-3.0), trimmed to what the calendar
// uses and minus its click sound.
import QtQuick
import QtQuick.Layouts
import "../../theme"

Item {
    id: root

    property int horizontalPadding: 12
    property int cornerRadius: 10

    property string buttonText: ""
    property string subText: ""
    property string buttonIcon: ""
    property int iconFontSize: 15
    property int textFontSize: 12

    property color accentColor: Theme.surface0
    property color textColor: Theme.text

    readonly property bool isHoveredOrHighlighted: btnMa.containsMouse

    signal clicked()

    property real flashOpacity: 0.0
    property real popScale: 1.0

    // Room left for the label once the padding and the icon are taken out,
    // so a long one elides instead of spilling out of the tile.
    readonly property real availableTextWidth:
        Math.max(0, root.width - root.horizontalPadding * 2
                    - (iconLabel.visible ? iconLabel.implicitWidth + mainRow.spacing : 0))

    implicitWidth: (iconLabel.visible ? iconLabel.implicitWidth : 0)
                   + (iconLabel.visible && textCol.visible ? mainRow.spacing : 0)
                   + (textCol.visible ? textCol.implicitWidth : 0)
                   + horizontalPadding * 2
    implicitHeight: 30

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        clip: true
        color: btnMa.pressed && root.enabled ? Qt.darker(root.accentColor, 1.28)
             : root.isHoveredOrHighlighted ? Qt.darker(root.accentColor, 1.14)
             : root.accentColor

        Behavior on color { ColorAnimation { duration: 180 } }

        scale: (btnMa.pressed && root.enabled ? 0.985 : root.isHoveredOrHighlighted ? 1.015 : 1.0) * root.popScale
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

        SequentialAnimation {
            id: popAnim
            NumberAnimation { target: root; property: "popScale"; to: 1.015; duration: 100; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popScale"; to: 1.0; duration: 350; easing.type: Easing.OutQuint }
        }

        RowLayout {
            id: mainRow
            anchors.centerIn: parent
            spacing: 8

            Text {
                id: iconLabel
                visible: root.buttonIcon !== ""
                text: root.buttonIcon
                font.family: Theme.fontFamily
                font.pixelSize: root.iconFontSize
                color: root.textColor
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                id: textCol
                visible: root.buttonText !== "" || root.subText !== ""
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                Text {
                    visible: root.buttonText !== ""
                    text: root.buttonText
                    font.family: Theme.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: root.textFontSize
                    color: root.textColor
                    elide: Text.ElideRight
                    Layout.maximumWidth: Math.ceil(root.availableTextWidth) + 2
                }

                Text {
                    visible: root.subText !== ""
                    text: root.subText
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(10, root.textFontSize - 6)
                    color: root.textColor
                    opacity: 0.75
                    elide: Text.ElideRight
                    Layout.maximumWidth: Math.ceil(root.availableTextWidth) + 2
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: root.cornerRadius
            color: "#ffffff"
            opacity: root.flashOpacity
            PropertyAnimation on opacity { id: flashAnim; to: 0; duration: 350; easing.type: Easing.OutExpo }
        }
    }

    MouseArea {
        id: btnMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

        onClicked: {
            if (!root.enabled) return;
            popAnim.start();
            root.flashOpacity = 0.15;
            flashAnim.start();
            root.clicked();
        }
    }
}
