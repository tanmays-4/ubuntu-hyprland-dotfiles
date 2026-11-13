import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import QtQuick

PanelWindow {
    id: pop

    property bool open: false
    visible: open

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "media"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
    }
    margins {
        top: 42
    }
    implicitWidth: 380
    implicitHeight: card.height + 20
    color: "transparent"

    property real closedAt: 0

    HyprlandFocusGrab {
        windows: [ pop ]
        active: pop.open
        onCleared: pop.open = false
    }

    property var player: {
        const list = Mpris.players.values
        const p = list.find(x => x.isPlaying)
        return p ? p : (list.length > 0 ? list[0] : null)
    }
    property bool hasPlayer: player !== null
    property bool playing: hasPlayer && player.isPlaying
    property var sink: Pipewire.defaultAudioSink

    IpcHandler {
        target: "media"
        function toggle(): void {
            if (!pop.open && Date.now() - pop.closedAt < 300) return
            pop.open = !pop.open
        }
    }

    onOpenChanged: {
        if (open) keys.forceActiveFocus()
        else closedAt = Date.now()
    }

    PwObjectTracker {
        objects: [ Pipewire.defaultAudioSink ]
    }

    Timer {
        interval: 1000
        running: pop.open && pop.playing
        repeat: true
        onTriggered: pop.player.positionChanged()
    }

    function fmt(sec) {
        const s = Math.max(0, Math.floor(sec))
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
    }

    component Icon: Canvas {
        property string kind: "play"
        property string tint: "#dcdcdc"
        width: 18
        height: 18
        onKindChanged: requestPaint()
        onTintChanged: requestPaint()
        onPaint: {
            const c = getContext("2d")
            c.reset()
            c.scale(width / 24, height / 24)
            c.strokeStyle = tint
            c.fillStyle = tint
            c.lineWidth = 2
            c.lineCap = "round"
            c.lineJoin = "round"
            c.beginPath()
            if (kind === "play") {
                c.moveTo(7, 4); c.lineTo(20, 12); c.lineTo(7, 20); c.closePath(); c.fill()
            } else if (kind === "pause") {
                c.fillRect(6, 4, 4, 16); c.fillRect(14, 4, 4, 16)
            } else if (kind === "next") {
                c.moveTo(4, 5); c.lineTo(15, 12); c.lineTo(4, 19); c.closePath(); c.fill()
                c.fillRect(16.5, 5, 3, 14)
            } else if (kind === "prev") {
                c.moveTo(20, 5); c.lineTo(9, 12); c.lineTo(20, 19); c.closePath(); c.fill()
                c.fillRect(4.5, 5, 3, 14)
            } else if (kind === "shuffle") {
                c.moveTo(3, 7); c.lineTo(7, 7); c.lineTo(15, 17); c.lineTo(20, 17)
                c.moveTo(17.5, 14.5); c.lineTo(20, 17); c.lineTo(17.5, 19.5)
                c.moveTo(3, 17); c.lineTo(7, 17); c.lineTo(9.8, 13.5)
                c.moveTo(12.2, 10.5); c.lineTo(15, 7); c.lineTo(20, 7)
                c.moveTo(17.5, 4.5); c.lineTo(20, 7); c.lineTo(17.5, 9.5)
                c.stroke()
            } else if (kind === "repeat" || kind === "repeatone") {
                c.moveTo(5, 11); c.lineTo(5, 8); c.lineTo(18, 8)
                c.moveTo(15.5, 5.5); c.lineTo(18, 8); c.lineTo(15.5, 10.5)
                c.moveTo(19, 13); c.lineTo(19, 16); c.lineTo(6, 16)
                c.moveTo(8.5, 13.5); c.lineTo(6, 16); c.lineTo(8.5, 18.5)
                c.stroke()
                if (kind === "repeatone") {
                    c.font = "bold 8px sans-serif"
                    c.fillText("1", 10, 14.5)
                }
            } else if (kind === "vol") {
                c.moveTo(3, 9.5); c.lineTo(7, 9.5); c.lineTo(12, 5); c.lineTo(12, 19)
                c.lineTo(7, 14.5); c.lineTo(3, 14.5); c.closePath(); c.fill()
                c.beginPath(); c.arc(13, 12, 4, -Math.PI / 3, Math.PI / 3); c.stroke()
                c.beginPath(); c.arc(13, 12, 8, -Math.PI / 3, Math.PI / 3); c.stroke()
            }
        }
    }

    component CtlButton: Rectangle {
        id: cb
        property string kind: "play"
        property bool active: false
        property bool enabledCtl: true
        property bool big: false
        signal activated()
        width: big ? 52 : 36
        height: big ? 52 : 36
        radius: width / 2
        opacity: enabledCtl ? 1 : 0.3
        color: big ? (cbArea.containsMouse ? "#ffffff" : "#ececec") : (cbArea.containsMouse ? "#1fffffff" : "transparent")
        scale: cbArea.pressed ? 0.92 : 1

        Behavior on scale {
            NumberAnimation { duration: 90 }
        }

        Icon {
            anchors.centerIn: parent
            width: cb.big ? 22 : 18
            height: cb.big ? 22 : 18
            kind: cb.kind
            tint: cb.big ? "#0a0a0b" : (cb.active ? "#ffffff" : "#8a8a8a")
        }

        Rectangle {
            visible: cb.active && !cb.big
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2
            width: 4
            height: 4
            radius: 2
            color: "#ffffff"
        }

        MouseArea {
            id: cbArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: cb.enabledCtl
            onClicked: cb.activated()
        }
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: pop.open = false

        Rectangle {
            id: card
            anchors.horizontalCenter: parent.horizontalCenter
            y: 8
            width: 360
            height: col.implicitHeight + 36
            radius: 24
            color: "#d90a0a0b"
            border.color: "#1affffff"
            border.width: 1
            transformOrigin: Item.Top
            scale: pop.open ? 1 : 0.85
            opacity: pop.open ? 1 : 0

            Behavior on scale {
                NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            }
            Behavior on opacity {
                NumberAnimation { duration: 180 }
            }

            MouseArea { anchors.fill: parent }

            Column {
                id: col
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 18
                spacing: 14

                Text {
                    visible: !pop.hasPlayer
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    topPadding: 20
                    bottomPadding: 20
                    text: "Nothing playing"
                    font.family: "Inter"
                    font.pixelSize: 13
                    color: "#8a8a8a"
                }

                Row {
                    visible: pop.hasPlayer
                    width: parent.width
                    spacing: 14

                    Rectangle {
                        width: 76
                        height: 76
                        radius: 14
                        color: "#161618"
                        border.color: "#14ffffff"
                        border.width: 1
                        clip: true

                        Text {
                            anchors.centerIn: parent
                            visible: art.status !== Image.Ready
                            text: "♪"
                            font.family: "Inter"
                            font.pixelSize: 28
                            color: "#5a5a5a"
                        }

                        Image {
                            id: art
                            anchors.fill: parent
                            anchors.margins: 1
                            source: pop.hasPlayer && pop.player.trackArtUrl ? pop.player.trackArtUrl : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 90
                        spacing: 3

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: pop.hasPlayer ? (pop.player.trackTitle || "Unknown") : ""
                            font.family: "Inter"
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            color: "#ffffff"
                        }
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: pop.hasPlayer ? (pop.player.trackArtist || "") : ""
                            font.family: "Inter"
                            font.pixelSize: 13
                            color: "#b4b4b4"
                        }
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: {
                                if (!pop.hasPlayer) return ""
                                const parts = [pop.player.trackAlbum, (pop.player.identity || "").toUpperCase()].filter(x => x)
                                return parts.join("  ·  ")
                            }
                            font.family: "Inter"
                            font.pixelSize: 10
                            color: "#7c7c7c"
                        }
                    }
                }

                Item {
                    visible: pop.hasPlayer
                    width: parent.width
                    height: 22

                    Row {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 3

                        Repeater {
                            model: 40

                            Rectangle {
                                required property int index
                                property bool active: pop.playing && pop.open
                                anchors.bottom: parent.bottom
                                width: 5
                                height: 3
                                radius: 2.5
                                color: index % 3 === 0 ? "#5e5e5e" : "#d8d8d8"

                                onActiveChanged: if (!active) height = 3

                                SequentialAnimation on height {
                                    running: pop.playing && pop.open
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 6 + ((index * 37) % 16); duration: 200 + ((index * 53) % 240); easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 3 + ((index * 11) % 5); duration: 180 + ((index * 29) % 200); easing.type: Easing.InOutSine }
                                }
                            }
                        }
                    }
                }

                Column {
                    visible: pop.hasPlayer
                    width: parent.width
                    spacing: 6

                    Item {
                        id: seek
                        width: parent.width
                        height: 12
                        property real ratio: pop.hasPlayer && pop.player.length > 0 ? Math.min(1, pop.player.position / pop.player.length) : 0

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 4
                            radius: 2
                            color: "#1fffffff"

                            Rectangle {
                                width: parent.width * seek.ratio
                                height: parent.height
                                radius: 2
                                color: "#ececec"
                            }
                        }

                        Rectangle {
                            x: seek.width * seek.ratio - width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: seekArea.containsMouse || seekArea.pressed ? 12 : 8
                            height: width
                            radius: width / 2
                            color: "#ffffff"

                            Behavior on width {
                                NumberAnimation { duration: 100 }
                            }
                        }

                        MouseArea {
                            id: seekArea
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            enabled: pop.hasPlayer && pop.player.canSeek && pop.player.length > 0
                            function seekTo(x) {
                                const r = Math.max(0, Math.min(1, (x - 6) / seek.width))
                                pop.player.position = r * pop.player.length
                            }
                            onPressed: mouse => seekTo(mouse.x)
                            onPositionChanged: mouse => { if (pressed) seekTo(mouse.x) }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 14

                        Text {
                            anchors.left: parent.left
                            text: pop.hasPlayer ? pop.fmt(pop.player.position) : "0:00"
                            font.family: "JetBrains Mono"
                            font.pixelSize: 10
                            color: "#8a8a8a"
                        }
                        Text {
                            anchors.right: parent.right
                            text: pop.hasPlayer && pop.player.length > 0 ? "-" + pop.fmt(pop.player.length - pop.player.position) : "0:00"
                            font.family: "JetBrains Mono"
                            font.pixelSize: 10
                            color: "#8a8a8a"
                        }
                    }
                }

                Row {
                    visible: pop.hasPlayer
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 14

                    CtlButton {
                        anchors.verticalCenter: parent.verticalCenter
                        kind: "shuffle"
                        enabledCtl: pop.hasPlayer && pop.player.shuffleSupported
                        active: pop.hasPlayer && pop.player.shuffle
                        onActivated: pop.player.shuffle = !pop.player.shuffle
                    }
                    CtlButton {
                        anchors.verticalCenter: parent.verticalCenter
                        kind: "prev"
                        active: true
                        enabledCtl: pop.hasPlayer && pop.player.canGoPrevious
                        onActivated: pop.player.previous()
                    }
                    CtlButton {
                        anchors.verticalCenter: parent.verticalCenter
                        big: true
                        kind: pop.playing ? "pause" : "play"
                        enabledCtl: pop.hasPlayer && pop.player.canTogglePlaying
                        onActivated: pop.player.togglePlaying()
                    }
                    CtlButton {
                        anchors.verticalCenter: parent.verticalCenter
                        kind: "next"
                        active: true
                        enabledCtl: pop.hasPlayer && pop.player.canGoNext
                        onActivated: pop.player.next()
                    }
                    CtlButton {
                        anchors.verticalCenter: parent.verticalCenter
                        kind: pop.hasPlayer && pop.player.loopState === MprisLoopState.Track ? "repeatone" : "repeat"
                        enabledCtl: pop.hasPlayer && pop.player.loopSupported
                        active: pop.hasPlayer && pop.player.loopState !== MprisLoopState.None
                        onActivated: {
                            const s = pop.player.loopState
                            if (s === MprisLoopState.None) pop.player.loopState = MprisLoopState.Playlist
                            else if (s === MprisLoopState.Playlist) pop.player.loopState = MprisLoopState.Track
                            else pop.player.loopState = MprisLoopState.None
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: 12

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        kind: "vol"
                        tint: "#8a8a8a"
                    }

                    Item {
                        id: volTrack
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 28
                        height: 12
                        property real level: pop.sink && pop.sink.audio ? (pop.sink.audio.muted ? 0 : pop.sink.audio.volume) : 0

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 4
                            radius: 2
                            color: "#1fffffff"

                            Rectangle {
                                width: parent.width * Math.min(1, volTrack.level)
                                height: parent.height
                                radius: 2
                                color: "#ececec"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            function setVol(x) {
                                if (!pop.sink || !pop.sink.audio) return
                                pop.sink.audio.muted = false
                                pop.sink.audio.volume = Math.max(0, Math.min(1, (x - 6) / volTrack.width))
                            }
                            onPressed: mouse => setVol(mouse.x)
                            onPositionChanged: mouse => { if (pressed) setVol(mouse.x) }
                        }
                    }
                }
            }
        }
    }
}
