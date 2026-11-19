import Quickshell
import Quickshell.Hyprland
import QtQuick

Card {
    id: card
    title: "TO DO"

    property string tab: "myday"               // myday | missed
    property var vdata: TodoStore.viewData(tab)
    property var rows: (vdata.groups.length ? vdata.groups[0].rows : []).concat(tab === "myday" ? vdata.completed : [])
    property var preview: TodoStore.parseTask(input.text || "")

    function openApp(view) {
        Hyprland.dispatch("exec qs ipc call dashboard toggle; qs ipc call todo show " + view)
    }

    // tabs + open button
    Row {
        x: card.width - width - 16
        y: 14
        spacing: 4

        Repeater {
            model: [
                { v: "myday",  label: "TODAY" },
                { v: "missed", label: "MISSED" }
            ]
            Rectangle {
                id: tab
                required property var modelData
                property int count: TodoStore.countFor(modelData.v)
                property bool on: card.tab === modelData.v
                width: tabText.implicitWidth + 12
                height: 20
                radius: 10
                color: on ? "#ececec" : (tabArea.containsMouse ? "#1affffff" : "transparent")
                border.color: "#1fffffff"
                border.width: on ? 0 : 1
                Text {
                    id: tabText
                    anchors.centerIn: parent
                    text: tab.modelData.label + (tab.count > 0 ? " " + tab.count : "")
                    font.family: "JetBrains Mono"
                    font.pixelSize: 8
                    font.letterSpacing: 0.6
                    color: tab.on ? "#0a0a0b" : (tab.modelData.v === "missed" && tab.count > 0 ? "#f87171" : "#9a9a9a")
                }
                MouseArea {
                    id: tabArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: card.tab = tab.modelData.v
                }
            }
        }

        Rectangle {
            width: 26
            height: 20
            radius: 10
            color: openArea.containsMouse ? "#ececec" : "transparent"
            border.color: "#1fffffff"
            border.width: openArea.containsMouse ? 0 : 1
            Text {
                anchors.centerIn: parent
                text: "↗"
                font.pixelSize: 11
                color: openArea.containsMouse ? "#0a0a0b" : "#9a9a9a"
            }
            MouseArea {
                id: openArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: card.openApp(card.tab)
            }
        }
    }

    // list
    ListView {
        id: list
        x: 16
        y: 46
        width: card.width - 32
        height: card.height - 46 - 50
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        model: card.rows

        delegate: Rectangle {
            id: row
            required property var modelData
            width: list.width
            height: 26
            radius: 7
            color: rowHover.hovered ? "#0fffffff" : "transparent"
            HoverHandler { id: rowHover }

            Rectangle {
                id: check
                x: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                radius: 7
                color: row.modelData.done ? "#ececec" : "transparent"
                border.color: row.modelData.done ? "#ececec" : "#6e6e6e"
                border.width: 1.2
                Text {
                    anchors.centerIn: parent
                    visible: row.modelData.done
                    text: "✓"
                    font.pixelSize: 9
                    color: "#0a0a0b"
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    onClicked: TodoStore.toggle(row.modelData.id)
                }
            }

            Text {
                anchors.left: check.right
                anchors.leftMargin: 8
                anchors.right: side.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: (row.modelData.important ? "★ " : "") + row.modelData.text
                font.family: "Inter"
                font.pixelSize: 11
                font.strikeout: row.modelData.done
                color: row.modelData.done ? "#6e6e6e" : "#dcdcdc"
            }

            Row {
                id: side
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Text {
                    visible: !(card.tab === "missed" && rowHover.hovered)
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.isRep ? "↻"
                        : (card.tab === "missed" ? TodoStore.dueLabel(row.modelData.due) : "")
                    font.family: "JetBrains Mono"
                    font.pixelSize: 8
                    color: card.tab === "missed" ? "#f87171" : "#8a8a8a"
                }
                Text {
                    visible: card.tab === "missed" && rowHover.hovered
                    anchors.verticalCenter: parent.verticalCenter
                    text: "→ today"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 8
                    color: "#dcdcdc"
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        onClicked: TodoStore.setDue(row.modelData.id, TodoStore.today)
                    }
                }
            }
        }
    }

    Text {
        visible: card.rows.length === 0
        anchors.horizontalCenter: list.horizontalCenter
        y: list.y + list.height / 2 - height / 2
        text: card.tab === "myday" ? "Nothing due today" : "Nothing missed  ✓"
        font.family: "Inter"
        font.pixelSize: 11
        color: "#5c5c5c"
    }

    // quick add
    Item {
        x: 16
        y: card.height - 44
        width: card.width - 32
        height: 30

        Field {
            id: input
            width: parent.width - chip.width - 6
            hint: "Quick add · 'tmrw', 'daily'"
            onSubmitted: {
                TodoStore.addTask(input.text, { myDay: true, defaultDue: TodoStore.today })
                input.text = ""
            }
        }
        Rectangle {
            id: chip
            property bool hit: card.preview.found || card.preview.repeat !== null
            anchors.right: parent.right
            anchors.verticalCenter: input.verticalCenter
            width: chipText.implicitWidth + 14
            height: 22
            radius: 11
            color: hit ? "#ececec" : "#14ffffff"
            Text {
                id: chipText
                anchors.centerIn: parent
                text: card.preview.repeat ? "↻ " + TodoStore.repeatLabel(card.preview.repeat)
                                          : TodoStore.dueLabel(card.preview.due)
                font.family: "JetBrains Mono"
                font.pixelSize: 8
                color: chip.hit ? "#0a0a0b" : "#8a8a8a"
            }
        }
    }
}
