import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick

PanelWindow {
    id: menu

    property bool open: false
    property real menuX: 0
    property var wins: []
    property real closedAt: 0
    property int screenW: Quickshell.screens.length > 0 ? Quickshell.screens[0].width : 1536

    visible: open

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "windowmenu"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        left: true
    }
    margins {
        top: 46
        left: Math.max(8, Math.min(menu.screenW - 328, menu.menuX - 12))
    }
    implicitWidth: 320
    implicitHeight: card.height + 12
    color: "transparent"

    HyprlandFocusGrab {
        windows: [ menu ]
        active: menu.open
        onCleared: menu.open = false
    }

    IpcHandler {
        target: "windows"
        function toggle(x: int): void {
            if (menu.open) {
                menu.open = false
                return
            }
            if (Date.now() - menu.closedAt < 300) return
            menu.menuX = x
            clients.running = true
        }
    }

    onOpenChanged: {
        if (open) keys.forceActiveFocus()
        else closedAt = Date.now()
    }

    function iconFor(cls) {
        try {
            const e = DesktopEntries.heuristicLookup(cls)
            if (e && e.icon) return Quickshell.iconPath(e.icon, "application-x-executable")
        } catch (err) {}
        return Quickshell.iconPath((cls || "").toLowerCase(), "application-x-executable")
    }

    function nameFor(cls, title) {
        try {
            const e = DesktopEntries.heuristicLookup(cls)
            if (e && e.name) return e.name
        } catch (err) {}
        return cls || title
    }

    Process {
        id: clients
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            id: cout
            onStreamFinished: {
                let list = []
                try { list = JSON.parse(cout.text) } catch (e) {}
                list = list.filter(c => c.mapped && c.address)
                list.sort((a, b) => a.focusHistoryID - b.focusHistoryID)
                menu.wins = list
                menu.open = true
            }
        }
    }

    function activate(w) {
        open = false
        if (w.workspace && w.workspace.id < 0) {
            const target = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
            Hyprland.dispatch("movetoworkspace " + target + ",address:" + w.address)
        }
        Hyprland.dispatch("focuswindow address:" + w.address)
    }

    function closeWin(i) {
        const w = wins[i]
        if (!w) return
        Hyprland.dispatch("closewindow address:" + w.address)
        const list = wins.slice()
        list.splice(i, 1)
        wins = list
        if (list.length === 0) open = false
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: menu.open = false

        Rectangle {
            id: card
            y: 4
            width: 320
            height: content.implicitHeight + 16
            radius: 16
            color: "#e60a0a0b"
            border.color: "#1affffff"
            border.width: 1
            transformOrigin: Item.Top
            scale: menu.open ? 1 : 0.9
            opacity: menu.open ? 1 : 0

            Behavior on scale {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }

            Column {
                id: content
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                spacing: 2

                Text {
                    leftPadding: 10
                    topPadding: 4
                    bottomPadding: 6
                    text: "OPEN WINDOWS  ·  " + menu.wins.length
                    font.family: "JetBrains Mono"
                    font.pixelSize: 9
                    font.letterSpacing: 1.4
                    color: "#7c7c7c"
                }

                ListView {
                    id: list
                    width: parent.width
                    height: Math.min(contentHeight, 420)
                    clip: true
                    spacing: 2
                    model: menu.wins
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        property bool current: index === 0
                        property bool hidden: modelData.workspace && modelData.workspace.id < 0

                        width: list.width
                        height: 46
                        radius: 10
                        color: rowHover.hovered ? "#1affffff" : (current ? "#0fffffff" : "transparent")

                        HoverHandler { id: rowHover }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: menu.activate(row.modelData)
                        }

                        IconImage {
                            id: icon
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 24
                            source: menu.iconFor(row.modelData.class)
                        }

                        Column {
                            anchors.left: icon.right
                            anchors.leftMargin: 12
                            anchors.right: right.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: menu.nameFor(row.modelData.class, row.modelData.title)
                                font.family: "Inter"
                                font.pixelSize: 12
                                font.weight: row.current ? Font.DemiBold : Font.Medium
                                color: row.current ? "#ffffff" : "#dcdcdc"
                            }

                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: row.modelData.title
                                font.family: "Inter"
                                font.pixelSize: 10
                                color: "#7c7c7c"
                            }
                        }

                        Item {
                            id: right
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 52
                            height: 22

                            Rectangle {
                                visible: row.current && !rowHover.hovered
                                anchors.right: parent.right
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                width: 6
                                height: 6
                                radius: 3
                                color: "#ececec"
                            }

                            Text {
                                visible: row.hidden && !rowHover.hovered
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: "HIDDEN"
                                font.family: "JetBrains Mono"
                                font.pixelSize: 8
                                color: "#7c7c7c"
                            }

                            Rectangle {
                                visible: rowHover.hovered
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 22
                                height: 22
                                radius: 11
                                color: closeArea.containsMouse ? "#ececec" : "#1fffffff"

                                Rectangle { anchors.centerIn: parent; width: 9; height: 1.4; rotation: 45; color: closeArea.containsMouse ? "#0a0a0b" : "#dcdcdc" }
                                Rectangle { anchors.centerIn: parent; width: 9; height: 1.4; rotation: -45; color: closeArea.containsMouse ? "#0a0a0b" : "#dcdcdc" }

                                MouseArea {
                                    id: closeArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: menu.closeWin(row.index)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
