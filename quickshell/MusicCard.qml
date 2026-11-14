import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick

Card {
    property bool dashOpen: true

    id: music

    property var player: {
        const list = Mpris.players.values
        const playing = list.find(p => p.isPlaying)
        return playing ? playing : (list.length > 0 ? list[0] : null)
    }
    property bool hasPlayer: player !== null
    property bool playing: hasPlayer && player.isPlaying
    property var bars: []

    function fmt(sec) {
        const s = Math.max(0, Math.floor(sec))
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
    }

    Timer {
        interval: 1000
        running: music.playing && dashOpen
        repeat: true
        onTriggered: music.player.positionChanged()
    }

    Process {
        id: cava
        running: music.playing && dashOpen
        command: ["cava", "-p", Quickshell.env("HOME") + "/.config/quickshell/scripts/cava.conf"]
        stdout: SplitParser {
            onRead: data => {
                music.bars = data.split(";").filter(v => v !== "").map(Number)
            }
        }
    }

    onPlayingChanged: if (!playing) bars = []

    component Glyph: Canvas {
        property string kind: "play"
        property string tint: "#cfcfcf"
        width: 16
        height: 16
        onKindChanged: requestPaint()
        onTintChanged: requestPaint()
        onPaint: {
            const c = getContext("2d")
            c.reset()
            c.fillStyle = tint
            const w = width
            const h = height
            if (kind === "play") {
                c.beginPath()
                c.moveTo(w * 0.28, h * 0.15)
                c.lineTo(w * 0.85, h * 0.5)
                c.lineTo(w * 0.28, h * 0.85)
                c.closePath()
                c.fill()
            } else if (kind === "pause") {
                c.fillRect(w * 0.24, h * 0.15, w * 0.18, h * 0.7)
                c.fillRect(w * 0.58, h * 0.15, w * 0.18, h * 0.7)
            } else if (kind === "next") {
                c.beginPath()
                c.moveTo(w * 0.15, h * 0.15)
                c.lineTo(w * 0.68, h * 0.5)
                c.lineTo(w * 0.15, h * 0.85)
                c.closePath()
                c.fill()
                c.fillRect(w * 0.72, h * 0.15, w * 0.13, h * 0.7)
            } else {
                c.beginPath()
                c.moveTo(w * 0.85, h * 0.15)
                c.lineTo(w * 0.32, h * 0.5)
                c.lineTo(w * 0.85, h * 0.85)
                c.closePath()
                c.fill()
                c.fillRect(w * 0.15, h * 0.15, w * 0.13, h * 0.7)
            }
        }
    }

    Rectangle {
        id: art
        x: 20
        y: 20
        width: music.height - 40
        height: width
        radius: 12
        color: "#161618"
        border.color: "#14ffffff"
        border.width: 1
        clip: true

        Text {
            anchors.centerIn: parent
            visible: cover.status !== Image.Ready
            text: "♪"
            font.family: "Inter"
            font.pixelSize: 48
            color: "#5a5a5a"
        }

        Image {
            id: cover
            anchors.fill: parent
            anchors.margins: 1
            source: music.hasPlayer && music.player.trackArtUrl ? music.player.trackArtUrl : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }

    Column {
        x: art.x + art.width + 22
        y: 22
        width: music.width - x - 22
        height: music.height - 44
        spacing: 0

        Text {
            text: !music.hasPlayer ? "NOW PLAYING" : (music.playing ? "NOW PLAYING" : "PAUSED")
            font.family: "JetBrains Mono"
            font.pixelSize: 10
            font.letterSpacing: 1.8
            color: "#8a8a8a"
        }

        Item { width: 1; height: 6 }

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: music.hasPlayer && music.player.trackTitle ? music.player.trackTitle : "Nothing playing"
            font.family: "Inter"
            font.pixelSize: 22
            font.weight: Font.Medium
            color: music.hasPlayer ? "#ececec" : "#6e6e6e"
        }

        Text {
            width: parent.width
            elide: Text.ElideRight
            visible: music.hasPlayer
            text: {
                if (!music.hasPlayer) return ""
                const parts = [music.player.trackArtist, music.player.trackAlbum].filter(s => s)
                return parts.join("  ·  ")
            }
            font.family: "Inter"
            font.pixelSize: 13
            color: "#9a9a9a"
        }

        Item { width: 1; height: 10 }

        Item {
            width: parent.width
            height: 38

            Row {
                anchors.bottom: parent.bottom
                spacing: 3

                Repeater {
                    model: 36

                    Rectangle {
                        required property int index
                        property real v: index < music.bars.length ? music.bars[index] : 0
                        anchors.bottom: parent.bottom
                        width: (music.width - (art.x + art.width + 44) - 35 * 3) / 36
                        height: Math.max(3, v / 100 * 38)
                        radius: width / 2
                        color: index % 3 === 0 ? "#6e6e6e" : "#d8d8d8"

                        Behavior on height {
                            NumberAnimation { duration: 80 }
                        }
                    }
                }
            }
        }

        Item { width: 1; height: 12 }

        Row {
            width: parent.width
            spacing: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: music.hasPlayer ? music.fmt(music.player.position) : "0:00"
                font.family: "JetBrains Mono"
                font.pixelSize: 10
                color: "#8a8a8a"
            }

            Rectangle {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 90
                height: 3
                radius: 2
                color: "#1affffff"

                Rectangle {
                    height: parent.height
                    radius: 2
                    color: "#e8e8e8"
                    width: music.hasPlayer && music.player.length > 0
                           ? parent.width * Math.min(1, music.player.position / music.player.length)
                           : 0
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    enabled: music.hasPlayer && music.player.canSeek && music.player.length > 0
                    onClicked: mouse => {
                        const ratio = Math.max(0, Math.min(1, (mouse.x - 8) / track.width))
                        music.player.position = ratio * music.player.length
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: music.hasPlayer && music.player.length > 0 ? music.fmt(music.player.length) : "0:00"
                font.family: "JetBrains Mono"
                font.pixelSize: 10
                color: "#8a8a8a"
            }
        }

        Item { width: 1; height: 10 }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 18
            opacity: music.hasPlayer ? 1 : 0.35

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 34
                height: 34
                radius: 17
                color: prevArea.containsMouse ? "#14ffffff" : "transparent"
                Glyph { anchors.centerIn: parent; kind: "prev" }
                MouseArea {
                    id: prevArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: if (music.hasPlayer && music.player.canGoPrevious) music.player.previous()
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 44
                radius: 22
                color: playArea.containsMouse ? "#ffffff" : "#ececec"
                Glyph {
                    anchors.centerIn: parent
                    kind: music.playing ? "pause" : "play"
                    tint: "#0a0a0b"
                }
                MouseArea {
                    id: playArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: if (music.hasPlayer && music.player.canTogglePlaying) music.player.togglePlaying()
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 34
                height: 34
                radius: 17
                color: nextArea.containsMouse ? "#14ffffff" : "transparent"
                Glyph { anchors.centerIn: parent; kind: "next" }
                MouseArea {
                    id: nextArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: if (music.hasPlayer && music.player.canGoNext) music.player.next()
                }
            }
        }
    }
}
