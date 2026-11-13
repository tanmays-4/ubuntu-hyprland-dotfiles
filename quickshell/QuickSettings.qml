import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import QtQuick

PanelWindow {
    id: qs

    property bool open: false
    visible: open

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quicksettings"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"

    property bool wifiOn: true
    property string wifiName: ""
    property int wifiSignal: 0
    property bool btOn: false
    property real brightness: 0.5
    property bool showNetworks: false
    property bool showDevices: false
    property var networks: []
    property string selected: ""
    property bool needPassword: false
    property string netMessage: ""
    property string confirming: ""

    property var sink: Pipewire.defaultAudioSink
    property real volume: sink && sink.audio ? sink.audio.volume : 0
    property bool muted: sink && sink.audio ? sink.audio.muted : false

    property var bat: UPower.displayDevice
    property real batRaw: bat ? bat.percentage : 0
    property int batPct: Math.round(batRaw <= 1 ? batRaw * 100 : batRaw)
    property bool charging: bat && bat.state === UPowerDeviceState.Charging

    IpcHandler {
        target: "quicksettings"
        function toggle(): void { qs.open = !qs.open }
    }

    onOpenChanged: {
        if (open) {
            showNetworks = false
            showDevices = false
            needPassword = false
            netMessage = ""
            confirming = ""
            statusProc.running = true
            brightProc.running = true
            keyCatcher.forceActiveFocus()
        }
    }

    function run(cmd) {
        Hyprland.dispatch("exec " + cmd)
    }

    PwObjectTracker {
        objects: [ Pipewire.defaultAudioSink ]
    }

    Process {
        id: statusProc
        command: ["sh", Quickshell.env("HOME") + "/.config/quickshell/scripts/status.sh"]
        stdout: StdioCollector {
            id: statusOut
            onStreamFinished: {
                for (const line of statusOut.text.trim().split("\n")) {
                    const sp = line.indexOf(" ")
                    const key = sp === -1 ? line : line.slice(0, sp)
                    const val = sp === -1 ? "" : line.slice(sp + 1).trim()
                    if (key === "WIFI") {
                        const c = val.lastIndexOf(":")
                        qs.wifiName = c === -1 ? "" : val.slice(0, c)
                        qs.wifiSignal = c === -1 ? 0 : Number(val.slice(c + 1))
                    } else if (key === "RADIO") {
                        qs.wifiOn = val === "enabled"
                    } else if (key === "BT") {
                        qs.btOn = Number(val) > 0
                    }
                }
            }
        }
    }

    Timer {
        interval: 3000
        running: qs.open
        repeat: true
        onTriggered: statusProc.running = true
    }

    Process {
        id: brightProc
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            id: brightOut
            onStreamFinished: {
                const parts = brightOut.text.trim().split(",")
                if (parts.length > 3) qs.brightness = parseInt(parts[3]) / 100
            }
        }
    }

    Timer {
        id: brightApply
        interval: 80
        onTriggered: qs.run("brightnessctl set " + Math.max(1, Math.round(qs.brightness * 100)) + "%")
    }

    Process {
        id: scanProc
        command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL,SECURITY,SSID", "dev", "wifi", "list"]
        stdout: StdioCollector {
            id: scanOut
            onStreamFinished: {
                const best = {}
                for (const line of scanOut.text.trim().split("\n")) {
                    const p = line.split(":")
                    if (p.length < 4) continue
                    const ssid = p.slice(3).join(":").replace(/\\:/g, ":")
                    if (ssid === "") continue
                    const item = { ssid: ssid, signal: Number(p[1]), secure: p[2] !== "", active: p[0] === "*" }
                    if (!best[ssid] || best[ssid].signal < item.signal || item.active) best[ssid] = item
                }
                qs.networks = Object.values(best)
                    .sort((a, b) => (b.active - a.active) || (b.signal - a.signal))
                    .slice(0, 8)
            }
        }
    }

    Process {
        id: connectProc
        property bool withPassword: false
        onExited: (code, status) => {
            if (code === 0) {
                qs.netMessage = "Connected to " + qs.selected
                qs.needPassword = false
                pwField.text = ""
                statusProc.running = true
                scanProc.running = true
            } else if (!withPassword) {
                qs.needPassword = true
                qs.netMessage = "Enter the password for " + qs.selected
                pwField.editor.forceActiveFocus()
            } else {
                qs.netMessage = "Couldn't connect. Check the password."
            }
        }
    }

    function connect(ssid) {
        selected = ssid
        needPassword = false
        netMessage = "Connecting to " + ssid + "…"
        connectProc.withPassword = false
        connectProc.command = ["nmcli", "dev", "wifi", "connect", ssid]
        connectProc.running = true
    }

    function connectWithPassword() {
        if (pwField.text === "") return
        netMessage = "Connecting to " + selected + "…"
        connectProc.withPassword = true
        connectProc.command = ["nmcli", "dev", "wifi", "connect", selected, "password", pwField.text]
        connectProc.running = true
    }

    Timer {
        id: confirmReset
        interval: 3000
        onTriggered: qs.confirming = ""
    }

    function power(action) {
        if (action === "restart" || action === "poweroff") {
            if (confirming !== action) {
                confirming = action
                confirmReset.restart()
                return
            }
        }
        open = false
        if (action === "settings") run("env XDG_CURRENT_DESKTOP=GNOME gnome-control-center")
        else if (action === "lock") run("loginctl lock-session")
        else if (action === "logout") Hyprland.dispatch("exit")
        else if (action === "restart") run("systemctl reboot")
        else if (action === "poweroff") run("systemctl poweroff")
    }

    component Icon: Canvas {
        property string kind: "wifi"
        property string tint: "#dcdcdc"
        property real level: 1
        property bool on: true
        width: 18
        height: 18
        onKindChanged: requestPaint()
        onTintChanged: requestPaint()
        onLevelChanged: requestPaint()
        onOnChanged: requestPaint()
        onPaint: {
            const c = getContext("2d")
            c.reset()
            c.scale(width / 24, height / 24)
            c.strokeStyle = tint
            c.fillStyle = tint
            c.lineWidth = 2
            c.lineCap = "round"
            c.lineJoin = "round"

            if (kind === "wifi") {
                const bars = on ? (level > 0.66 ? 3 : (level > 0.33 ? 2 : (level > 0 ? 1 : 0))) : 0
                const radii = [5, 9.5, 14]
                for (let i = 0; i < 3; i++) {
                    c.globalAlpha = i < bars ? 1 : 0.3
                    c.beginPath()
                    c.arc(12, 20, radii[i], -Math.PI * 0.75, -Math.PI * 0.25)
                    c.stroke()
                }
                c.globalAlpha = 1
                c.beginPath(); c.arc(12, 20, 1.6, 0, 2 * Math.PI); c.fill()
            } else if (kind === "bt") {
                c.beginPath()
                c.moveTo(7, 7); c.lineTo(17, 16); c.lineTo(12, 20.5); c.lineTo(12, 3.5)
                c.lineTo(17, 8); c.lineTo(7, 17)
                c.stroke()
            } else if (kind === "vol") {
                c.beginPath()
                c.moveTo(3, 9.5); c.lineTo(7, 9.5); c.lineTo(12, 5); c.lineTo(12, 19)
                c.lineTo(7, 14.5); c.lineTo(3, 14.5); c.closePath()
                c.fill()
                if (!on) {
                    c.beginPath(); c.moveTo(16, 9); c.lineTo(21, 15); c.moveTo(21, 9); c.lineTo(16, 15); c.stroke()
                } else {
                    c.beginPath(); c.arc(13, 12, 4, -Math.PI / 3, Math.PI / 3); c.stroke()
                    c.beginPath(); c.arc(13, 12, 8, -Math.PI / 3, Math.PI / 3); c.stroke()
                }
            } else if (kind === "sun") {
                c.beginPath(); c.arc(12, 12, 4, 0, 2 * Math.PI); c.stroke()
                for (let i = 0; i < 8; i++) {
                    const a = i * Math.PI / 4
                    c.beginPath()
                    c.moveTo(12 + Math.cos(a) * 7, 12 + Math.sin(a) * 7)
                    c.lineTo(12 + Math.cos(a) * 9.5, 12 + Math.sin(a) * 9.5)
                    c.stroke()
                }
            } else if (kind === "gear") {
                c.beginPath(); c.arc(12, 12, 3, 0, 2 * Math.PI); c.stroke()
                c.beginPath(); c.arc(12, 12, 6.5, 0, 2 * Math.PI); c.stroke()
                for (let i = 0; i < 8; i++) {
                    const a = i * Math.PI / 4
                    c.beginPath()
                    c.moveTo(12 + Math.cos(a) * 6.5, 12 + Math.sin(a) * 6.5)
                    c.lineTo(12 + Math.cos(a) * 9.5, 12 + Math.sin(a) * 9.5)
                    c.stroke()
                }
            } else if (kind === "lock") {
                c.beginPath(); c.roundedRect(5, 11, 14, 10, 2, 2); c.stroke()
                c.beginPath(); c.arc(12, 11, 4.5, Math.PI, 0); c.stroke()
            } else if (kind === "logout") {
                c.beginPath()
                c.moveTo(10, 4); c.lineTo(5, 4); c.lineTo(5, 20); c.lineTo(10, 20)
                c.moveTo(10, 12); c.lineTo(20, 12)
                c.moveTo(16, 8); c.lineTo(20, 12); c.lineTo(16, 16)
                c.stroke()
            } else if (kind === "restart") {
                c.beginPath(); c.arc(12, 12, 8, -Math.PI * 0.3, Math.PI * 1.45); c.stroke()
                c.beginPath()
                c.moveTo(14.5, 2.5); c.lineTo(19, 5.5); c.lineTo(15, 9)
                c.stroke()
            } else if (kind === "power") {
                c.beginPath(); c.arc(12, 13, 8, -Math.PI / 2 + 0.75, -Math.PI / 2 - 0.75 + 2 * Math.PI); c.stroke()
                c.beginPath(); c.moveTo(12, 3); c.lineTo(12, 12); c.stroke()
            }
        }
    }

    component Tile: Rectangle {
        id: tile
        property string label: ""
        property string sub: ""
        property string icon: "wifi"
        property real iconLevel: 1
        property bool on: false
        signal toggled()
        signal more()

        height: 64
        radius: 14
        color: on ? "#ececec" : "#14ffffff"

        Behavior on color {
            ColorAnimation { duration: 150 }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: tile.toggled()
        }

        Rectangle {
            id: iconBox
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            radius: 16
            color: tile.on ? "#1a000000" : "#14ffffff"

            Icon {
                anchors.centerIn: parent
                kind: tile.icon
                level: tile.iconLevel
                on: tile.on
                tint: tile.on ? "#0a0a0b" : "#dcdcdc"
            }
        }

        Column {
            anchors.left: iconBox.right
            anchors.leftMargin: 10
            anchors.right: moreBtn.left
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                text: tile.label
                font.family: "Inter"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: tile.on ? "#0a0a0b" : "#ececec"
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: tile.sub
                font.family: "Inter"
                font.pixelSize: 11
                color: tile.on ? "#4a4a4a" : "#8a8a8a"
            }
        }

        Rectangle {
            id: moreBtn
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 40
            radius: 10
            color: moreArea.containsMouse ? (tile.on ? "#1a000000" : "#1fffffff") : "transparent"

            Text {
                anchors.centerIn: parent
                text: "›"
                font.family: "Inter"
                font.pixelSize: 20
                color: tile.on ? "#0a0a0b" : "#ececec"
            }

            MouseArea {
                id: moreArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: tile.more()
            }
        }
    }

    component Slider: Item {
        id: slider
        property string icon: "vol"
        property bool iconOn: true
        property real value: 0
        signal moved(real v)

        height: 32

        Icon {
            id: sliderIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            kind: slider.icon
            on: slider.iconOn
        }

        Rectangle {
            id: sliderTrack
            anchors.left: sliderIcon.right
            anchors.leftMargin: 14
            anchors.right: sliderPct.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            height: 8
            radius: 4
            color: "#1fffffff"

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, slider.value))
                height: parent.height
                radius: 4
                color: "#ececec"
            }

            MouseArea {
                anchors.fill: parent
                anchors.topMargin: -12
                anchors.bottomMargin: -12
                function update(x) {
                    slider.moved(Math.max(0, Math.min(1, x / sliderTrack.width)))
                }
                onPressed: mouse => update(mouse.x)
                onPositionChanged: mouse => update(mouse.x)
            }
        }

        Text {
            id: sliderPct
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 38
            horizontalAlignment: Text.AlignRight
            text: Math.round(slider.value * 100) + "%"
            font.family: "JetBrains Mono"
            font.pixelSize: 11
            color: "#b4b4b4"
        }
    }

    component PowerButton: Rectangle {
        id: pbtn
        property string label: ""
        property string action: ""
        property string icon: "gear"
        property bool armed: qs.confirming === action
        height: 38
        radius: 10
        color: armed ? "#ececec" : (pArea.containsMouse ? "#24ffffff" : "#14ffffff")

        Row {
            anchors.centerIn: parent
            spacing: 7

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                width: 15
                height: 15
                kind: pbtn.icon
                tint: pbtn.armed ? "#0a0a0b" : "#dcdcdc"
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pbtn.armed ? "Sure?" : pbtn.label
                font.family: "Inter"
                font.pixelSize: 12
                font.weight: Font.Medium
                color: pbtn.armed ? "#0a0a0b" : "#dcdcdc"
            }
        }

        MouseArea {
            id: pArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: qs.power(pbtn.action)
        }
    }

    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: qs.open = false

        MouseArea {
            anchors.fill: parent
            onClicked: qs.open = false
        }

        Rectangle {
            id: panel
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 50
            width: 360
            height: content.implicitHeight + 32
            radius: 18
            color: "#eb0a0a0b"
            border.color: "#14ffffff"
            border.width: 1

            MouseArea { anchors.fill: parent }

            Column {
                id: content
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 14

                Row {
                    width: parent.width

                    Text {
                        width: parent.width - batText.width
                        text: "QUICK SETTINGS"
                        font.family: "JetBrains Mono"
                        font.pixelSize: 10
                        font.letterSpacing: 1.6
                        color: "#8a8a8a"
                    }

                    Text {
                        id: batText
                        text: "BAT " + qs.batPct + "%" + (qs.charging ? " · CHARGING" : "")
                        font.family: "JetBrains Mono"
                        font.pixelSize: 10
                        color: "#9a9a9a"
                    }
                }

                Row {
                    width: parent.width
                    spacing: 10

                    Tile {
                        width: (parent.width - 10) / 2
                        label: "Wi-Fi"
                        icon: "wifi"
                        iconLevel: qs.wifiSignal > 0 ? qs.wifiSignal / 100 : 1
                        on: qs.wifiOn
                        sub: !qs.wifiOn ? "Off" : (qs.wifiName !== "" ? qs.wifiName : "Not connected")
                        onToggled: {
                            qs.run("nmcli radio wifi " + (qs.wifiOn ? "off" : "on"))
                            qs.wifiOn = !qs.wifiOn
                        }
                        onMore: {
                            qs.showNetworks = !qs.showNetworks
                            if (qs.showNetworks) scanProc.running = true
                        }
                    }

                    Tile {
                        width: (parent.width - 10) / 2
                        label: "Bluetooth"
                        icon: "bt"
                        on: qs.btOn
                        sub: qs.btOn ? "On" : "Off"
                        onToggled: {
                            qs.run("bluetoothctl power " + (qs.btOn ? "off" : "on"))
                            qs.btOn = !qs.btOn
                        }
                        onMore: qs.showDevices = !qs.showDevices
                    }
                }

                Column {
                    visible: qs.showNetworks
                    width: parent.width
                    spacing: 4

                    Text {
                        visible: qs.networks.length === 0
                        text: qs.wifiOn ? "Scanning…" : "Wi-Fi is off"
                        font.family: "Inter"
                        font.pixelSize: 12
                        color: "#8a8a8a"
                    }

                    Repeater {
                        model: qs.networks

                        Rectangle {
                            id: netRow
                            required property var modelData
                            width: parent.width
                            height: 34
                            radius: 9
                            color: netArea.containsMouse ? "#14ffffff" : "transparent"

                            Icon {
                                id: netIcon
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: 15
                                height: 15
                                kind: "wifi"
                                level: netRow.modelData.signal / 100
                            }

                            Text {
                                anchors.left: netIcon.right
                                anchors.leftMargin: 10
                                anchors.right: netInfo.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                text: netRow.modelData.ssid
                                font.family: "Inter"
                                font.pixelSize: 12
                                font.weight: netRow.modelData.active ? Font.DemiBold : Font.Normal
                                color: "#ececec"
                            }

                            Row {
                                id: netInfo
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                Icon {
                                    visible: netRow.modelData.secure
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 12
                                    height: 12
                                    kind: "lock"
                                    tint: "#8a8a8a"
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: netRow.modelData.active ? "CONNECTED" : netRow.modelData.signal + "%"
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 9
                                    color: "#8a8a8a"
                                }
                            }

                            MouseArea {
                                id: netArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: if (!netRow.modelData.active) qs.connect(netRow.modelData.ssid)
                            }
                        }
                    }

                    Field {
                        id: pwField
                        visible: qs.needPassword
                        width: parent.width
                        hint: "Password"
                        editor.echoMode: TextInput.Password
                        onSubmitted: qs.connectWithPassword()
                    }

                    Text {
                        visible: qs.netMessage !== ""
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: qs.netMessage
                        font.family: "Inter"
                        font.pixelSize: 11
                        color: "#9a9a9a"
                    }
                }

                BluetoothList {
                    width: parent.width
                    visible: qs.showDevices
                    active: qs.open && qs.showDevices
                }

                Slider {
                    width: parent.width
                    icon: "vol"
                    iconOn: !qs.muted
                    value: qs.muted ? 0 : qs.volume
                    onMoved: v => {
                        if (qs.sink && qs.sink.audio) {
                            qs.sink.audio.muted = false
                            qs.sink.audio.volume = v
                        }
                    }
                }

                Slider {
                    width: parent.width
                    icon: "sun"
                    value: qs.brightness
                    onMoved: v => {
                        qs.brightness = Math.max(0.01, v)
                        brightApply.restart()
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#0fffffff"
                }

                Grid {
                    width: parent.width
                    columns: 3
                    columnSpacing: 8
                    rowSpacing: 8

                    PowerButton { width: (parent.width - 16) / 3; label: "Settings"; icon: "gear"; action: "settings" }
                    PowerButton { width: (parent.width - 16) / 3; label: "Lock"; icon: "lock"; action: "lock" }
                    PowerButton { width: (parent.width - 16) / 3; label: "Log out"; icon: "logout"; action: "logout" }
                    PowerButton { width: (parent.width - 16) / 3; label: "Restart"; icon: "restart"; action: "restart" }
                    PowerButton { width: (parent.width - 16) / 3; label: "Power off"; icon: "power"; action: "poweroff" }
                }
            }
        }
    }
}
