import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick

Card {
    id: stats
    title: "SYSTEM"

    property real cpu: 0
    property real freqGhz: 0
    property int threads: 0
    property real memUsed: 0
    property real memTotal: 0
    property real temp: 0
    property real diskUsed: 0
    property real diskTotal: 0
    property real down: 0
    property real up: 0
    property int uptime: 0

    property var lastCpu: null
    property var lastNet: null

    property var bat: UPower.displayDevice
    property real batRaw: bat ? bat.percentage : 0
    property real batLevel: batRaw <= 1 ? batRaw : batRaw / 100
    property bool charging: bat && bat.state === UPowerDeviceState.Charging

    function gb(bytes) { return (bytes / 1073741824).toFixed(0) }
    function rate(bps) {
        if (bps >= 1048576) return (bps / 1048576).toFixed(1) + " MB/s"
        return (bps / 1024).toFixed(0) + " KB/s"
    }
    function dur(sec) {
        const h = Math.floor(sec / 3600)
        const m = Math.floor((sec % 3600) / 60)
        return h > 0 ? h + "h " + m + "m" : m + "m"
    }

    property string batDetail: {
        if (!bat) return ""
        if (charging) return bat.timeToFull > 0 ? "full in " + dur(bat.timeToFull) : "charging"
        return bat.timeToEmpty > 0 ? dur(bat.timeToEmpty) + " left" : "on battery"
    }

    Process {
        id: reader
        command: ["sh", Quickshell.env("HOME") + "/.config/quickshell/scripts/stats.sh"]
        stdout: StdioCollector {
            id: out
            onStreamFinished: stats.parse(out.text)
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: reader.running = true
    }

    function parse(text) {
        const lines = text.trim().split("\n")
        for (const line of lines) {
            const f = line.trim().split(/\s+/)
            const key = f[0]

            if (key === "CPU") {
                const nums = f.slice(1).map(Number)
                const idle = nums[3] + nums[4]
                const total = nums.reduce((a, b) => a + b, 0)
                if (lastCpu) {
                    const dt = total - lastCpu.total
                    const di = idle - lastCpu.idle
                    if (dt > 0) cpu = 1 - di / dt
                }
                lastCpu = { total: total, idle: idle }
            } else if (key === "MEM") {
                memTotal = Number(f[1]) / 1048576
                memUsed = (Number(f[1]) - Number(f[2])) / 1048576
            } else if (key === "TEMP") {
                temp = Number(f[1]) / 1000
            } else if (key === "FREQ") {
                freqGhz = Number(f[1]) / 1000
            } else if (key === "THREADS") {
                threads = Number(f[1])
            } else if (key === "DISK") {
                diskUsed = Number(f[1])
                diskTotal = Number(f[2])
            } else if (key === "NET") {
                const rx = Number(f[1])
                const tx = Number(f[2])
                if (lastNet) {
                    down = Math.max(0, (rx - lastNet.rx) / 2)
                    up = Math.max(0, (tx - lastNet.tx) / 2)
                }
                lastNet = { rx: rx, tx: tx }
            } else if (key === "UP") {
                uptime = Number(f[1])
            }
        }
    }

    component Stat: Row {
        property real value: 0
        property string label: ""
        property string big: ""
        property string small: ""
        spacing: 12

        Ring {
            anchors.verticalCenter: parent.verticalCenter
            value: parent.value
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                text: label
                font.family: "JetBrains Mono"
                font.pixelSize: 9
                font.letterSpacing: 1.4
                color: "#8a8a8a"
            }
            Text {
                text: big
                font.family: "Inter"
                font.pixelSize: 18
                font.weight: Font.Medium
                color: "#f0f0f0"
            }
            Text {
                text: small
                font.family: "JetBrains Mono"
                font.pixelSize: 10
                color: "#9a9a9a"
            }
        }
    }

    Grid {
        x: 20
        y: 40
        columns: 2
        columnSpacing: 20
        rowSpacing: 10

        Stat {
            width: (stats.width - 60) / 2
            value: stats.cpu
            label: "CPU"
            big: Math.round(stats.cpu * 100) + "%"
            small: stats.freqGhz.toFixed(1) + " GHz · " + stats.threads + " threads"
        }
        Stat {
            width: (stats.width - 60) / 2
            value: stats.memTotal > 0 ? stats.memUsed / stats.memTotal : 0
            label: "MEMORY"
            big: stats.memUsed.toFixed(1) + " / " + stats.memTotal.toFixed(0) + " GB"
            small: Math.round(stats.memTotal > 0 ? stats.memUsed / stats.memTotal * 100 : 0) + "% used"
        }
        Stat {
            width: (stats.width - 60) / 2
            value: stats.batLevel
            label: "BATTERY"
            big: Math.round(stats.batLevel * 100) + "%"
            small: stats.batDetail
        }
        Stat {
            width: (stats.width - 60) / 2
            value: stats.temp / 100
            label: "TEMP"
            big: Math.round(stats.temp) + "°C"
            small: stats.temp >= 80 ? "running hot" : (stats.temp >= 60 ? "warm" : "cool")
        }
    }

    Rectangle {
        x: 20
        y: 154
        width: stats.width - 40
        height: 1
        color: "#0fffffff"
    }

    Row {
        x: 20
        y: 164
        width: stats.width - 40

        Repeater {
            model: [
                ["DISK", stats.gb(stats.diskUsed) + " / " + stats.gb(stats.diskTotal) + " GB"],
                ["↑", stats.rate(stats.up)],
                ["↓", stats.rate(stats.down)],
                ["UP", stats.dur(stats.uptime)]
            ]

            Text {
                required property var modelData
                width: (stats.width - 40) / 4
                text: modelData[0] + "  " + modelData[1]
                font.family: "JetBrains Mono"
                font.pixelSize: 10
                color: "#9a9a9a"
            }
        }
    }
}
