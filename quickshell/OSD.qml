import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

PanelWindow {
    id: osd

    property string label: "VOL"
    property real level: 0
    property bool shown: false

    function show(newLabel, newLevel) {
        label = newLabel
        level = Math.max(0, Math.min(1, newLevel))
        shown = true
        hideTimer.restart()
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "osd"
    exclusionMode: ExclusionMode.Ignore

    anchors {
        right: true
    }
    margins {
        right: 24
    }
    implicitWidth: 64
    implicitHeight: 230
    color: "transparent"
    visible: box.opacity > 0

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: osd.shown = false
    }

    PwObjectTracker {
        objects: [ Pipewire.defaultAudioSink ]
    }

    Connections {
        target: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null

        function onVolumeChanged() {
            osd.show("VOL", Pipewire.defaultAudioSink.audio.volume)
        }

        function onMutedChanged() {
            const audio = Pipewire.defaultAudioSink.audio
            osd.show(audio.muted ? "MUTE" : "VOL", audio.muted ? 0 : audio.volume)
        }
    }

    Process {
        id: brightnessReader
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            id: brightnessOutput
            onStreamFinished: {
                const parts = brightnessOutput.text.trim().split(",")
                osd.show("BRT", parseInt(parts[3]) / 100)
            }
        }
    }

    IpcHandler {
        target: "osd"

        function brightness(): void {
            brightnessReader.running = true
        }
    }

    Rectangle {
        id: box
        anchors.fill: parent
        radius: 18
        color: "#e00a0a0b"
        border.color: "#14ffffff"
        border.width: 1
        opacity: osd.shown ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 250 }
        }

        Column {
            anchors.centerIn: parent
            spacing: 12

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: osd.label
                font.family: "JetBrains Mono"
                font.pixelSize: 10
                font.letterSpacing: 1.5
                color: "#9a9a9a"
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 6
                height: 150
                radius: 3
                color: "#1fffffff"

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: parent.height * osd.level
                    radius: 3
                    color: "#ececec"

                    Behavior on height {
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Math.round(osd.level * 100)
                font.family: "JetBrains Mono"
                font.pixelSize: 12
                color: "#ececec"
            }
        }
    }
}
