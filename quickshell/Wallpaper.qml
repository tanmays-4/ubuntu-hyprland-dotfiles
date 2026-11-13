import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

PanelWindow {
    id: wall
    required property var modelData
    screen: modelData

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "wallpaper"
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "black"

    property string home: Quickshell.env("HOME")
    property bool busy: false

    Process {
        id: check
        command: ["hyprctl", "activeworkspace", "-j"]
        stdout: StdioCollector {
            id: out
            onStreamFinished: {
                try { wall.busy = JSON.parse(out.text).windows > 0 } catch (e) {}
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const watched = ["openwindow", "closewindow", "movewindow", "movewindowv2",
                             "workspace", "workspacev2", "focusedmon", "activespecial"]
            if (watched.includes(event.name)) check.running = true
        }
    }

    Component.onCompleted: check.running = true

    Image {
        anchors.fill: parent
        source: "file://" + wall.home + "/Pictures/Wallpapers/flower.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    Image {
        anchors.fill: parent
        source: "file://" + wall.home + "/.cache/wallpaper/flower-blur.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        opacity: wall.busy ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 450; easing.type: Easing.OutCubic }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: wall.busy ? 0.3 : 0

        Behavior on opacity {
            NumberAnimation { duration: 450; easing.type: Easing.OutCubic }
        }
    }
}
