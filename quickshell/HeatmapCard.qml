import QtQuick

Card {
    id: heat
    title: "ACTIVITY"

    property string hoverInfo: ""
    readonly property int gap: 3
    property int cell: Math.max(6, Math.min(12, Math.floor((height - 50 - 26 + gap) / 7) - gap))
    property int weeks: Math.max(4, Math.floor((width - 32 + gap) / (cell + gap)))
    property string gridStart: TodoStore.addDays(TodoStore.today, -(TodoStore.todayDow + (weeks - 1) * 7))

    Text {
        x: heat.width - width - 18
        y: 16
        text: TodoStore.streak + " day streak  ·  " + TodoStore.weekDone + " this week"
        font.family: "JetBrains Mono"
        font.pixelSize: 9
        color: "#9a9a9a"
    }

    Grid {
        x: 16
        y: 46
        rows: 7
        flow: Grid.TopToBottom
        spacing: heat.gap

        Repeater {
            model: heat.weeks * 7
            Rectangle {
                id: cellBox
                required property int index
                property string day: TodoStore.addDays(heat.gridStart, index)
                property int n: TodoStore.history[day] || 0
                width: heat.cell
                height: heat.cell
                radius: 2
                opacity: day <= TodoStore.today ? 1 : 0
                color: TodoStore.greens[TodoStore.level(n)]
                border.color: day === TodoStore.today ? "#99ffffff" : "transparent"
                border.width: 1
                HoverHandler {
                    onHoveredChanged: {
                        if (hovered && cellBox.day <= TodoStore.today)
                            heat.hoverInfo = cellBox.n + (cellBox.n === 1 ? " task · " : " tasks · ")
                                           + Qt.formatDate(TodoStore.fromKey(cellBox.day), "ddd d MMM")
                        else if (!hovered)
                            heat.hoverInfo = ""
                    }
                }
            }
        }
    }

    Text {
        x: 16
        y: heat.height - 24
        text: heat.hoverInfo !== "" ? heat.hoverInfo : "Tasks completed per day"
        font.family: "JetBrains Mono"
        font.pixelSize: 9
        color: "#7c7c7c"
    }

    Row {
        x: heat.width - width - 16
        y: heat.height - 23
        spacing: 2
        Repeater {
            model: TodoStore.greens
            Rectangle {
                required property string modelData
                width: 8
                height: 8
                radius: 2
                color: modelData
            }
        }
    }
}
