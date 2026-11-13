import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Scope {
    Process {
        id: activeWin
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            id: aout
            onStreamFinished: {
                try {
                    const w = JSON.parse(aout.text)
                    if (w && w.address && !w.floating && w.fullscreen === 0 && w.workspace && w.workspace.id > 0)
                        Hyprland.dispatch("fullscreen 1")
                } catch (e) {}
            }
        }
    }

    Timer {
        id: delay
        interval: 150
        onTriggered: activeWin.running = true
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "openwindow" || event.name === "activewindowv2") delay.restart()
        }
    }
}
