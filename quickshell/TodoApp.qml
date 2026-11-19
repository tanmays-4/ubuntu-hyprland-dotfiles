import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: app

    property bool open: false
    property string viewId: "myday"
    property string selectedId: ""
    property bool showCompleted: true
    property bool addingList: false
    property bool confirmDelete: false
    property bool confirmList: false
    property bool loadingDetails: false
    property string noteTarget: ""

    readonly property var smartViews: ["myday", "important", "planned", "missed", "repeat"]
    readonly property bool isSmart: smartViews.indexOf(viewId) !== -1
    readonly property var vdata: TodoStore.viewData(viewId)
    readonly property var sel: selectedId === "" ? null : (TodoStore.decorated.find(it => it.id === selectedId) || null)
    property var preview: TodoStore.parseTask(addField.text || "")

    visible: open
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "todo"
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
        target: "todo"
        function toggle(): void { app.open = !app.open }
        function show(view: string): void {
            app.viewId = view
            app.open = true
        }
    }

    onOpenChanged: if (open) Qt.callLater(() => addField.editor.forceActiveFocus())
    onSelectedIdChanged: {
        confirmDelete = false
        loadDetails()
    }
    onViewIdChanged: {
        selectedId = ""
        confirmList = false
    }

    function viewTitle() {
        switch (viewId) {
        case "myday": return "My Day"
        case "important": return "Important"
        case "planned": return "Planned"
        case "missed": return "Missed"
        case "repeat": return "Repeating"
        }
        return TodoStore.listName(viewId)
    }

    function ctx() {
        const t = TodoStore.today
        if (viewId === "myday" || viewId === "missed") return { myDay: true, defaultDue: t }
        if (viewId === "important") return { important: true }
        if (viewId === "planned") return { defaultDue: t }
        if (viewId === "repeat") return { repeat: [0, 1, 2, 3, 4, 5, 6] }
        return { list: viewId }
    }

    function meta(t) {
        const parts = []
        if (isSmart && t.list !== "tasks") parts.push(TodoStore.listName(t.list))
        if (t.myDay === TodoStore.today && viewId !== "myday") parts.push("☀ My Day")
        if (t.isRep) parts.push("↻ " + TodoStore.repeatLabel(t.repeat))
        else if (t.due) parts.push((t.due < TodoStore.today && !t.done ? "Missed · " : "") + "Due " + TodoStore.dueLabel(t.due))
        if (t.steps && t.steps.length) parts.push(t.steps.filter(s => s.done).length + " of " + t.steps.length)
        if (t.note) parts.push("✎ Note")
        return parts.join("   ·   ")
    }

    function loadDetails() {
        if (noteTimer.running) {
            noteTimer.stop()
            TodoStore.setNote(noteTarget, noteEdit.text)
        }
        const s = TodoStore.decorated.find(it => it.id === selectedId)
        if (!s) return
        loadingDetails = true
        titleField.text = s.text
        noteEdit.text = s.note || ""
        stepField.text = ""
        dueField.text = ""
        repeatField.text = ""
        loadingDetails = false
    }

    Timer {
        id: noteTimer
        interval: 400
        onTriggered: TodoStore.setNote(app.noteTarget, noteEdit.text)
    }

    // ================= reusable pieces =================
    component PillButton: Rectangle {
        id: pb
        property string label: ""
        property bool on: false
        property bool danger: false
        signal clicked()
        width: pbText.implicitWidth + 22
        height: 26
        radius: 13
        color: on ? "#ececec" : (pbArea.containsMouse ? "#24ffffff" : "#12ffffff")
        border.color: danger ? "#66f87171" : "transparent"
        border.width: 1
        Text {
            id: pbText
            anchors.centerIn: parent
            text: pb.label
            font.family: "Inter"
            font.pixelSize: 11
            color: pb.on ? "#0a0a0b" : (pb.danger ? "#f87171" : "#dcdcdc")
        }
        MouseArea {
            id: pbArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pb.clicked()
        }
    }

    component SideItem: Rectangle {
        id: si
        property string icon: ""
        property string label: ""
        property int count: 0
        property bool active: false
        property bool alert: false
        signal picked()
        width: 216
        height: 36
        radius: 8
        color: active ? "#1fffffff" : (siArea.containsMouse ? "#0fffffff" : "transparent")
        Text {
            x: 10
            width: 22
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
            text: si.icon
            font.pixelSize: 14
            color: si.alert && si.count > 0 ? "#f87171" : "#bdbdbd"
        }
        Text {
            x: 42
            anchors.verticalCenter: parent.verticalCenter
            text: si.label
            font.family: "Inter"
            font.pixelSize: 13
            font.weight: si.active ? Font.DemiBold : Font.Normal
            color: si.active ? "#ffffff" : "#dcdcdc"
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: si.count > 0 ? si.count : ""
            font.family: "JetBrains Mono"
            font.pixelSize: 10
            color: si.alert ? "#f87171" : "#7c7c7c"
        }
        MouseArea {
            id: siArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: si.picked()
        }
    }

    component TaskRow: Rectangle {
        id: tr
        property var task: ({})
        property bool selected: false
        property string metaText: ""
        signal picked()
        property bool overdue: !task.isRep && !task.done && !!task.due && task.due < TodoStore.today
        height: 54
        radius: 10
        color: selected ? "#29ffffff" : (trHover.hovered ? "#1cffffff" : "#12ffffff")

        HoverHandler { id: trHover }
        MouseArea {
            anchors.fill: parent
            onClicked: tr.picked()
        }

        Rectangle {
            id: circ
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18
            radius: 9
            color: tr.task.done ? "#ececec" : (circArea.containsMouse ? "#24ffffff" : "transparent")
            border.color: tr.task.done ? "#ececec" : "#8a8a8a"
            border.width: 1.5
            Text {
                anchors.centerIn: parent
                visible: tr.task.done || circArea.containsMouse
                text: "✓"
                font.pixelSize: 11
                color: tr.task.done ? "#0a0a0b" : "#bdbdbd"
            }
            MouseArea {
                id: circArea
                anchors.fill: parent
                anchors.margins: -5
                hoverEnabled: true
                onClicked: TodoStore.toggle(tr.task.id)
            }
        }

        Column {
            anchors.left: circ.right
            anchors.leftMargin: 14
            anchors.right: star.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: tr.task.text || ""
                font.family: "Inter"
                font.pixelSize: 13
                font.strikeout: !!tr.task.done
                color: tr.task.done ? "#7c7c7c" : "#f0f0f0"
            }
            Text {
                width: parent.width
                visible: tr.metaText !== ""
                elide: Text.ElideRight
                text: tr.metaText
                font.family: "Inter"
                font.pixelSize: 10
                color: tr.overdue ? "#f87171" : "#8a8a8a"
            }
        }

        Text {
            id: star
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            text: tr.task.important ? "★" : "☆"
            font.pixelSize: 16
            color: tr.task.important ? "#ececec" : "#6e6e6e"
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                onClicked: TodoStore.toggleImportant(tr.task.id)
            }
        }
    }

    // ================= window =================
    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: {
            if (app.selectedId !== "") app.selectedId = ""
            else app.open = false
        }

        Rectangle {
            anchors.fill: parent
            color: "#99000000"
            opacity: app.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
            MouseArea {
                anchors.fill: parent
                onClicked: app.open = false
            }
        }

        Rectangle {
            id: win
            anchors.centerIn: parent
            width: Math.min(1100, parent.width - 80)
            height: Math.min(700, parent.height - 80)
            radius: 20
            color: "#f20b0b0d"
            border.color: "#1affffff"
            border.width: 1
            clip: true
            scale: app.open ? 1 : 0.96
            opacity: app.open ? 1 : 0
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 160 } }

            MouseArea { anchors.fill: parent }

            // ---------- sidebar ----------
            Rectangle {
                id: side
                width: 232
                height: parent.height
                color: "#08ffffff"

                Column {
                    x: 8
                    y: 18
                    width: parent.width - 16
                    spacing: 2

                    Text {
                        leftPadding: 12
                        bottomPadding: 14
                        text: "To Do"
                        font.family: "Inter"
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                        color: "#ffffff"
                    }

                    Repeater {
                        model: [
                            { v: "myday",     icon: "☀", label: "My Day" },
                            { v: "important", icon: "☆", label: "Important" },
                            { v: "planned",   icon: "▦", label: "Planned" },
                            { v: "missed",    icon: "!", label: "Missed" },
                            { v: "repeat",    icon: "↻", label: "Repeating" }
                        ]
                        SideItem {
                            required property var modelData
                            icon: modelData.icon
                            label: modelData.label
                            count: TodoStore.countFor(modelData.v)
                            active: app.viewId === modelData.v
                            alert: modelData.v === "missed"
                            onPicked: app.viewId = modelData.v
                        }
                    }

                    Rectangle {
                        width: 200
                        height: 1
                        x: 8
                        color: "#14ffffff"
                    }
                    Item { width: 1; height: 6 }

                    Repeater {
                        model: TodoStore.lists
                        SideItem {
                            required property var modelData
                            icon: "≡"
                            label: modelData.name
                            count: TodoStore.countFor(modelData.id)
                            active: app.viewId === modelData.id
                            onPicked: app.viewId = modelData.id
                        }
                    }

                    Rectangle {
                        visible: !app.addingList
                        width: 216
                        height: 36
                        radius: 8
                        color: nlArea.containsMouse ? "#0fffffff" : "transparent"
                        Text {
                            x: 16
                            anchors.verticalCenter: parent.verticalCenter
                            text: "+   New list"
                            font.family: "Inter"
                            font.pixelSize: 13
                            color: "#9a9a9a"
                        }
                        MouseArea {
                            id: nlArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                app.addingList = true
                                Qt.callLater(() => newListField.editor.forceActiveFocus())
                            }
                        }
                    }

                    Field {
                        id: newListField
                        visible: app.addingList
                        width: 216
                        hint: "List name, then Enter"
                        onSubmitted: {
                            const id = TodoStore.addList(newListField.text)
                            newListField.text = ""
                            app.addingList = false
                            if (id) app.viewId = id
                        }
                    }
                }
            }

            // ---------- main ----------
            Item {
                id: main
                x: side.width
                width: parent.width - side.width - (app.sel ? details.width : 0)
                height: parent.height

                Text {
                    id: vTitle
                    x: 28
                    y: 22
                    text: app.viewTitle()
                    font.family: "Inter"
                    font.pixelSize: 26
                    font.weight: Font.DemiBold
                    color: app.viewId === "missed" ? "#f87171" : "#ffffff"
                }
                Text {
                    id: vSub
                    x: 28
                    anchors.top: vTitle.bottom
                    anchors.topMargin: 2
                    text: app.viewId === "myday"
                          ? Qt.formatDate(TodoStore.fromKey(TodoStore.today), "dddd, d MMMM")
                          : app.vdata.activeCount + " open"
                    font.family: "Inter"
                    font.pixelSize: 12
                    color: "#8a8a8a"
                }

                PillButton {
                    visible: !app.isSmart && app.viewId !== "tasks"
                    anchors.right: parent.right
                    anchors.rightMargin: 28
                    y: 30
                    danger: true
                    label: app.confirmList ? "Sure? Delete list" : "Delete list"
                    onClicked: {
                        if (app.confirmList) {
                            TodoStore.removeList(app.viewId)
                            app.viewId = "tasks"
                        } else app.confirmList = true
                    }
                }

                // add bar
                Rectangle {
                    id: addBar
                    x: 28
                    y: vSub.y + vSub.height + 16
                    width: main.width - 56
                    height: 46
                    radius: 10
                    color: "#14ffffff"
                    border.color: addField.editor.activeFocus ? "#40ffffff" : "transparent"
                    border.width: 1

                    Text {
                        id: plus
                        x: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: "+"
                        font.pixelSize: 20
                        color: "#bdbdbd"
                    }
                    Field {
                        id: addField
                        anchors.left: plus.right
                        anchors.leftMargin: 12
                        anchors.right: addChip.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        hint: "Add a task  ·  try 'gym daily' or 'report by fri'"
                        onSubmitted: {
                            TodoStore.addTask(addField.text, app.ctx())
                            addField.text = ""
                        }
                    }
                    Rectangle {
                        id: addChip
                        property bool hit: app.preview.found || app.preview.repeat !== null
                        visible: addField.text !== ""
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: visible ? chipText.implicitWidth + 16 : 0
                        height: 24
                        radius: 12
                        color: hit ? "#ececec" : "#14ffffff"
                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: app.preview.repeat ? "↻ " + TodoStore.repeatLabel(app.preview.repeat)
                                : (app.preview.found ? "Due " + TodoStore.dueLabel(app.preview.due)
                                   : (app.ctx().defaultDue ? "Today" : "No date"))
                            font.family: "JetBrains Mono"
                            font.pixelSize: 9
                            color: addChip.hit ? "#0a0a0b" : "#8a8a8a"
                        }
                    }
                }

                // task list
                Flickable {
                    id: flick
                    x: 28
                    y: addBar.y + addBar.height + 14
                    width: main.width - 56
                    height: main.height - y - 20
                    contentHeight: listCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: listCol
                        width: flick.width
                        spacing: 6

                        Repeater {
                            model: app.vdata.groups
                            Column {
                                id: grp
                                required property var modelData
                                width: listCol.width
                                spacing: 6

                                Text {
                                    visible: grp.modelData.label !== ""
                                    topPadding: 8
                                    text: grp.modelData.label + "   " + grp.modelData.rows.length
                                    font.family: "Inter"
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    color: grp.modelData.label === "Missed" ? "#f87171" : "#bdbdbd"
                                }

                                Repeater {
                                    model: grp.modelData.rows
                                    TaskRow {
                                        required property var modelData
                                        width: listCol.width
                                        task: modelData
                                        selected: app.selectedId === modelData.id
                                        metaText: app.meta(modelData)
                                        onPicked: app.selectedId = (app.selectedId === modelData.id ? "" : modelData.id)
                                    }
                                }
                            }
                        }

                        Rectangle {
                            visible: app.vdata.completed.length > 0
                            width: compText.implicitWidth + 24
                            height: 28
                            radius: 8
                            color: compArea.containsMouse ? "#1fffffff" : "#12ffffff"
                            Text {
                                id: compText
                                anchors.centerIn: parent
                                text: (app.showCompleted ? "⌄   " : "›   ") + "Completed   " + app.vdata.completed.length
                                font.family: "Inter"
                                font.pixelSize: 11
                                color: "#dcdcdc"
                            }
                            MouseArea {
                                id: compArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: app.showCompleted = !app.showCompleted
                            }
                        }

                        Repeater {
                            model: app.showCompleted ? app.vdata.completed : []
                            TaskRow {
                                required property var modelData
                                width: listCol.width
                                task: modelData
                                selected: app.selectedId === modelData.id
                                metaText: app.meta(modelData)
                                onPicked: app.selectedId = (app.selectedId === modelData.id ? "" : modelData.id)
                            }
                        }
                    }
                }

                Text {
                    visible: app.vdata.activeCount === 0 && app.vdata.completed.length === 0
                    anchors.horizontalCenter: flick.horizontalCenter
                    y: flick.y + 60
                    text: app.viewId === "myday" ? "Focus on your day. Add a task above."
                        : app.viewId === "missed" ? "Nothing missed  ✓"
                        : "No tasks here yet"
                    font.family: "Inter"
                    font.pixelSize: 13
                    color: "#5c5c5c"
                }
            }

            // ---------- details pane ----------
            Rectangle {
                id: details
                visible: app.sel !== null
                x: parent.width - width
                width: 320
                height: parent.height
                color: "#0dffffff"

                Rectangle {
                    width: 1
                    height: parent.height
                    color: "#14ffffff"
                }

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 20
                    anchors.bottomMargin: 60
                    contentHeight: dcol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: dcol
                        width: parent.width
                        spacing: 16

                        // title
                        Item {
                            width: dcol.width
                            height: 36
                            Rectangle {
                                id: dCirc
                                anchors.verticalCenter: parent.verticalCenter
                                width: 20
                                height: 20
                                radius: 10
                                color: app.sel && app.sel.done ? "#ececec" : "transparent"
                                border.color: app.sel && app.sel.done ? "#ececec" : "#8a8a8a"
                                border.width: 1.5
                                Text {
                                    anchors.centerIn: parent
                                    visible: app.sel && app.sel.done
                                    text: "✓"
                                    font.pixelSize: 12
                                    color: "#0a0a0b"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    onClicked: TodoStore.toggle(app.selectedId)
                                }
                            }
                            Field {
                                id: titleField
                                anchors.left: dCirc.right
                                anchors.leftMargin: 10
                                anchors.right: dStar.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                hint: "Task name"
                                onSubmitted: TodoStore.rename(app.selectedId, titleField.text)
                            }
                            Connections {
                                target: titleField.editor
                                function onActiveFocusChanged() {
                                    if (!titleField.editor.activeFocus && app.selectedId !== "")
                                        TodoStore.rename(app.selectedId, titleField.text)
                                }
                            }
                            Text {
                                id: dStar
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: app.sel && app.sel.important ? "★" : "☆"
                                font.pixelSize: 18
                                color: app.sel && app.sel.important ? "#ececec" : "#6e6e6e"
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    onClicked: TodoStore.toggleImportant(app.selectedId)
                                }
                            }
                        }

                        // steps
                        Column {
                            width: dcol.width
                            spacing: 2
                            Repeater {
                                model: app.sel ? app.sel.steps : []
                                Item {
                                    id: stepRow
                                    required property var modelData
                                    required property int index
                                    width: dcol.width
                                    height: 28
                                    HoverHandler { id: stepHover }
                                    Rectangle {
                                        id: sc
                                        x: 3
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 14
                                        height: 14
                                        radius: 7
                                        color: stepRow.modelData.done ? "#ececec" : "transparent"
                                        border.color: stepRow.modelData.done ? "#ececec" : "#8a8a8a"
                                        border.width: 1.2
                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -4
                                            onClicked: TodoStore.toggleStep(app.selectedId, stepRow.index)
                                        }
                                    }
                                    Text {
                                        anchors.left: sc.right
                                        anchors.leftMargin: 12
                                        anchors.right: sx.left
                                        anchors.rightMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        elide: Text.ElideRight
                                        text: stepRow.modelData.text
                                        font.family: "Inter"
                                        font.pixelSize: 12
                                        font.strikeout: stepRow.modelData.done
                                        color: stepRow.modelData.done ? "#7c7c7c" : "#dcdcdc"
                                    }
                                    Text {
                                        id: sx
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: stepHover.hovered
                                        text: "×"
                                        font.pixelSize: 14
                                        color: "#9a9a9a"
                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -5
                                            onClicked: TodoStore.removeStep(app.selectedId, stepRow.index)
                                        }
                                    }
                                }
                            }
                            Field {
                                id: stepField
                                width: dcol.width
                                hint: "+ Add step"
                                onSubmitted: {
                                    TodoStore.addStep(app.selectedId, stepField.text)
                                    stepField.text = ""
                                }
                            }
                        }

                        // my day
                        PillButton {
                            visible: app.sel !== null && !app.sel.isRep
                            on: app.sel !== null && app.sel.myDay === TodoStore.today
                            label: on ? "☀   Added to My Day" : "☀   Add to My Day"
                            onClicked: TodoStore.toggleMyDay(app.selectedId)
                        }

                        // due
                        Column {
                            visible: app.sel !== null && !app.sel.isRep
                            width: dcol.width
                            spacing: 8
                            Text {
                                text: "DUE"
                                font.family: "JetBrains Mono"
                                font.pixelSize: 9
                                font.letterSpacing: 1.4
                                color: "#7c7c7c"
                            }
                            Text {
                                text: app.sel && app.sel.due
                                      ? "Due " + TodoStore.dueLabel(app.sel.due) + "   ·   " + Qt.formatDate(TodoStore.fromKey(app.sel.due), "ddd, d MMM")
                                      : "No due date"
                                font.family: "Inter"
                                font.pixelSize: 12
                                color: app.sel && app.sel.due && app.sel.due < TodoStore.today && !app.sel.done ? "#f87171" : "#dcdcdc"
                            }
                            Flow {
                                width: dcol.width
                                spacing: 6
                                PillButton { label: "Today";     onClicked: TodoStore.setDue(app.selectedId, TodoStore.today) }
                                PillButton { label: "Tomorrow";  onClicked: TodoStore.setDue(app.selectedId, TodoStore.addDays(TodoStore.today, 1)) }
                                PillButton { label: "Next week"; onClicked: TodoStore.setDue(app.selectedId, TodoStore.addDays(TodoStore.today, 7)) }
                                PillButton {
                                    visible: app.sel !== null && app.sel.due !== ""
                                    label: "Clear"
                                    onClicked: TodoStore.setDue(app.selectedId, "")
                                }
                            }
                            Field {
                                id: dueField
                                width: dcol.width
                                hint: "or type: fri, 25 nov, in 3 days"
                                onSubmitted: {
                                    const p = TodoStore.parseTask("x " + dueField.text)
                                    if (p.found) TodoStore.setDue(app.selectedId, p.due)
                                    dueField.text = ""
                                }
                            }
                        }

                        // repeat
                        Column {
                            width: dcol.width
                            spacing: 8
                            Text {
                                text: "REPEAT"
                                font.family: "JetBrains Mono"
                                font.pixelSize: 9
                                font.letterSpacing: 1.4
                                color: "#7c7c7c"
                            }
                            Text {
                                text: app.sel && app.sel.isRep ? "↻ " + TodoStore.repeatLabel(app.sel.repeat) : "Doesn't repeat"
                                font.family: "Inter"
                                font.pixelSize: 12
                                color: "#dcdcdc"
                            }
                            Flow {
                                width: dcol.width
                                spacing: 6
                                PillButton { label: "Daily";    onClicked: TodoStore.setRepeat(app.selectedId, [0, 1, 2, 3, 4, 5, 6]) }
                                PillButton { label: "Weekdays"; onClicked: TodoStore.setRepeat(app.selectedId, [1, 2, 3, 4, 5]) }
                                PillButton { label: "Weekly";   onClicked: TodoStore.setRepeat(app.selectedId, [TodoStore.todayDow]) }
                                PillButton {
                                    visible: app.sel !== null && app.sel.isRep
                                    label: "Stop"
                                    onClicked: TodoStore.setRepeat(app.selectedId, null)
                                }
                            }
                            Field {
                                id: repeatField
                                width: dcol.width
                                hint: "or type: every mon and thu"
                                onSubmitted: {
                                    const p = TodoStore.parseTask("x " + repeatField.text)
                                    if (p.repeat) TodoStore.setRepeat(app.selectedId, p.repeat)
                                    repeatField.text = ""
                                }
                            }
                        }

                        // list
                        Column {
                            width: dcol.width
                            spacing: 8
                            Text {
                                text: "LIST"
                                font.family: "JetBrains Mono"
                                font.pixelSize: 9
                                font.letterSpacing: 1.4
                                color: "#7c7c7c"
                            }
                            Flow {
                                width: dcol.width
                                spacing: 6
                                Repeater {
                                    model: TodoStore.lists
                                    PillButton {
                                        required property var modelData
                                        label: modelData.name
                                        on: app.sel !== null && app.sel.list === modelData.id
                                        onClicked: TodoStore.moveToList(app.selectedId, modelData.id)
                                    }
                                }
                            }
                        }

                        // note
                        Column {
                            width: dcol.width
                            spacing: 8
                            Text {
                                text: "NOTE"
                                font.family: "JetBrains Mono"
                                font.pixelSize: 9
                                font.letterSpacing: 1.4
                                color: "#7c7c7c"
                            }
                            Rectangle {
                                width: dcol.width
                                height: 120
                                radius: 10
                                color: "#12ffffff"
                                TextEdit {
                                    id: noteEdit
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    wrapMode: TextEdit.Wrap
                                    selectByMouse: true
                                    clip: true
                                    font.family: "Inter"
                                    font.pixelSize: 12
                                    color: "#dcdcdc"
                                    onTextChanged: {
                                        if (!app.loadingDetails) {
                                            app.noteTarget = app.selectedId
                                            noteTimer.restart()
                                        }
                                    }
                                }
                                Text {
                                    x: 10
                                    y: 10
                                    visible: noteEdit.text === "" && !noteEdit.activeFocus
                                    text: "Add note"
                                    font.family: "Inter"
                                    font.pixelSize: 12
                                    color: "#6e6e6e"
                                }
                            }
                        }
                    }
                }

                // footer
                Item {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 52
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#14ffffff"
                    }
                    Text {
                        x: 20
                        anchors.verticalCenter: parent.verticalCenter
                        text: app.sel ? "Created " + TodoStore.dueLabel(app.sel.created || TodoStore.today).toLowerCase() : ""
                        font.family: "Inter"
                        font.pixelSize: 10
                        color: "#7c7c7c"
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        PillButton {
                            danger: true
                            label: app.confirmDelete ? "Sure? Delete" : "Delete"
                            onClicked: {
                                if (app.confirmDelete) {
                                    TodoStore.remove(app.selectedId)
                                    app.selectedId = ""
                                } else app.confirmDelete = true
                            }
                        }
                        PillButton {
                            label: "Close"
                            onClicked: app.selectedId = ""
                        }
                    }
                }
            }
        }
    }
}
