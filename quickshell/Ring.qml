import QtQuick

Canvas {
    id: ring
    property real value: 0

    width: 48
    height: 48

    onValueChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        const c = width / 2
        const r = c - 4
        ctx.lineWidth = 5
        ctx.lineCap = "round"

        ctx.strokeStyle = "rgba(255, 255, 255, 0.08)"
        ctx.beginPath()
        ctx.arc(c, c, r, 0, 2 * Math.PI)
        ctx.stroke()

        if (value > 0) {
            ctx.strokeStyle = "#e8e8e8"
            ctx.beginPath()
            ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * Math.min(1, value))
            ctx.stroke()
        }
    }
}
