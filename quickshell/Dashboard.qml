import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: dash
    required property var modelData
    screen: modelData

    property bool shown: false
    property bool busy: false
    visible: shown

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "dashboard"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"

    IpcHandler {
        target: "dashboard"
        function toggle(): void {
            if (dash.shown) {
                dash.shown = false
            } else {
                check.running = true
                dash.shown = true
            }
        }
    }

    onShownChanged: if (shown) keys.forceActiveFocus()

    Process {
        id: check
        command: ["hyprctl", "activeworkspace", "-j"]
        stdout: StdioCollector {
            id: checkOut
            onStreamFinished: {
                try { dash.busy = JSON.parse(checkOut.text).windows > 0 } catch (e) {}
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const watched = ["openwindow", "closewindow", "movewindow", "movewindowv2", "workspace", "workspacev2"]
            if (dash.shown && watched.includes(event.name)) check.running = true
        }
    }

    property real colWidth: (1136 - 48) / 4

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    property int hour: clock.date.getHours()
    property string greeting: hour < 12 ? "Good morning" : (hour < 17 ? "Good afternoon" : "Good evening")

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: dash.shown = false

        Rectangle {
            id: glass
            anchors.fill: parent
            color: "#000000"
            opacity: dash.busy ? 0.45 : 0

            Behavior on opacity {
                NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: dash.shown = false
            }
        }

        Item {
            id: content
            anchors.centerIn: parent
            width: 1136
            height: 660
            opacity: dash.shown ? 1 : 0
            scale: dash.shown ? 1 : 0.94

            Behavior on opacity {
                NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
            }

            Column {
                anchors.fill: parent
                spacing: 26

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 40

                    AnalogClock {
                        anchors.verticalCenter: parent.verticalCenter
                        date: clock.date
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Text {
                            text: Qt.formatTime(clock.date, "HH:mm")
                            font.family: "Inter"
                            font.pixelSize: 92
                            font.weight: Font.Medium
                            font.letterSpacing: -2
                            color: "#ececec"
                        }

                        Text {
                            text: Qt.formatDate(clock.date, "dddd, d MMMM")
                            font.family: "Inter"
                            font.pixelSize: 15
                            color: "#a6a6a6"
                        }

                        Text {
                            text: dash.greeting + ", Tanmay"
                            font.family: "Inter"
                            font.pixelSize: 13
                            color: "#8a8a8a"
                        }
                    }
                }

                GridLayout {
                    width: parent.width
                    columns: 4
                    rowSpacing: 16
                    columnSpacing: 16

                    MusicCard {
                        Layout.columnSpan: 2
                        Layout.preferredWidth: dash.colWidth * 2 + 16
                        Layout.preferredHeight: 222
                    }

                    CalendarCard {
                        Layout.preferredWidth: dash.colWidth
                        Layout.preferredHeight: 222
                    }

                    PlanCard {
                        Layout.rowSpan: 2
                        Layout.preferredWidth: dash.colWidth
                        Layout.preferredHeight: 222 + 16 + 196
                    }

                    StatsCard {
                        Layout.columnSpan: 2
                        Layout.preferredWidth: dash.colWidth * 2 + 16
                        Layout.preferredHeight: 196
                    }

                    TodoCard {
                        Layout.preferredWidth: dash.colWidth
                        Layout.preferredHeight: 196
                    }
                }
            }
        }
    }
}
