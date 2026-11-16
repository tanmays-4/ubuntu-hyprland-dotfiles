import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

PanelWindow {
    id: menu

    property bool open: false
    property real menuX: -1
    property string target: ""
    property real closedAt: 0
    property int screenW: Quickshell.screens.length > 0 ? Quickshell.screens[0].width : 1536
    property int cardW: 4 * 112 + 3 * 12 + 32

    visible: open
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "snap"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        left: true
    }
    margins {
        top: 46
        left: menu.menuX < 0
              ? (menu.screenW - menu.cardW) / 2
              : Math.max(8, Math.min(menu.screenW - menu.cardW - 8, menu.menuX - menu.cardW / 2))
    }
    implicitWidth: cardW
    implicitHeight: card.height + 12
    color: "transparent"

    HyprlandFocusGrab {
        windows: [ menu ]
        active: menu.open
        onCleared: menu.open = false
    }

    IpcHandler {
        target: "snap"
        function toggle(x: int): void {
            if (menu.open) {
                menu.open = false
                return
            }
            if (Date.now() - menu.closedAt < 300) return
            menu.menuX = x
            getActive.running = true
        }
    }

    // remember which window to snap before the menu takes focus
    Process {
        id: getActive
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            id: aout
            onStreamFinished: {
                menu.target = ""
                try {
                    const w = JSON.parse(aout.text)
                    if (w && w.address && w.workspace && w.workspace.id > 0) menu.target = w.address
                } catch (e) {}
                if (menu.target !== "") menu.open = true
            }
        }
    }

    onOpenChanged: {
        if (open) keys.forceActiveFocus()
        else closedAt = Date.now()
    }

    function snap(pos) {
        open = false
        Quickshell.execDetached(["python3", Quickshell.env("HOME") + "/.config/quickshell/scripts/snap.py", pos, target])
    }

    // one clickable zone inside a layout preview
    component Zone: Rectangle {
        property string pos: ""
        radius: 4
        color: zoneArea.containsMouse ? "#ececec" : "#1fffffff"
        border.color: "#26ffffff"
        border.width: 1
        Behavior on color { ColorAnimation { duration: 100 } }

        MouseArea {
            id: zoneArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: menu.snap(parent.pos)
        }
    }

    // one layout preview (a mini screen)
    component Preview: Item {
        property string label: ""
        default property alias zones: screen.data
        width: 112
        height: 70 + 18

        Rectangle {
            id: screen
            width: 112
            height: 70
            radius: 7
            color: "#0dffffff"
            border.color: "#1affffff"
            border.width: 1
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            text: parent.label
            font.family: "Inter"
            font.pixelSize: 9
            color: "#7c7c7c"
        }
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: menu.open = false

        Rectangle {
            id: card
            y: 4
            width: menu.cardW
            height: col.implicitHeight + 28
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
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 10

                Text {
                    text: "SNAP LAYOUTS"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 9
                    font.letterSpacing: 1.4
                    color: "#7c7c7c"
                }

                Row {
                    spacing: 12

                    // halves
                    Preview {
                        label: "Halves"
                        Zone { pos: "left";  x: 4;  y: 4; width: 50; height: 62 }
                        Zone { pos: "right"; x: 58; y: 4; width: 50; height: 62 }
                    }

                    // quarters
                    Preview {
                        label: "Quarters"
                        Zone { pos: "tl"; x: 4;  y: 4;  width: 50; height: 29 }
                        Zone { pos: "tr"; x: 58; y: 4;  width: 50; height: 29 }
                        Zone { pos: "bl"; x: 4;  y: 37; width: 50; height: 29 }
                        Zone { pos: "br"; x: 58; y: 37; width: 50; height: 29 }
                    }

                    // one big + two small
                    Preview {
                        label: "1 + 2"
                        Zone { pos: "left"; x: 4;  y: 4;  width: 50; height: 62 }
                        Zone { pos: "tr";   x: 58; y: 4;  width: 50; height: 29 }
                        Zone { pos: "br";   x: 58; y: 37; width: 50; height: 29 }
                    }

                    // maximise
                    Preview {
                        label: "Maximise"
                        Zone { pos: "max"; x: 4; y: 4; width: 104; height: 62 }
                    }
                }
            }
        }
    }
}

