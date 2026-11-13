import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

PanelWindow {
    id: grid

    property bool open: false
    visible: open

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "appgrid"
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
        target: "launcher"
        function toggle(): void { grid.open = !grid.open }
    }

    onOpenChanged: {
        if (open) {
            search.text = ""
            search.forceActiveFocus()
            view.positionViewAtBeginning()
        }
    }

    property var apps: DesktopEntries.applications.values
        .filter(a => !a.noDisplay)
        .slice()
        .sort((a, b) => a.name.localeCompare(b.name))

    property var filtered: {
        const q = search.text.toLowerCase().trim()
        if (q === "") return apps
        return apps.filter(a => {
            const hay = [a.name, a.genericName || "", (a.keywords || []).join(" ")].join(" ").toLowerCase()
            return hay.includes(q)
        })
    }

    function launch(app) {
        app.execute()
        open = false
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"

        MouseArea {
            anchors.fill: parent
            onClicked: grid.open = false
        }
    }

    Item {
        id: content
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(grid.width - 160, 1040)
        height: grid.height
        opacity: grid.open ? 1 : 0
        y: grid.open ? 0 : -16

        Behavior on opacity {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }

        Rectangle {
            id: searchPill
            anchors.horizontalCenter: parent.horizontalCenter
            y: 84
            width: 480
            height: 46
            radius: 23
            color: "#0f0f11"
            border.color: search.activeFocus ? "#33ffffff" : "#1affffff"
            border.width: 1

            Canvas {
                id: searchIcon
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                onPaint: {
                    const c = getContext("2d")
                    c.reset()
                    c.strokeStyle = "#8a8a8a"
                    c.lineWidth = 1.8
                    c.lineCap = "round"
                    c.beginPath(); c.arc(7, 7, 5.2, 0, 2 * Math.PI); c.stroke()
                    c.beginPath(); c.moveTo(11, 11); c.lineTo(15, 15); c.stroke()
                }
            }

            TextInput {
                id: search
                anchors.left: searchIcon.right
                anchors.leftMargin: 12
                anchors.right: countText.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                color: "#ececec"
                selectionColor: "#40ffffff"
                font.family: "Inter"
                font.pixelSize: 14
                clip: true

                Keys.onEscapePressed: grid.open = false
                Keys.onReturnPressed: if (grid.filtered.length > 0) grid.launch(grid.filtered[0])
            }

            Text {
                anchors.left: search.left
                anchors.verticalCenter: parent.verticalCenter
                visible: search.text === ""
                text: "Search apps"
                font.family: "Inter"
                font.pixelSize: 14
                color: "#5e5e5e"
            }

            Text {
                id: countText
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                text: grid.filtered.length + (grid.filtered.length === 1 ? " app" : " apps")
                font.family: "Inter"
                font.pixelSize: 11
                color: "#5e5e5e"
            }
        }

        GridView {
            id: view
            anchors.top: searchPill.bottom
            anchors.topMargin: 36
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            height: grid.height - 84 - 46 - 36 - 48
            clip: true
            model: grid.filtered
            cellWidth: width / Math.max(1, Math.floor(width / 136))
            cellHeight: 132

            delegate: Item {
                id: cell
                required property var modelData
                width: view.cellWidth
                height: view.cellHeight

                Rectangle {
                    anchors.centerIn: parent
                    width: 118
                    height: 118
                    radius: 22
                    color: cellArea.containsMouse ? "#14ffffff" : "transparent"
                    border.color: cellArea.containsMouse ? "#1affffff" : "transparent"
                    border.width: 1
                    scale: cellArea.pressed ? 0.95 : 1

                    Behavior on scale {
                        NumberAnimation { duration: 100 }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 10

                    IconImage {
                        anchors.horizontalCenter: parent.horizontalCenter
                        implicitSize: 54
                        source: Quickshell.iconPath(cell.modelData.icon, "application-x-executable")
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 104
                        horizontalAlignment: Text.AlignHCenter
                        text: cell.modelData.name
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        font.family: "Inter"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: "#cfcfcf"
                    }
                }

                MouseArea {
                    id: cellArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: grid.launch(cell.modelData)
                }
            }
        }
    }
}
