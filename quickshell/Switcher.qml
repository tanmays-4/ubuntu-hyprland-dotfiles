import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick

PanelWindow {
    id: sw

    property bool open: false
    property var wins: []
    property int index: 0
    property int pending: 0
    property bool commitPending: false

    visible: open && wins.length > 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "switcher"
    exclusionMode: ExclusionMode.Ignore

    implicitWidth: Math.min(Math.max(240, wins.length * 148 + 28), 1100)
    implicitHeight: 176
    color: "transparent"

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
                const cur = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
                list = list.filter(c => c.mapped && c.address && c.workspace && (c.workspace.id === cur || c.workspace.id < 0))
                list.sort((a, b) => a.focusHistoryID - b.focusHistoryID)
                sw.wins = list
                if (list.length === 0) {
                    sw.open = false
                    return
                }
                sw.index = ((sw.pending % list.length) + list.length) % list.length
                if (sw.commitPending) sw.commit()
            }
        }
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
        id: ensureMax_delay
        interval: 150
        onTriggered: ensureMax.running = true
    }    
    function step(d) {
        if (!open) {
            open = true
            commitPending = false
            wins = []
            pending = d
            clients.running = true
        } else if (wins.length > 0) {
            index = (index + d + wins.length) % wins.length
        } else {
            pending += d
        }
    }

    function commit() {
        if (!open) return
        if (wins.length === 0) {
            commitPending = true
            return
        }
        const w = wins[index]
        open = false
        commitPending = false
        if (!w) return
        if (w.workspace && w.workspace.id < 0) {
            const target = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
            Hyprland.dispatch("movetoworkspace " + target + ",address:" + w.address)
        }
        Hyprland.dispatch("focuswindow address:" + w.address)
        ensureMax_delay.restart()
    }

    IpcHandler {
        target: "switcher"
        function next(): void { sw.step(1) }
        function prev(): void { sw.step(-1) }
        function commit(): void { sw.commit() }
    }

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: "#f20a0a0b"
        border.color: "#14ffffff"
        border.width: 1

        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: 14
            orientation: ListView.Horizontal
            spacing: 4
            clip: true
            model: sw.wins
            currentIndex: sw.index
            highlightMoveDuration: 120

            delegate: Rectangle {
                id: item
                required property var modelData
                required property int index
                property bool selected: index === sw.index
                width: 144
                height: list.height
                radius: 14
                color: selected ? "#1fffffff" : "transparent"
                border.color: selected ? "#40ffffff" : "transparent"
                border.width: 1

                Column {
                    anchors.centerIn: parent
                    width: parent.width - 20
                    spacing: 8

                    IconImage {
                        anchors.horizontalCenter: parent.horizontalCenter
                        implicitSize: 52
                        source: sw.iconFor(item.modelData.class)
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: sw.nameFor(item.modelData.class, item.modelData.title)
                        font.family: "Inter"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: "#ececec"
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: item.modelData.title
                        font.family: "Inter"
                        font.pixelSize: 10
                        color: "#8a8a8a"
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        sw.index = item.index
                        sw.commit()
                    }
                }
            }
        }
    }
}
