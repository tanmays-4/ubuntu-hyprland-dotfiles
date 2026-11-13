import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Hyprland
import QtQuick

Item {
    id: pill

    property var player: {
        const list = Mpris.players.values
        const p = list.find(x => x.isPlaying)
        return p ? p : (list.length > 0 ? list[0] : null)
    }
    property bool playing: player !== null && player.isPlaying
    property string title: player && player.trackTitle ? player.trackTitle : ""
    property string artist: player && player.trackArtist ? player.trackArtist : ""

    visible: title !== ""
    width: visible ? bg.width : 0
    height: 24
    opacity: playing ? 1 : 0.65

    Behavior on opacity {
        NumberAnimation { duration: 200 }
    }

    component Ctl: Canvas {
        property string kind: "play"
        width: 10
        height: 10
        onKindChanged: requestPaint()
        onPaint: {
            const c = getContext("2d")
            c.reset()
            c.fillStyle = "#dcdcdc"
            const w = width
            const h = height
            c.beginPath()
            if (kind === "play") {
                c.moveTo(w * 0.2, 0); c.lineTo(w, h / 2); c.lineTo(w * 0.2, h)
            } else if (kind === "pause") {
                c.fillRect(w * 0.15, 0, w * 0.25, h)
                c.fillRect(w * 0.6, 0, w * 0.25, h)
                return
            } else if (kind === "next") {
                c.moveTo(0, 0); c.lineTo(w * 0.7, h / 2); c.lineTo(0, h)
                c.closePath(); c.fill()
                c.fillRect(w * 0.75, 0, w * 0.2, h)
                return
            } else {
                c.moveTo(w, 0); c.lineTo(w * 0.3, h / 2); c.lineTo(w, h)
                c.closePath(); c.fill()
                c.fillRect(w * 0.05, 0, w * 0.2, h)
                return
            }
            c.closePath()
            c.fill()
        }
    }

    Rectangle {
        id: bg
        height: 24
        width: content.width + 18
        radius: 12
        color: hover.hovered ? "#1fffffff" : "#0fffffff"

        HoverHandler { id: hover }

        MouseArea {
            anchors.fill: parent
            onClicked: Hyprland.dispatch("exec qs ipc call media toggle")
        }

        Row {
            id: content
            anchors.centerIn: parent
            spacing: 8

            Canvas {
                id: disc
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                onPaint: {
                    const c = getContext("2d")
                    c.reset()
                    c.fillStyle = "#1c1c1e"
                    c.beginPath(); c.arc(8, 8, 7.5, 0, 2 * Math.PI); c.fill()
                    c.strokeStyle = "rgba(255,255,255,0.18)"
                    c.lineWidth = 0.8
                    for (const r of [6, 4.5]) {
                        c.beginPath(); c.arc(8, 8, r, 0, 2 * Math.PI); c.stroke()
                    }
                    c.strokeStyle = "rgba(255,255,255,0.55)"
                    c.lineWidth = 1
                    c.beginPath(); c.arc(8, 8, 6, -0.6, 0.4); c.stroke()
                    c.fillStyle = "#ececec"
                    c.beginPath(); c.arc(8, 8, 2.2, 0, 2 * Math.PI); c.fill()
                    c.fillStyle = "#1c1c1e"
                    c.beginPath(); c.arc(8, 8, 0.7, 0, 2 * Math.PI); c.fill()
                }

                RotationAnimator on rotation {
                    from: 0
                    to: 360
                    duration: 3200
                    loops: Animation.Infinite
                    running: pill.playing
                }
            }

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 4 * 2 + 3 * 2
                height: 12

                Row {
                    anchors.bottom: parent.bottom
                    spacing: 2

                    Repeater {
                        model: 4

                        Rectangle {
                            required property int index
                            property bool active: pill.playing
                            anchors.bottom: parent.bottom
                            width: 2
                            height: 3
                            radius: 1
                            color: "#dcdcdc"

                            onActiveChanged: if (!active) height = 3

                            SequentialAnimation on height {
                                running: pill.playing
                                loops: Animation.Infinite
                                NumberAnimation { to: 12; duration: 260 + index * 90; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 3; duration: 240 + index * 70; easing.type: Easing.InOutSine }
                            }
                        }
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 230)
                elide: Text.ElideRight
                text: pill.artist !== "" ? pill.title + "  ·  " + pill.artist : pill.title
                font.family: "Inter"
                font.pixelSize: 11
                color: "#dcdcdc"
            }

            Row {
                opacity: hover.hovered ? 1 : 0
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }

                Repeater {
                    model: ["prev", "toggle", "next"]

                    Rectangle {
                        required property var modelData
                        width: 20
                        height: 20
                        radius: 10
                        color: ctlArea.containsMouse ? "#2affffff" : "transparent"

                        Ctl {
                            anchors.centerIn: parent
                            kind: parent.modelData === "toggle" ? (pill.playing ? "pause" : "play") : parent.modelData
                        }

                        MouseArea {
                            id: ctlArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (!pill.player) return
                                if (parent.modelData === "prev" && pill.player.canGoPrevious) pill.player.previous()
                                else if (parent.modelData === "next" && pill.player.canGoNext) pill.player.next()
                                else if (parent.modelData === "toggle" && pill.player.canTogglePlaying) pill.player.togglePlaying()
                            }
                        }
                    }
                }
            }
        }
    }
}
