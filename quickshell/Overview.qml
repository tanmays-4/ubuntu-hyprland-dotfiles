import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick

PanelWindow {
    id: ov

    property bool open: false
    property var wins: []
    property int index: 0

    visible: open

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "overview"
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
        target: "overview"
        function toggle(): void {
            if (ov.open) ov.open = false
            else ov.show()
        }
    }

    function addressOf(t) {
        return "0x" + String(t.address).replace(/^0x/, "")
    }

    function appNameOf(t) {
        const id = t.wayland ? t.wayland.appId : ""
        try {
            const e = DesktopEntries.heuristicLookup(id)
            if (e && e.name) return e.name
        } catch (err) {}
        return id || t.title
    }

    function iconOf(t) {
        const id = t.wayland ? t.wayland.appId : ""
        try {
            const e = DesktopEntries.heuristicLookup(id)
            if (e && e.icon) return Quickshell.iconPath(e.icon, "application-x-executable")
        } catch (err) {}
        return Quickshell.iconPath((id || "").toLowerCase(), "application-x-executable")
    }

    function show() {
        try { Hyprland.refreshToplevels() } catch (e) {}
        const active = ToplevelManager.activeToplevel
        const list = Hyprland.toplevels.values.filter(t => t.wayland)
        list.sort((a, b) => (b.wayland === active) - (a.wayland === active))
        wins = list
        index = list.length > 1 ? 1 : 0
        open = true
        keys.forceActiveFocus()
    }

    function activate(i) {
        const t = wins[i]
        open = false
        if (!t) return
        const addr = addressOf(t)
        if (t.workspace && t.workspace.id < 0) {
            const target = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
            Hyprland.dispatch("movetoworkspace " + target + ",address:" + addr)
        }
        Hyprland.dispatch("focuswindow address:" + addr)
        ensureDelay.restart()
    }

    function closeWindow(i) {
        const t = wins[i]
        if (!t) return
        Hyprland.dispatch("closewindow address:" + addressOf(t))
        const list = wins.slice()
        list.splice(i, 1)
        wins = list
        if (index >= list.length) index = Math.max(0, list.length - 1)
        if (list.length === 0) open = false
    }

    Process {
        id: ensureMax
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            id: eout
            onStreamFinished: {
                try {
                    const w = JSON.parse(eout.text)
                    if (w && w.address && !w.floating && w.fullscreen === 0 && w.workspace && w.workspace.id > 0)
                        Hyprland.dispatch("fullscreen 1")
                } catch (e) {}
            }
        }
    }

    Timer {
        id: ensureDelay
        interval: 150
        onTriggered: ensureMax.running = true
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: ov.open = false
        Keys.onLeftPressed: ov.index = Math.max(0, ov.index - 1)
        Keys.onRightPressed: ov.index = Math.min(ov.wins.length - 1, ov.index + 1)
        Keys.onTabPressed: ov.index = ov.wins.length > 0 ? (ov.index + 1) % ov.wins.length : 0
        Keys.onReturnPressed: ov.activate(ov.index)
        Keys.onEnterPressed: ov.activate(ov.index)

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: ov.open ? 0.72 : 0

            Behavior on opacity {
                NumberAnimation { duration: 220 }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: ov.open = false
            }
        }

        Item {
            id: content
            anchors.fill: parent
            opacity: ov.open ? 1 : 0
            scale: ov.open ? 1 : 0.92

            Behavior on opacity {
                NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height / 2 - 190
                spacing: 6

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "TASK VIEW  ·  " + ov.wins.length + (ov.wins.length === 1 ? " WINDOW" : " WINDOWS")
                    font.family: "JetBrains Mono"
                    font.pixelSize: 11
                    font.letterSpacing: 2
                    color: "#9a9a9a"
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "← →  choose     Enter  open     Esc  close"
                    font.family: "Inter"
                    font.pixelSize: 11
                    color: "#6e6e6e"
                }
            }

            Text {
                anchors.centerIn: parent
                visible: ov.wins.length === 0
                text: "No open windows"
                font.family: "Inter"
                font.pixelSize: 15
                color: "#8a8a8a"
            }

            ListView {
                id: row
                anchors.centerIn: parent
                width: Math.min(contentWidth, parent.width - 120)
                height: 270
                orientation: ListView.Horizontal
                spacing: 24
                clip: true
                model: ov.wins
                currentIndex: ov.index
                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: 0
                preferredHighlightEnd: width
                highlightMoveDuration: 200

                delegate: Item {
                    id: card
                    required property var modelData
                    required property int index
                    property bool selected: index === ov.index

                    width: 320
                    height: 270

                    HoverHandler {
                        id: cardHover
                        onHoveredChanged: if (hovered) ov.index = card.index
                    }

                    Rectangle {
                        id: frame
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 320
                        height: 210
                        radius: 14
                        color: "#141416"
                        border.color: card.selected ? "#ececec" : "#1fffffff"
                        border.width: card.selected ? 2 : 1
                        scale: card.selected ? 1.04 : 1
                        clip: true

                        Behavior on scale {
                            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                        }

                        ScreencopyView {
                            anchors.centerIn: parent
                            captureSource: card.modelData.wayland
                            live: ov.open
                            constraintSize: Qt.size(304, 194)
                        }

                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 8
                            width: 26
                            height: 26
                            radius: 13
                            visible: cardHover.hovered
                            color: closeArea.containsMouse ? "#ececec" : "#cc0a0a0b"

                            Rectangle { anchors.centerIn: parent; width: 11; height: 1.6; rotation: 45; color: closeArea.containsMouse ? "#0a0a0b" : "#ececec" }
                            Rectangle { anchors.centerIn: parent; width: 11; height: 1.6; rotation: -45; color: closeArea.containsMouse ? "#0a0a0b" : "#ececec" }

                            MouseArea {
                                id: closeArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: ov.closeWindow(card.index)
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            z: -1
                            onClicked: ov.activate(card.index)
                        }
                    }

                    Row {
                        anchors.top: frame.bottom
                        anchors.topMargin: 14
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8

                        IconImage {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 20
                            source: ov.iconOf(card.modelData)
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, 260)
                            elide: Text.ElideRight
                            text: ov.appNameOf(card.modelData)
                            font.family: "Inter"
                            font.pixelSize: 13
                            font.weight: card.selected ? Font.DemiBold : Font.Normal
                            color: card.selected ? "#ffffff" : "#b4b4b4"
                        }
                    }
                }
            }
        }
    }
}
