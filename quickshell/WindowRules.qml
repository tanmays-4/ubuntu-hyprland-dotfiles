import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Scope {
    id: rules
    property string snap: Quickshell.env("HOME") + "/.config/quickshell/scripts/snap.py"

    Process {
        id: activeWin
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            id: aout
            onStreamFinished: {
                let w = null
                try { w = JSON.parse(aout.text) } catch (e) { return }
                if (!w || !w.address || !w.workspace || w.workspace.id < 0) return

                if (!w.floating && w.fullscreen === 0) {
                    // a new (tiled) app: make it a maximised floating window
                    Quickshell.execDetached(["python3", rules.snap, "fill", w.address])
                } else if (w.floating) {
                    // switching apps: just bring the focused one to the front
                    Hyprland.dispatch("alterzorder top,address:" + w.address)
                }
            }
        }
    }

    Timer {
        id: delay
        interval: 120
        onTriggered: activeWin.running = true
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "openwindow" || event.name === "activewindowv2") delay.restart()
        }
    }
}
