import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower
import QtQuick

PanelWindow {
    id: menu

    property bool open: false
    property real menuX: 0
    property real closedAt: 0
    property int screenW: Quickshell.screens.length > 0 ? Quickshell.screens[0].width : 1536

    readonly property var dev: UPower.displayDevice
    readonly property real pct: dev ? (dev.percentage <= 1 ? dev.percentage * 100 : dev.percentage) : 0
    readonly property bool charging: !UPower.onBattery
    readonly property color tint: charging ? "#4ade80" : pct < 15 ? "#ef4444" : PowerProfiles.profile === PowerProfile.PowerSaver ? "#facc15" : "#ececec"

    // ---------- auto power saver ----------
    property bool autoSet: false
    property int prevProfile: PowerProfile.Balanced

    function checkLow() {
        if (UPower.onBattery && pct > 0 && pct < 30 && !autoSet) {
            prevProfile = PowerProfiles.profile
            autoSet = true
            if (prevProfile !== PowerProfile.PowerSaver) {
                PowerProfiles.profile = PowerProfile.PowerSaver
                Quickshell.execDetached(["notify-send", "Battery " + Math.round(pct) + "%", "Switched to Power Saver"])
            }
        }
        if (!UPower.onBattery && autoSet) {
            PowerProfiles.profile = prevProfile
            autoSet = false
        }
    }

    Connections {
        target: menu.dev
        ignoreUnknownSignals: true
        function onPercentageChanged() { menu.checkLow() }
    }
    Connections {
        target: UPower
        function onOnBatteryChanged() { menu.checkLow() }
    }
    Timer { interval: 60000; running: true; repeat: true; onTriggered: menu.checkLow() }
    Component.onCompleted: checkLow()

    function timeText() {
        if (!dev) return ""
        const s = charging ? dev.timeToFull : dev.timeToEmpty
        if (!s || s <= 0) return charging ? (pct >= 99 ? "Fully charged" : "Charging") : "On battery"
        const h = Math.floor(s / 3600)
        const m = Math.round((s % 3600) / 60)
        return (h > 0 ? h + "h " : "") + m + "m " + (charging ? "until full" : "left")
    }

    // ---------- window ----------
    visible: open
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "battery"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        left: true
    }
    margins {
        top: 46
        left: Math.max(8, Math.min(menu.screenW - 268, menu.menuX - 110))
    }
    implicitWidth: 260
    implicitHeight: card.height + 12
    color: "transparent"

    HyprlandFocusGrab {
        windows: [ menu ]
        active: menu.open
        onCleared: menu.open = false
    }

    IpcHandler {
        target: "battery"
        function toggle(x: int): void {
            if (menu.open) {
                menu.open = false
                return
            }
            if (Date.now() - menu.closedAt < 300) return
            menu.menuX = x
            menu.open = true
        }
    }

    onOpenChanged: {
        if (open) keys.forceActiveFocus()
        else closedAt = Date.now()
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: menu.open = false

        Rectangle {
            id: card
            y: 4
            width: 260
            height: col.implicitHeight + 24
            radius: 16
            color: "#e60a0a0b"
            border.color: "#1affffff"
            border.width: 1
            transformOrigin: Item.Top
            scale: menu.open ? 1 : 0.9
            opacity: menu.open ? 1 : 0
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 150 } }

            Column {
                id: col
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 4

                // header: big percentage + status
                Row {
                    leftPadding: 6
                    spacing: 10
                    Text {
                        text: Math.round(menu.pct) + "%"
                        font.family: "Inter"
                        font.pixelSize: 28
                        font.weight: Font.DemiBold
                        color: menu.tint
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            text: menu.charging ? "⚡ Plugged in" : "On battery"
                            font.family: "Inter"
                            font.pixelSize: 11
                            color: "#dcdcdc"
                        }
                        Text {
                            text: menu.timeText()
                            font.family: "Inter"
                            font.pixelSize: 10
                            color: "#7c7c7c"
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: "#14ffffff" }

                Text {
                    leftPadding: 6
                    topPadding: 4
                    bottomPadding: 2
                    text: "POWER MODE"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 9
                    font.letterSpacing: 1.4
                    color: "#7c7c7c"
                }

                Repeater {
                    model: [
                        { name: "Performance", sub: "Fastest, uses more battery", p: PowerProfile.Performance, c: "#ececec" },
                        { name: "Balanced",    sub: "Speed and battery balanced", p: PowerProfile.Balanced,    c: "#ececec" },
                        { name: "Power Saver", sub: "Longest battery life",       p: PowerProfile.PowerSaver,  c: "#facc15" }
                    ]

                    delegate: Rectangle {
                        id: opt
                        required property var modelData
                        property bool active: PowerProfiles.profile === modelData.p
                        property bool usable: modelData.p !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile

                        width: col.width
                        height: 42
                        radius: 10
                        opacity: usable ? 1 : 0.4
                        color: optHover.hovered && usable ? "#1affffff" : (active ? "#0fffffff" : "transparent")

                        HoverHandler { id: optHover }

                        MouseArea {
                            anchors.fill: parent
                            enabled: opt.usable
                            onClicked: {
                                PowerProfiles.profile = opt.modelData.p
                                menu.autoSet = false
                            }
                        }

                        Rectangle {
                            id: dot
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: 10
                            height: 10
                            radius: 5
                            color: opt.active ? opt.modelData.c : "transparent"
                            border.color: opt.modelData.c
                            border.width: 1.2
                        }

                        Column {
                            anchors.left: dot.right
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: opt.modelData.name
                                font.family: "Inter"
                                font.pixelSize: 12
                                font.weight: opt.active ? Font.DemiBold : Font.Medium
                                color: opt.active ? "#ffffff" : "#dcdcdc"
                            }
                            Text {
                                text: opt.modelData.sub
                                font.family: "Inter"
                                font.pixelSize: 10
                                color: "#7c7c7c"
                            }
                        }

                        Text {
                            visible: opt.active
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: "✓"
                            font.pixelSize: 13
                            color: opt.modelData.c
                        }
                    }
                }

                Text {
                    leftPadding: 6
                    topPadding: 6
                    text: "Auto Power Saver below 30%"
                    font.family: "Inter"
                    font.pixelSize: 9
                    color: "#5c5c5c"
                }
            }
        }
    }
}
