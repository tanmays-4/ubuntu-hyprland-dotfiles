import QtQuick

Rectangle {
    property string title: ""
    property string placeholder: ""

    radius: 18
    color: "#ad0c0c0d"
    border.color: "#0fffffff"
    border.width: 1

    Text {
        visible: parent.title !== ""
        x: 18
        y: 16
        text: parent.title
        font.family: "JetBrains Mono"
        font.pixelSize: 10
        font.letterSpacing: 1.8
        color: "#8a8a8a"
    }

    Text {
        visible: parent.placeholder !== ""
        anchors.centerIn: parent
        text: parent.placeholder
        font.family: "Inter"
        font.pixelSize: 12
        color: "#5a5a5a"
    }
}
