import Quickshell
import Quickshell.Services.UPower
import Quickshell.Hyprland
import QtQuick

Item {
    id: bat

    readonly property var dev: UPower.displayDevice
    readonly property real pct: dev ? (dev.percentage <= 1 ? dev.percentage * 100 : dev.percentage) : 0
    readonly property bool charging: !UPower.onBattery
    readonly property bool saver: PowerProfiles.profile === PowerProfile.PowerSaver
    readonly property bool low: !charging && pct < 15
    readonly property color tint: charging ? "#4ade80" : low ? "#ef4444" : saver ? "#facc15" : "#ececec"

    implicitWidth: row.implicitWidth
    implicitHeight: 22

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        Canvas {
            id: icon
            width: 22
            height: 12
            anchors.verticalCenter: parent.verticalCenter
            property real level: bat.pct
            property color c: bat.tint
            property bool bolt: bat.charging
            onLevelChanged: requestPaint()
            onCChanged: requestPaint()
            onBoltChanged: requestPaint()

            onPaint: {
                const g = getContext("2d")
                g.reset()
                g.strokeStyle = c
                g.fillStyle = c
                g.lineWidth = 1.2

                g.beginPath()
                g.roundedRect(0.6, 0.6, 18, 10.8, 2.5, 2.5)
                g.stroke()
                g.fillRect(19.4, 3.8, 2, 4.4)

                const w = Math.max(1.5, 15 * Math.min(level, 100) / 100)
                g.globalAlpha = bolt ? 0.35 : 1
                g.beginPath()
                g.roundedRect(2, 2, w, 8, 1.5, 1.5)
                g.fill()
                g.globalAlpha = 1

                if (bolt) {
                    g.beginPath()
                    g.moveTo(11, 1.2)
                    g.lineTo(6.2, 6.8)
                    g.lineTo(9.2, 6.8)
                    g.lineTo(8.2, 10.8)
                    g.lineTo(13, 5.2)
                    g.lineTo(10, 5.2)
                    g.closePath()
                    g.fill()
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(bat.pct) + "%"
            font.family: "Inter"
            font.pixelSize: 11
            font.weight: Font.Medium
            color: bat.tint
            Behavior on color { ColorAnimation { duration: 250 } }
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        onClicked: Hyprland.dispatch("exec qs ipc call battery toggle " + Math.round(bat.mapToItem(null, 0, 0).x))
    }
}
