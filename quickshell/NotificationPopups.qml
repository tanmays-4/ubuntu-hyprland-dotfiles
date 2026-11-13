import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick

PanelWindow {
    id: root

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "notifications"
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        right: true
    }
    margins {
        top: 62
        right: 12
    }
    implicitWidth: 360
    implicitHeight: Math.max(1, stack.implicitHeight)
    color: "transparent"
    visible: server.trackedNotifications.values.length > 0

    NotificationServer {
        id: server
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        keepOnReload: false

        onNotification: n => {
            n.tracked = true
        }
    }

    Column {
        id: stack
        width: parent.width
        spacing: 10

        Repeater {
            model: server.trackedNotifications

            Rectangle {
                id: card
                required property var modelData

                width: stack.width
                height: content.implicitHeight + 28
                radius: 14
                color: "#e60a0a0b"
                border.color: "#14ffffff"
                border.width: 1
                opacity: 0

                Component.onCompleted: opacity = 1

                Behavior on opacity {
                    NumberAnimation { duration: 200 }
                }

                Timer {
                    interval: 6000
                    running: card.modelData.urgency !== NotificationUrgency.Critical
                    onTriggered: card.modelData.expire()
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: card.modelData.dismiss()
                }

                Column {
                    id: content
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 14
                    spacing: 4

                    Text {
                        text: (card.modelData.appName || "NOTIFICATION").toUpperCase()
                        font.family: "JetBrains Mono"
                        font.pixelSize: 9
                        font.letterSpacing: 1.5
                        color: "#7c7c7c"
                    }

                    Text {
                        width: parent.width
                        text: card.modelData.summary
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        font.family: "Inter"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: "#ececec"
                    }

                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: card.modelData.body
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        font.family: "Inter"
                        font.pixelSize: 12
                        color: "#9a9a9a"
                    }

                    Row {
                        visible: card.modelData.actions.length > 0
                        topPadding: 6
                        spacing: 8

                        Repeater {
                            model: card.modelData.actions

                            Rectangle {
                                required property var modelData
                                width: label.implicitWidth + 20
                                height: 26
                                radius: 8
                                color: actionArea.containsMouse ? "#2affffff" : "#14ffffff"

                                Text {
                                    id: label
                                    anchors.centerIn: parent
                                    text: parent.modelData.text
                                    font.family: "Inter"
                                    font.pixelSize: 11
                                    color: "#ececec"
                                }

                                MouseArea {
                                    id: actionArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: parent.modelData.invoke()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
