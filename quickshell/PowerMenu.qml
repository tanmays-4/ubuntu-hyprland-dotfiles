import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: pm

    property bool open: false
    property string armed: ""          // action waiting for its second press
    property bool canHibernate: false
    property var pending: null

    visible: open
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "power"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"

    IpcHandler {
        target: "power"
        function toggle(): void { pm.open = !pm.open }
    }

    onOpenChanged: {
        armed = ""
        if (open) {
            hibCheck.running = true
            Qt.callLater(() => keys.forceActiveFocus())
        }
    }

    // ask the system whether hibernate is possible
    Process {
        id: hibCheck
        command: ["busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1",
                  "org.freedesktop.login1.Manager", "CanHibernate"]
        stdout: StdioCollector {
            id: hout
            onStreamFinished: pm.canHibernate = hout.text.indexOf("\"yes\"") !== -1
        }
    }

    readonly property var actions: [
        { id: "lock",      key: "L", label: "Lock",      sub: "Keep everything open",          cmd: ["loginctl", "lock-session"],   confirm: false },
        { id: "sleep",     key: "S", label: "Sleep",     sub: "Low power, wakes instantly",    cmd: ["systemctl", "suspend"],        confirm: false },
        { id: "logout",    key: "E", label: "Log out",   sub: "Close all apps",                cmd: ["hyprctl", "dispatch", "exit"], confirm: true },
        { id: "reboot",    key: "R", label: "Restart",   sub: "Close everything and restart",  cmd: ["systemctl", "reboot"],         confirm: true },
        { id: "poweroff",  key: "P", label: "Shut down", sub: "Close everything and turn off", cmd: ["systemctl", "poweroff"],       confirm: true }
    ]

    function run(a) {
        if (a.id === "hibernate" && !canHibernate) return
        if (a.confirm && armed !== a.id) {
            armed = a.id
            return
        }
        pending = a
        open = false
        delay.restart()
    }

    // let the menu disappear before the screen locks / sleeps
    Timer {
        id: delay
        interval: 200
        onTriggered: if (pm.pending) Quickshell.execDetached(pm.pending.cmd)
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: pm.open = false
        Keys.onPressed: event => {
            const k = (event.text || "").toUpperCase()
            const a = pm.actions.find(x => x.key === k)
            if (a) {
                pm.run(a)
                event.accepted = true
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "#b3000000"
            opacity: pm.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
            MouseArea {
                anchors.fill: parent
                onClicked: pm.open = false
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 28
            opacity: pm.open ? 1 : 0
            scale: pm.open ? 1 : 0.95
            Behavior on opacity { NumberAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "POWER"
                font.family: "JetBrains Mono"
                font.pixelSize: 11
                font.letterSpacing: 3
                color: "#8a8a8a"
            }

            Row {
                spacing: 14

                Repeater {
                    model: pm.actions

                    Rectangle {
                        id: tile
                        required property var modelData
                        property bool disabled: modelData.id === "hibernate" && !pm.canHibernate
                        property bool armedNow: pm.armed === modelData.id

                        width: 150
                        height: 160
                        radius: 22
                        opacity: disabled ? 0.35 : 1
                        color: armedNow ? "#ececec" : (tileArea.containsMouse && !disabled ? "#24ffffff" : "#12ffffff")
                        border.color: "#1fffffff"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 10

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 48
                                height: 48
                                radius: 24
                                color: "transparent"
                                border.color: tile.armedNow ? "#0a0a0b" : "#8a8a8a"
                                border.width: 1.4
                                Text {
                                    anchors.centerIn: parent
                                    text: tile.modelData.key
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 18
                                    font.weight: Font.Bold
                                    color: tile.armedNow ? "#0a0a0b" : "#ececec"
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tile.modelData.label
                                font.family: "Inter"
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                color: tile.armedNow ? "#0a0a0b" : "#ffffff"
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 130
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                text: tile.armedNow ? "Press again to confirm"
                                    : (tile.disabled ? "Not set up" : tile.modelData.sub)
                                font.family: "Inter"
                                font.pixelSize: 10
                                color: tile.armedNow ? "#3a3a3a" : "#8a8a8a"
                            }
                        }

                        MouseArea {
                            id: tileArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: tile.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onClicked: pm.run(tile.modelData)
                        }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Press a letter or click  ·  Esc to close"
                font.family: "Inter"
                font.pixelSize: 11
                color: "#6e6e6e"
            }
        }
    }
}
