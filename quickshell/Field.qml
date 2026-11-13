import QtQuick

Rectangle {
    id: field
    property alias text: input.text
    property alias editor: input
    property string hint: ""
    signal submitted()

    height: 30
    radius: 8
    color: "#14ffffff"
    border.color: input.activeFocus ? "#40ffffff" : "transparent"
    border.width: 1

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: TextInput.AlignVCenter
        color: "#ececec"
        selectionColor: "#40ffffff"
        font.family: "Inter"
        font.pixelSize: 12
        clip: true
        selectByMouse: true
        onAccepted: field.submitted()
    }

    Text {
        anchors.fill: input
        verticalAlignment: Text.AlignVCenter
        visible: input.text === ""
        text: field.hint
        font.family: "Inter"
        font.pixelSize: 12
        color: "#6e6e6e"
    }
}
