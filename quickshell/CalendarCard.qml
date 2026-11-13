import Quickshell
import QtQuick

Card {
    id: cal

    SystemClock {
        id: calClock
        precision: SystemClock.Hours
    }

    property var now: calClock.date
    property int year: now.getFullYear()
    property int month: now.getMonth()
    property int today: now.getDate()
    property int offset: (new Date(year, month, 1).getDay() + 6) % 7
    property int daysInMonth: new Date(year, month + 1, 0).getDate()

    property var cells: {
        const list = []
        for (let i = 0; i < offset; i++) list.push(0)
        for (let d = 1; d <= daysInMonth; d++) list.push(d)
        return list
    }

    property real cellWidth: (width - 36) / 7

    Column {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 8

        Row {
            width: parent.width

            Text {
                width: parent.width - yearText.width
                text: Qt.formatDate(cal.now, "MMMM")
                font.family: "Inter"
                font.pixelSize: 15
                font.weight: Font.DemiBold
                color: "#ececec"
            }

            Text {
                id: yearText
                text: cal.year
                font.family: "JetBrains Mono"
                font.pixelSize: 11
                color: "#8a8a8a"
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Row {
            Repeater {
                model: ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]

                Text {
                    required property var modelData
                    width: cal.cellWidth
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    font.family: "JetBrains Mono"
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    color: "#7c7c7c"
                }
            }
        }

        Grid {
            columns: 7
            rowSpacing: 2

            Repeater {
                model: cal.cells

                Rectangle {
                    required property var modelData
                    property bool isToday: modelData === cal.today
                    width: cal.cellWidth
                    height: 22
                    radius: 6
                    color: isToday ? "#ececec" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData > 0 ? parent.modelData : ""
                        font.family: "JetBrains Mono"
                        font.pixelSize: 11
                        font.weight: parent.isToday ? Font.Bold : Font.Normal
                        color: parent.isToday ? "#0a0a0b" : (parent.modelData < cal.today ? "#6e6e6e" : "#dcdcdc")
                    }
                }
            }
        }
    }
}
