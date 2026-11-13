import Quickshell
import Quickshell.Io
import QtQuick

Card {
    id: plan
    title: "TODAY"

    property int startHour: 9
    property int endHour: 21
    property var store: ({})
    property bool adding: false
    property string error: ""

    SystemClock {
        id: clk
        precision: SystemClock.Minutes
    }

    property real now: clk.date.getHours() + clk.date.getMinutes() / 60
    property string dayKey: Qt.formatDate(clk.date, "yyyy-MM-dd")
    property var slots: store[dayKey] ? store[dayKey] : []

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.local/share/dashboard/plan.json"
        onLoaded: {
            try { plan.store = JSON.parse(file.text()) } catch (e) { plan.store = {} }
        }
        onLoadFailed: plan.store = {}
    }

    function save() {
        file.setText(JSON.stringify(store, null, 2))
    }

    function parseTime(t) {
        const m = /^(\d{1,2}):(\d{2})$/.exec(t.trim())
        if (!m) return -1
        const h = Number(m[1])
        const mi = Number(m[2])
        if (h > 23 || mi > 59) return -1
        return h + mi / 60
    }

    function fmt(h) {
        const hh = Math.floor(h)
        const mm = Math.round((h - hh) * 60)
        return String(hh).padStart(2, "0") + ":" + String(mm).padStart(2, "0")
    }

    function setSlots(list) {
        const d = Object.assign({}, store)
        d[dayKey] = list
        store = d
        save()
    }

    function addSlot(title, s, e) {
        const a = parseTime(s)
        const b = parseTime(e)
        if (title.trim() === "") { error = "Give the slot a name"; return false }
        if (a < 0 || b < 0) { error = "Use HH:MM, e.g. 14:30"; return false }
        if (b <= a) { error = "End must be after start"; return false }
        const list = slots.slice()
        list.push({ title: title.trim(), start: a, end: b })
        list.sort((x, y) => x.start - y.start)
        setSlots(list)
        error = ""
        return true
    }

    function removeSlot(i) {
        const list = slots.slice()
        list.splice(i, 1)
        setSlots(list)
    }

    function openForm() {
        titleField.text = ""
        startField.text = fmt(Math.floor(now))
        endField.text = fmt(Math.min(23, Math.floor(now) + 1))
        error = ""
        adding = true
        titleField.editor.forceActiveFocus()
    }

    function submit() {
        if (addSlot(titleField.text, startField.text, endField.text)) adding = false
    }

    Rectangle {
        x: plan.width - 44
        y: 12
        width: 26
        height: 26
        radius: 7
        color: addArea.containsMouse ? "#24ffffff" : "transparent"
        border.color: "#1fffffff"
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: plan.adding ? "×" : "+"
            font.family: "Inter"
            font.pixelSize: 15
            color: "#ececec"
        }

        MouseArea {
            id: addArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: plan.adding ? plan.adding = false : plan.openForm()
        }
    }

    Item {
        id: timeline
        x: 18
        y: 50
        width: plan.width - 36
        height: plan.height - 50 - 16

        property real pxh: height / (plan.endHour - plan.startHour)

        Repeater {
            model: plan.endHour - plan.startHour + 1

            Item {
                required property int index
                y: index * timeline.pxh
                width: timeline.width
                height: 1

                Text {
                    y: -6
                    text: String(plan.startHour + index).padStart(2, "0") + ":00"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 9
                    color: "#6e6e6e"
                }

                Rectangle {
                    x: 40
                    width: parent.width - 40
                    height: 1
                    color: "#0dffffff"
                }
            }
        }

        Repeater {
            model: plan.slots

            Rectangle {
                id: slot
                required property var modelData
                required property int index
                property real s: Math.max(plan.startHour, modelData.start)
                property real e: Math.min(plan.endHour, modelData.end)
                property bool active: plan.now >= modelData.start && plan.now < modelData.end
                property bool past: plan.now >= modelData.end

                visible: e > s
                x: 44
                y: (s - plan.startHour) * timeline.pxh + 1
                width: timeline.width - 44
                height: Math.max(14, (e - s) * timeline.pxh - 2)
                radius: 7
                color: active ? "#24ffffff" : "#0bffffff"
                border.color: active ? "#59ffffff" : "#12ffffff"
                border.width: 1
                clip: true

                HoverHandler { id: slotHover }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.rightMargin: 24
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: slot.modelData.title
                        font.family: "Inter"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: slot.past ? "#8a8a8a" : "#ececec"
                    }

                    Text {
                        visible: slot.height >= 30
                        text: plan.fmt(slot.modelData.start) + " – " + plan.fmt(slot.modelData.end)
                        font.family: "JetBrains Mono"
                        font.pixelSize: 9
                        color: slot.past ? "#6e6e6e" : "#9a9a9a"
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    visible: slotHover.hovered
                    text: "×"
                    font.family: "Inter"
                    font.pixelSize: 14
                    color: delArea.containsMouse ? "#ffffff" : "#9a9a9a"

                    MouseArea {
                        id: delArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        onClicked: plan.removeSlot(slot.index)
                    }
                }
            }
        }

        Item {
            visible: plan.now >= plan.startHour && plan.now <= plan.endHour
            y: (plan.now - plan.startHour) * timeline.pxh - 3
            x: 36
            width: timeline.width - 36
            height: 7

            Rectangle {
                width: 7
                height: 7
                radius: 3.5
                color: "#ffffff"
            }

            Rectangle {
                x: 6
                y: 3
                width: parent.width - 6
                height: 1
                color: "#ffffff"
            }
        }

        Rectangle {
            visible: plan.adding
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: form.implicitHeight + 24
            radius: 12
            color: "#f50c0c0d"
            border.color: "#24ffffff"
            border.width: 1

            MouseArea { anchors.fill: parent }

            Column {
                id: form
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 8

                Text {
                    text: "NEW SLOT"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 9
                    font.letterSpacing: 1.6
                    color: "#8a8a8a"
                }

                Field {
                    id: titleField
                    width: parent.width
                    hint: "What are you doing?"
                    onSubmitted: plan.submit()
                }

                Row {
                    width: parent.width
                    spacing: 8

                    Field {
                        id: startField
                        width: (parent.width - 8) / 2
                        hint: "Start 14:00"
                        onSubmitted: plan.submit()
                    }

                    Field {
                        id: endField
                        width: (parent.width - 8) / 2
                        hint: "End 15:00"
                        onSubmitted: plan.submit()
                    }
                }

                Text {
                    visible: plan.error !== ""
                    text: plan.error
                    font.family: "Inter"
                    font.pixelSize: 11
                    color: "#b4b4b4"
                }

                Rectangle {
                    width: parent.width
                    height: 30
                    radius: 8
                    color: saveArea.containsMouse ? "#ffffff" : "#ececec"

                    Text {
                        anchors.centerIn: parent
                        text: "Add slot"
                        font.family: "Inter"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: "#0a0a0b"
                    }

                    MouseArea {
                        id: saveArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: plan.submit()
                    }
                }
            }
        }
    }
}
