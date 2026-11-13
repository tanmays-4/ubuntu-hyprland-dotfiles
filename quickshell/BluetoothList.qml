import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Column {
    id: bt
    property bool active: false
    property var devices: []
    property bool scanning: false
    property string busyMac: ""
    spacing: 4

    onActiveChanged: if (active) refresh()

    function refresh() {
        lister.running = true
    }

    Process {
        id: lister
        command: ["sh", Quickshell.env("HOME") + "/.config/quickshell/scripts/bt.sh"]
        stdout: StdioCollector {
            id: lout
            onStreamFinished: {
                const list = []
                for (const line of lout.text.trim().split("\n")) {
                    const p = line.split("|")
                    if (p.length < 4) continue
                    const name = p.slice(3).join("|")
                    if (/^([0-9A-F]{2}-){5}[0-9A-F]{2}$/i.test(name)) continue
                    list.push({ kind: p[0], mac: p[1], connected: p[2] === "1", name: name })
                }
                list.sort((a, b) => (b.connected - a.connected) || ((a.kind === "P" ? 0 : 1) - (b.kind === "P" ? 0 : 1)))
                bt.devices = list
            }
        }
    }

    Timer {
        interval: 3000
        running: bt.active
        repeat: true
        onTriggered: lister.running = true
    }

    Process {
        id: scanner
        command: ["bluetoothctl", "--timeout", "10", "scan", "on"]
        onExited: {
            bt.scanning = false
            bt.refresh()
        }
    }

    Process {
        id: action
        onExited: {
            bt.busyMac = ""
            bt.refresh()
        }
    }

    function toggle(d) {
        if (action.running) return
        busyMac = d.mac
        if (d.connected) action.command = ["bluetoothctl", "disconnect", d.mac]
        else if (d.kind === "P") action.command = ["bluetoothctl", "connect", d.mac]
        else action.command = ["sh", "-c", "bluetoothctl pair \"$1\" && bluetoothctl trust \"$1\" && bluetoothctl connect \"$1\"", "sh", d.mac]
        action.running = true
    }

    Row {
        width: parent.width
        height: 28

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - scanBtn.width - moreBtn.width - 8
            text: "DEVICES"
            font.family: "JetBrains Mono"
            font.pixelSize: 9
            font.letterSpacing: 1.6
            color: "#8a8a8a"
        }

        Rectangle {
            id: scanBtn
            anchors.verticalCenter: parent.verticalCenter
            width: scanText.implicitWidth + 18
            height: 24
            radius: 7
            color: scanArea.containsMouse ? "#24ffffff" : "#14ffffff"

            Text {
                id: scanText
                anchors.centerIn: parent
                text: bt.scanning ? "Scanning…" : "Scan"
                font.family: "Inter"
                font.pixelSize: 11
                color: "#dcdcdc"
            }

            MouseArea {
                id: scanArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    if (bt.scanning) return
                    bt.scanning = true
                    scanner.running = true
                }
            }
        }

        Item { width: 8; height: 1 }

        Rectangle {
            id: moreBtn
            anchors.verticalCenter: parent.verticalCenter
            width: moreText.implicitWidth + 18
            height: 24
            radius: 7
            color: moreArea.containsMouse ? "#24ffffff" : "transparent"

            Text {
                id: moreText
                anchors.centerIn: parent
                text: "More…"
                font.family: "Inter"
                font.pixelSize: 11
                color: "#8a8a8a"
            }

            MouseArea {
                id: moreArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: Hyprland.dispatch("exec blueman-manager")
            }
        }
    }

    Text {
        visible: bt.devices.length === 0
        text: bt.scanning ? "Looking for devices…" : "No devices yet. Press Scan."
        font.family: "Inter"
        font.pixelSize: 12
        color: "#8a8a8a"
    }

    Repeater {
        model: bt.devices

        Rectangle {
            id: devRow
            required property var modelData
            property bool busy: bt.busyMac === modelData.mac
            width: bt.width
            height: 36
            radius: 9
            color: devArea.containsMouse ? "#14ffffff" : (modelData.connected ? "#0dffffff" : "transparent")

            Rectangle {
                id: dot
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 6
                height: 6
                radius: 3
                color: devRow.modelData.connected ? "#ececec" : "#33ffffff"
            }

            Text {
                anchors.left: dot.right
                anchors.leftMargin: 12
                anchors.right: status.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: devRow.modelData.name
                font.family: "Inter"
                font.pixelSize: 12
                font.weight: devRow.modelData.connected ? Font.DemiBold : Font.Normal
                color: devRow.modelData.connected ? "#ffffff" : "#b4b4b4"
            }

            Text {
                id: status
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: devRow.busy ? "…" : (devRow.modelData.connected ? "CONNECTED" : (devRow.modelData.kind === "P" ? "PAIRED" : "NEW"))
                font.family: "JetBrains Mono"
                font.pixelSize: 9
                color: devRow.modelData.connected ? "#dcdcdc" : "#7c7c7c"
            }

            MouseArea {
                id: devArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: bt.toggle(devRow.modelData)
            }
        }
    }
}
