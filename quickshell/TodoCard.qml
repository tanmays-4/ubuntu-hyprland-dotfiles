import Quickshell
import Quickshell.Io
import QtQuick

Card {
    id: todo
    title: "TO-DO"

    property var items: []

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.local/share/dashboard/todo.json"
        onLoaded: {
            try { todo.items = JSON.parse(file.text()) } catch (e) { todo.items = [] }
        }
        onLoadFailed: todo.items = []
    }

    function save() {
        file.setText(JSON.stringify(items, null, 2))
    }

    function add(text) {
        if (text.trim() === "") return
        items = items.concat([{ text: text.trim(), done: false }])
        save()
    }

    function toggle(i) {
        const list = items.slice()
        list[i] = { text: list[i].text, done: !list[i].done }
        items = list
        save()
    }

    function remove(i) {
        const list = items.slice()
        list.splice(i, 1)
        items = list
        save()
    }

    Text {
        x: 18
        y: 44
        visible: todo.items.length === 0
        text: "No tasks yet"
        font.family: "Inter"
        font.pixelSize: 12
        color: "#6e6e6e"
    }

    ListView {
        id: list
        x: 18
        y: 42
        width: todo.width - 36
        height: todo.height - 42 - 52
        clip: true
        spacing: 6
        model: todo.items

        delegate: Item {
            id: row
            required property var modelData
            required property int index
            width: list.width
            height: 22

            HoverHandler { id: rowHover }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 15
                height: 15
                radius: 4
                color: row.modelData.done ? "#d8d8d8" : "transparent"
                border.color: row.modelData.done ? "#d8d8d8" : "#66ffffff"
                border.width: 1.5

                Rectangle {
                    visible: row.modelData.done
                    anchors.centerIn: parent
                    width: 7
                    height: 7
                    radius: 2
                    color: "#0a0a0b"
                }
            }

            Text {
                x: 25
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 50
                elide: Text.ElideRight
                text: row.modelData.text
                font.family: "Inter"
                font.pixelSize: 12
                font.strikeout: row.modelData.done
                color: row.modelData.done ? "#7c7c7c" : "#e2e2e2"
            }

            MouseArea {
                anchors.fill: parent
                anchors.rightMargin: 24
                onClicked: todo.toggle(row.index)
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: rowHover.hovered
                text: "×"
                font.family: "Inter"
                font.pixelSize: 14
                color: delArea.containsMouse ? "#ffffff" : "#9a9a9a"

                MouseArea {
                    id: delArea
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    onClicked: todo.remove(row.index)
                }
            }
        }
    }

    Field {
        id: newTask
        x: 18
        y: todo.height - 46
        width: todo.width - 36
        hint: "Add a task…"
        onSubmitted: {
            todo.add(newTask.text)
            newTask.text = ""
        }
    }
}
