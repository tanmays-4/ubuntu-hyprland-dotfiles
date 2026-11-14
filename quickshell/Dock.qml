import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

PanelWindow {
    id: dock
    required property var modelData
    screen: modelData

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dock"
    exclusionMode: ExclusionMode.Ignore

    anchors {
        bottom: true
    }
    implicitWidth: Math.max(panel.width, 220) + 40
    implicitHeight: 84
    color: "transparent"

    property bool shown: false

    property var apps: [
        { kind: "terminal", cmd: "kitty", ids: ["kitty"] },
        { kind: "folder", cmd: "nautilus", ids: ["org.gnome.nautilus", "nautilus"] },
        { kind: "globe", cmd: "brave-browser", ids: ["brave-browser", "firefox", "google-chrome"] },
        { kind: "code", cmd: "code", ids: ["code", "code-url-handler"] },
        { kind: "music", cmd: "brave-browser --app=https://music.apple.com", ids: ["music.apple.com"] },
        { kind: "settings", cmd: "env XDG_CURRENT_DESKTOP=GNOME gnome-control-center", ids: ["org.gnome.settings", "gnome-control-center"] }
    ]

    mask: Region {
        item: dock.shown ? shownZone : triggerZone
    }

    function show() {
        hideTimer.stop()
        shown = true
    }

    IpcHandler {
        target: "dock"
        function toggle(): void {
            if (dock.shown) {
                dock.shown = false
            } else {
                dock.show()
                if (!hover.hovered) hideTimer.restart()
            }
        }
    }

    Timer {
        id: hideTimer
        interval: 700
        onTriggered: dock.shown = false
    }

    component Glyph: Canvas {
        property string kind: "terminal"
        width: 20
        height: 20
        onKindChanged: requestPaint()
        onPaint: {
            const c = getContext("2d")
            c.reset()
            c.scale(width / 24, height / 24)
            c.strokeStyle = "#dcdcdc"
            c.fillStyle = "#dcdcdc"
            c.lineWidth = 1.8
            c.lineCap = "round"
            c.lineJoin = "round"
            c.beginPath()
            if (kind === "terminal") {
                c.moveTo(5, 7); c.lineTo(10, 12); c.lineTo(5, 17)
                c.moveTo(12, 17); c.lineTo(19, 17)
                c.stroke()
            } else if (kind === "folder") {
                c.moveTo(3, 7); c.lineTo(3, 18); c.lineTo(21, 18); c.lineTo(21, 9)
                c.lineTo(11, 9); c.lineTo(9, 6); c.lineTo(4, 6); c.closePath()
                c.stroke()
            } else if (kind === "globe") {
                c.arc(12, 12, 9, 0, 2 * Math.PI)
                c.moveTo(3, 12); c.lineTo(21, 12)
                c.stroke()
                c.beginPath()
                c.ellipse(8, 3, 8, 18)
                c.stroke()
            } else if (kind === "code") {
                c.moveTo(8, 7); c.lineTo(3, 12); c.lineTo(8, 17)
                c.moveTo(16, 7); c.lineTo(21, 12); c.lineTo(16, 17)
                c.stroke()
            } else if (kind === "music") {
                c.moveTo(9, 18); c.lineTo(9, 5); c.lineTo(20, 3); c.lineTo(20, 16)
                c.stroke()
                c.beginPath(); c.arc(6, 18, 3, 0, 2 * Math.PI); c.stroke()
                c.beginPath(); c.arc(17, 16, 3, 0, 2 * Math.PI); c.stroke()
            } else {
                c.moveTo(4, 6); c.lineTo(20, 6)
                c.moveTo(4, 12); c.lineTo(20, 12)
                c.moveTo(4, 18); c.lineTo(20, 18)
                c.stroke()
                c.beginPath(); c.arc(15, 6, 2.2, 0, 2 * Math.PI); c.fill()
                c.beginPath(); c.arc(9, 12, 2.2, 0, 2 * Math.PI); c.fill()
                c.beginPath(); c.arc(13, 18, 2.2, 0, 2 * Math.PI); c.fill()
            }
        }
    }

    Item {
        id: root
        anchors.fill: parent

        HoverHandler {
            id: hover
            onHoveredChanged: {
                if (hovered) dock.show()
                else if (dock.shown) hideTimer.restart()
            }
        }

        Item {
            id: triggerZone
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: 220
            height: 8
        }

        Item {
            id: shownZone
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: Math.max(panel.width, 220)
            height: panel.height + 22
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            width: 70
            height: 4
            radius: 2
            color: "#40ffffff"
            opacity: dock.shown ? 0 : 1

            Behavior on opacity {
                NumberAnimation { duration: 200 }
            }
        }

        Rectangle {
            id: panel
            anchors.horizontalCenter: parent.horizontalCenter
            width: row.width + 16
            height: 56
            radius: 14
            color: "#e00a0a0b"
            border.color: "#14ffffff"
            border.width: 1
            y: dock.shown ? root.height - height - 14 : root.height + 10
            opacity: dock.shown ? 1 : 0

            Behavior on y {
                NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: 200 }
            }

            Row {
                id: row
                anchors.centerIn: parent
                spacing: 6

                Repeater {
                    model: dock.apps

                    Rectangle {
                        id: appBtn
                        required property var modelData
                        property var hwin: Hyprland.toplevels.values.find(t => t.wayland && t.workspace && Hyprland.focusedWorkspace
                            && (t.workspace.id === Hyprland.focusedWorkspace.id || t.workspace.id < 0)
                            && modelData.ids.some(id => (t.wayland.appId || "").toLowerCase().indexOf(id) !== -1))
                        property var win: hwin ? hwin.wayland : null
                        property bool running: win !== undefined && win !== null

                        width: 42
                        height: 42
                        radius: 11
                        color: btnArea.containsMouse ? "#1fffffff" : "#0dffffff"

                        Glyph {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -2
                            kind: appBtn.modelData.kind
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                            width: 4
                            height: 4
                            radius: 2
                            color: appBtn.running ? "#ececec" : "transparent"
                        }

                        MouseArea {
                            id: btnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (appBtn.running) {
                                    const a = String(appBtn.hwin.address)
                                    if (appBtn.hwin.workspace.id < 0 && Hyprland.focusedWorkspace)
                                        Hyprland.dispatch("movetoworkspace " + Hyprland.focusedWorkspace.id + ",address:" + (a.startsWith("0x") ? a : "0x" + a))
                                    appBtn.win.activate()
                                }
                                else Hyprland.dispatch("exec " + appBtn.modelData.cmd)
                                dock.shown = false
                            }
                        }
                    }
                }
            }
        }
    }
}
