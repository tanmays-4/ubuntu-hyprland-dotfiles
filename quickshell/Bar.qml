import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import QtQuick

PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    WlrLayershell.namespace: "bar"

    anchors {
        top: true
        left: true
        right: true
    }
    exclusiveZone: busy ? 0 : 42
    implicitHeight: 48
    color: "transparent"

    property bool busy: false
    property bool hoverHold: false
    property bool peek: false
    property bool shown: !busy || hoverHold || peek

    mask: Region {
        item: bar.shown ? pillZone : trigger
    }

    property string wifiName: ""
    property int wifiSignal: 0
    property bool wifiOn: true
    property bool btOn: false
    property int minCount: 0

    property var sink: Pipewire.defaultAudioSink
    property bool muted: sink && sink.audio ? sink.audio.muted : false
    property real volume: sink && sink.audio ? sink.audio.volume : 0

    property var dev: UPower.displayDevice
    property real batRaw: dev ? dev.percentage : 0
    property real batLevel: batRaw <= 1 ? batRaw : batRaw / 100
    property bool charging: dev && dev.state === UPowerDeviceState.Charging

    property var activeWin: ToplevelManager.activeToplevel
    property string appName: {
        if (!activeWin) return ""
        try {
            const entry = DesktopEntries.heuristicLookup(activeWin.appId)
            if (entry && entry.name) return entry.name
        } catch (e) {}
        return activeWin.title
    }

    Process {
        id: busyCheck
        command: ["hyprctl", "activeworkspace", "-j"]
        stdout: StdioCollector {
            id: busyOut
            onStreamFinished: {
                try { bar.busy = JSON.parse(busyOut.text).windows > 0 } catch (e) {}
            }
        }
    }

    Component.onCompleted: busyCheck.running = true

    Timer {
        id: holdTimer
        interval: 500
        onTriggered: bar.hoverHold = false
    }

    Timer {
        id: peekTimer
        interval: 1200
        onTriggered: bar.peek = false
    }

    Process {
        id: status
        command: ["sh", Quickshell.env("HOME") + "/.config/quickshell/scripts/status.sh"]
        stdout: StdioCollector {
            id: statusOut
            onStreamFinished: {
                let mins = 0
                for (const line of statusOut.text.trim().split("\n")) {
                    const sp = line.indexOf(" ")
                    const key = sp === -1 ? line : line.slice(0, sp)
                    const val = sp === -1 ? "" : line.slice(sp + 1).trim()
                    if (key === "WIFI") {
                        const c = val.lastIndexOf(":")
                        bar.wifiName = c === -1 ? "" : val.slice(0, c)
                        bar.wifiSignal = c === -1 ? 0 : Number(val.slice(c + 1))
                    } else if (key === "RADIO") {
                        bar.wifiOn = val === "enabled"
                    } else if (key === "BT") {
                        bar.btOn = Number(val) > 0
                    } else if (key === "MIN") {
                        mins = Number(val) || 0
                    }
                }
                bar.minCount = mins
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: status.running = true
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event.name
            if (["openwindow", "closewindow", "movewindow", "movewindowv2"].includes(n)) status.running = true
            if (["openwindow", "closewindow", "movewindow", "movewindowv2", "workspace", "workspacev2", "activespecial"].includes(n)) busyCheck.running = true
            if (n === "workspacev2") {
                bar.peek = true
                peekTimer.restart()
            }
        }
    }

    PwObjectTracker {
        objects: [ Pipewire.defaultAudioSink ]
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    component Sep: Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 1
        height: 14
        color: "#1fffffff"
    }

    component WinButton: Rectangle {
        id: btn
        property string action: ""
        property bool danger: false
        width: 26
        height: 22
        radius: 11
        color: hover.containsMouse ? (danger ? "#59ffffff" : "#1fffffff") : "transparent"
        anchors.verticalCenter: parent.verticalCenter

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            onClicked: Hyprland.dispatch(btn.action)
        }
    }

    component Glyph: Canvas {
        property string kind: "wifi"
        property real level: 1
        property bool on: true
        property bool flag: false
        width: 14
        height: 14
        anchors.verticalCenter: parent.verticalCenter
        onKindChanged: requestPaint()
        onLevelChanged: requestPaint()
        onOnChanged: requestPaint()
        onFlagChanged: requestPaint()
        onPaint: {
            const c = getContext("2d")
            c.reset()
            c.scale(width / 24, height / 24)
            const bright = "#dcdcdc"
            const dim = "#4dffffff"
            c.lineWidth = 2.2
            c.lineCap = "round"
            c.lineJoin = "round"

            if (kind === "wifi") {
                const bars = on ? (level > 0.66 ? 3 : (level > 0.33 ? 2 : (level > 0 ? 1 : 0))) : 0
                const radii = [5, 9.5, 14]
                for (let i = 0; i < 3; i++) {
                    c.strokeStyle = i < bars ? bright : dim
                    c.beginPath()
                    c.arc(12, 20, radii[i], -Math.PI * 0.75, -Math.PI * 0.25)
                    c.stroke()
                }
                c.fillStyle = on ? bright : dim
                c.beginPath()
                c.arc(12, 20, 1.6, 0, 2 * Math.PI)
                c.fill()
            } else if (kind === "bt") {
                c.strokeStyle = on ? bright : dim
                c.beginPath()
                c.moveTo(7, 7); c.lineTo(17, 16); c.lineTo(12, 20.5); c.lineTo(12, 3.5)
                c.lineTo(17, 8); c.lineTo(7, 17)
                c.stroke()
            } else if (kind === "vol") {
                c.fillStyle = bright
                c.beginPath()
                c.moveTo(3, 9.5); c.lineTo(7, 9.5); c.lineTo(12, 5); c.lineTo(12, 19)
                c.lineTo(7, 14.5); c.lineTo(3, 14.5); c.closePath()
                c.fill()
                c.strokeStyle = bright
                if (flag) {
                    c.beginPath()
                    c.moveTo(16, 9); c.lineTo(21, 15)
                    c.moveTo(21, 9); c.lineTo(16, 15)
                    c.stroke()
                } else {
                    c.beginPath()
                    c.arc(13, 12, 4, -Math.PI / 3, Math.PI / 3)
                    c.stroke()
                    if (level > 0.5) {
                        c.beginPath()
                        c.arc(13, 12, 8, -Math.PI / 3, Math.PI / 3)
                        c.stroke()
                    }
                }
            } else if (kind === "bat") {
                c.strokeStyle = bright
                c.lineWidth = 1.6
                c.beginPath()
                c.roundedRect(2, 7, 18, 10, 2.5, 2.5)
                c.stroke()
                c.fillStyle = bright
                c.fillRect(21, 10, 1.8, 4)
                c.fillRect(4, 9, Math.max(1, 14 * Math.min(1, level)), 6)
                if (flag) {
                    c.fillStyle = "#0a0a0b"
                    c.beginPath()
                    c.moveTo(12, 8); c.lineTo(8.5, 12.5); c.lineTo(11, 12.5)
                    c.lineTo(10, 16); c.lineTo(13.5, 11.5); c.lineTo(11, 11.5)
                    c.closePath()
                    c.fill()
                }
            }
        }
    }

    Item {
        id: root
        anchors.fill: parent

        HoverHandler {
            onHoveredChanged: {
                if (hovered) {
                    holdTimer.stop()
                    bar.hoverHold = true
                } else {
                    holdTimer.restart()
                }
            }
        }

        Item {
            id: pillZone
            x: pill.x - 12
            y: 0
            width: pill.width + 24
            height: parent.height
        }

        Item {
            id: trigger
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            width: Math.max(pill.width, 300)
            height: 4
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 3
            width: 56
            height: 3
            radius: 1.5
            color: "#59ffffff"
            opacity: bar.shown ? 0 : 1

            Behavior on opacity {
                NumberAnimation { duration: 200 }
            }
        }

        Rectangle {
            id: pill
            anchors.horizontalCenter: parent.horizontalCenter
            y: bar.shown ? 8 : -height - 8
            height: 34
            width: row.width + 14
            radius: 17
            color: "#590a0a0b"
            border.color: "#14ffffff"
            border.width: 1

            Behavior on y {
                NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
            }
            Behavior on width {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            Row {
                id: row
                anchors.centerIn: parent
                spacing: 8

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    height: 26
                    radius: 13
                    color: appsArea.containsMouse ? "#1fffffff" : "#0dffffff"

                    Grid {
                        anchors.centerIn: parent
                        columns: 3
                        spacing: 2
                        Repeater {
                            model: 9
                            Rectangle { width: 2.5; height: 2.5; radius: 1.25; color: "#dcdcdc" }
                        }
                    }

                    MouseArea {
                        id: appsArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: Hyprland.dispatch("exec qs ipc call launcher toggle")
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatTime(clock.date, "HH:mm")
                        font.family: "Inter"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: "#f0f0f0"
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDate(clock.date, "ddd d")
                        font.family: "Inter"
                        font.pixelSize: 11
                        color: "#9a9a9a"
                    }
                }

                Sep {}

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Repeater {
                        model: 6

                        Rectangle {
                            required property int index
                            property int wsId: index + 1
                            property bool active: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === wsId
                            property bool occupied: Hyprland.workspaces.values.some(w => w.id === wsId)

                            anchors.verticalCenter: parent.verticalCenter
                            width: active ? 26 : 18
                            height: 18
                            radius: 9
                            color: active ? "#ececec" : (wsArea.containsMouse ? "#14ffffff" : "transparent")

                            Behavior on width {
                                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: parent.wsId
                                font.family: "Inter"
                                font.pixelSize: 10
                                font.weight: parent.active ? Font.Bold : Font.Medium
                                color: parent.active ? "#0a0a0b" : (parent.occupied ? "#dcdcdc" : "#6e6e6e")
                            }

                            MouseArea {
                                id: wsArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: Hyprland.dispatch("workspace " + parent.wsId)
                            }
                        }
                    }
                }

                MediaPill {
                    anchors.verticalCenter: parent.verticalCenter
                }

                Sep {}

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: statusRow.width + 14
                    height: 26
                    radius: 13
                    color: statusArea.containsMouse ? "#1fffffff" : "transparent"

                    Row {
                        id: statusRow
                        anchors.centerIn: parent
                        spacing: 9

                        Glyph {
                            kind: "wifi"
                            on: bar.wifiOn && bar.wifiName !== ""
                            level: bar.wifiSignal / 100
                        }

                        Glyph {
                            kind: "bt"
                            on: bar.btOn
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            Glyph { kind: "vol"; level: bar.volume; flag: bar.muted }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: bar.muted ? "0%" : Math.round(bar.volume * 100) + "%"
                                font.family: "Inter"
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: "#dcdcdc"
                            }
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            Battery { id: batWidget; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }

                    MouseArea {
                        id: statusArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: (mouse) => {
                            const m = mapToItem(null, mouse.x, mouse.y)
                            const b = batWidget.mapToItem(null, 0, 0)
                            if (m.x >= b.x - 4 && m.x <= b.x + batWidget.width + 4)
                                Hyprland.dispatch("exec qs ipc call battery toggle " + Math.round(b.x))
                            else
                                Hyprland.dispatch("exec qs ipc call quicksettings toggle")
                        }
                        onWheel: wheel => {
                            if (!bar.sink || !bar.sink.audio) return
                            const change = wheel.angleDelta.y / 2400
                            bar.sink.audio.muted = false
                            bar.sink.audio.volume = Math.max(0, Math.min(1, bar.sink.audio.volume + change))
                        }
                    }
                }

                Rectangle {
                    visible: bar.minCount > 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: minText.implicitWidth + 16
                    height: 22
                    radius: 11
                    color: minArea.containsMouse ? "#2affffff" : "#14ffffff"

                    Text {
                        id: minText
                        anchors.centerIn: parent
                        text: bar.minCount + " hidden"
                        font.family: "Inter"
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: "#dcdcdc"
                    }

                    MouseArea {
                        id: minArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: Hyprland.dispatch("togglespecialworkspace minimized")
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0
                    visible: bar.activeWin !== null

                    Sep {}

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        leftPadding: 10
                        rightPadding: 6
                        width: Math.min(implicitWidth, 150)
                        elide: Text.ElideRight
                        text: bar.appName
                        font.family: "Inter"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: nameArea.containsMouse ? "#ffffff" : "#dcdcdc"

                        MouseArea {
                            id: nameArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: clickTimer.restart()
                            onDoubleClicked: {
                                clickTimer.stop()
                                Hyprland.dispatch("exec sh $HOME/.config/quickshell/scripts/maximize.sh")
                            }

                            Timer {
                                id: clickTimer
                                interval: 260
                                onTriggered: Hyprland.dispatch("exec qs ipc call windows toggle " + Math.round(nameArea.mapToItem(null, 0, 0).x))
                            }
                        }
                    }

                    WinButton {
                        action: "movetoworkspacesilent special:minimized"
                        Rectangle { anchors.centerIn: parent; width: 9; height: 1.2; color: "#dcdcdc" }
                    }

                    WinButton {
                        action: "exec sh $HOME/.config/quickshell/scripts/maximize.sh"
                        Rectangle {
                            anchors.centerIn: parent
                            width: 8
                            height: 8
                            radius: 1.5
                            color: "transparent"
                            border.color: "#dcdcdc"
                            border.width: 1.2
                        }
                    }

                    WinButton {
                        action: "killactive"
                        danger: true
                        Rectangle { anchors.centerIn: parent; width: 10; height: 1.2; rotation: 45; color: "#dcdcdc" }
                        Rectangle { anchors.centerIn: parent; width: 10; height: 1.2; rotation: -45; color: "#dcdcdc" }
                    }
                }
            }
        }
    }
}
