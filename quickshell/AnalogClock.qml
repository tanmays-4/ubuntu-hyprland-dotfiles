import QtQuick

Item {
    id: clockFace
    property var date: new Date()

    property int hours: date.getHours() % 12
    property int minutes: date.getMinutes()
    property int seconds: date.getSeconds()

    width: 150
    height: 150

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "#8c0a0a0b"
        border.color: "#14ffffff"
        border.width: 1
    }

    Repeater {
        model: 12

        Rectangle {
            required property int index
            property bool major: index % 3 === 0
            width: major ? 3 : 1.5
            height: major ? 12 : 7
            radius: width / 2
            color: major ? "#f0f0f0" : "#4dffffff"
            x: clockFace.width / 2 - width / 2
            y: 8
            transform: Rotation {
                origin.x: width / 2
                origin.y: clockFace.height / 2 - 8
                angle: index * 30
            }
        }
    }

    Rectangle {
        width: 5
        height: 36
        radius: 2.5
        color: "#f0f0f0"
        x: clockFace.width / 2 - width / 2
        y: clockFace.height / 2 - height
        transform: Rotation {
            origin.x: 2.5
            origin.y: 36
            angle: clockFace.hours * 30 + clockFace.minutes * 0.5
        }
    }

    Rectangle {
        width: 3
        height: 54
        radius: 1.5
        color: "#f0f0f0"
        x: clockFace.width / 2 - width / 2
        y: clockFace.height / 2 - height
        transform: Rotation {
            origin.x: 1.5
            origin.y: 54
            angle: clockFace.minutes * 6 + clockFace.seconds * 0.1
        }
    }

    Rectangle {
        width: 1.4
        height: 62
        color: "#8a8a8a"
        x: clockFace.width / 2 - width / 2
        y: clockFace.height / 2 - height
        transform: Rotation {
            origin.x: 0.7
            origin.y: 62
            angle: clockFace.seconds * 6
        }
    }

    Rectangle {
        width: 8
        height: 8
        radius: 4
        color: "#f0f0f0"
        anchors.centerIn: parent
    }
}
