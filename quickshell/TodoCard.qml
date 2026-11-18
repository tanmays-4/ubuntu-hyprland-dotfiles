import Quickshell
import Quickshell.Io
import QtQuick

Card {
    id: todo
    title: "TO DO"

    property var items: []
    property var history: ({})            // { "2026-11-18": 3 } tasks done per day
    property string view: "today"         // today | missed | next | heat
    property string hoverInfo: ""

    SystemClock {
        id: clk
        precision: SystemClock.Minutes
    }
    // the "day" starts at 5:30 AM, not midnight
    readonly property int dayStartMinutes: 5 * 60 + 30
    property string today: key(new Date(clk.date.getTime() - dayStartMinutes * 60000))
    property int todayDow: fromKey(today).getDay()
    onTodayChanged: prune()

    // ================= date helpers =================
    readonly property var monthNames: ["jan","feb","mar","apr","may","jun","jul","aug","sep","oct","nov","dec"]
    readonly property var dayNames: ["sun","mon","tue","wed","thu","fri","sat"]
    readonly property var dayShort: ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]

    function pad(n) { return (n < 10 ? "0" : "") + n }
    function key(d) { return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()) }
    function fromKey(k) {
        const p = k.split("-")
        return new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2]))
    }
    function addDays(k, n) {
        const d = fromKey(k)
        d.setDate(d.getDate() + n)
        return key(d)
    }
    function daysBetween(a, b) { return Math.round((fromKey(b) - fromKey(a)) / 86400000) }

    function makeDate(y, m, d) {
        const dt = new Date(y, m, d)
        return (dt.getMonth() === m && dt.getDate() === d) ? key(dt) : ""
    }

    function monthDay(name, d) {
        const m = monthNames.indexOf(name.toLowerCase().slice(0, 3))
        const y = fromKey(today).getFullYear()
        let k = makeDate(y, m, d)
        if (k && k < today) k = makeDate(y + 1, m, d)
        return k
    }

    function dueLabel(k) {
        const diff = daysBetween(today, k)
        if (diff === 0) return "Today"
        if (diff === 1) return "Tomorrow"
        if (diff === -1) return "Yesterday"
        if (diff < 0) return (-diff) + " days ago"
        if (diff < 7) return Qt.formatDate(fromKey(k), "dddd")
        return Qt.formatDate(fromKey(k), "d MMM")
    }

    function repeatLabel(days) {
        const s = days.slice().sort().join(",")
        if (s === "0,1,2,3,4,5,6") return "Daily"
        if (s === "1,2,3,4,5") return "Weekdays"
        if (s === "0,6") return "Weekends"
        return days.slice().sort().map(d => dayShort[d]).join(", ")
    }

    // ================= natural-language parsing =================
    function parseTask(raw) {
        let s = " " + raw + " "
        let due = ""
        let repeat = null
        const base = fromKey(today)
        const P = "(?:\\s(?:by|on|due|for))?\\s"
        const MON = "(january|jan|february|feb|march|mar|april|apr|may|june|jun|july|jul|august|aug|september|sept|sep|october|oct|november|nov|december|dec)"
        const DAY = "(sunday|sun|monday|mon|tuesday|tues|tue|wednesday|wed|thursday|thurs|thu|friday|fri|saturday|sat)"

        function cut(m) { s = s.slice(0, m.index) + " " + s.slice(m.index + m[0].length) }

        // ---- repeating ----
        const repeatRules = [
            ["\\s(?:daily|every ?day)(?=\\s)",                         m => [0,1,2,3,4,5,6]],
            ["(?:\\son)?\\s(?:every weekday|weekdays)(?=\\s)",         m => [1,2,3,4,5]],
            ["(?:\\son)?\\s(?:every weekend|weekends)(?=\\s)",         m => [0,6]],
            ["\\severy\\s(" + DAY + "(?:\\s*(?:,|and|&)\\s*" + DAY + ")*)(?=\\s)", m => {
                const names = m[1].match(new RegExp(DAY, "gi")) || []
                const days = []
                for (const n of names) {
                    const i = dayNames.indexOf(n.toLowerCase().slice(0, 3))
                    if (i >= 0 && days.indexOf(i) === -1) days.push(i)
                }
                return days.length ? days : null
            }]
        ]
        for (const [pattern, toDays] of repeatRules) {
            const m = new RegExp(pattern, "i").exec(s)
            if (!m) continue
            const days = toDays(m)
            if (!days) continue
            repeat = days
            cut(m)
            break
        }

        // ---- one-off due date ----
        const rules = [
            [P + "day after tomorrow(?=\\s)",            m => addDays(today, 2)],
            [P + "(?:today|tonight)(?=\\s)",              m => today],
            [P + "(?:tomorrow|tmrw|tmr)(?=\\s)",          m => addDays(today, 1)],
            [P + "in (\\d+) days?(?=\\s)",                m => addDays(today, Number(m[1]))],
            [P + "(?:next week|in a week)(?=\\s)",        m => addDays(today, 7)],
            [P + "(\\d{4})-(\\d{1,2})-(\\d{1,2})(?=\\s)", m => makeDate(Number(m[1]), Number(m[2]) - 1, Number(m[3]))],
            [P + "(\\d{1,2})[/-](\\d{1,2})(?:[/-](\\d{2,4}))?(?=\\s)", m => {
                let y = m[3] ? Number(m[3]) : base.getFullYear()
                if (y < 100) y += 2000
                let k = makeDate(y, Number(m[2]) - 1, Number(m[1]))
                if (k && !m[3] && k < today) k = makeDate(y + 1, Number(m[2]) - 1, Number(m[1]))
                return k
            }],
            [P + "(\\d{1,2})(?:st|nd|rd|th)?\\s" + MON + "(?=\\s)", m => monthDay(m[2], Number(m[1]))],
            [P + MON + "\\s(\\d{1,2})(?:st|nd|rd|th)?(?=\\s)",      m => monthDay(m[1], Number(m[2]))],
            [P + "(next\\s)?" + DAY + "(?=\\s)", m => {
                const target = dayNames.indexOf(m[2].toLowerCase().slice(0, 3))
                let diff = (target - base.getDay() + 7) % 7
                if (m[1] && diff === 0) diff = 7
                return addDays(today, diff)
            }]
        ]
        if (!repeat) {
            for (const [pattern, toDate] of rules) {
                const m = new RegExp(pattern, "i").exec(s)
                if (!m) continue
                const k = toDate(m)
                if (!k) continue
                due = k
                cut(m)
                break
            }
        }

        let text = s.replace(/\s+/g, " ").trim()
        if (text === "") text = raw.trim()
        return { text: text, due: due || today, found: due !== "", repeat: repeat }
    }

    // ================= storage =================
    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.local/share/dashboard/todo.json"
        onLoaded: {
            let data = null
            try { data = JSON.parse(file.text()) } catch (e) {}
            let list = []
            let hist = {}
            if (Array.isArray(data)) {
                list = data.map((x, i) => ({
                    id: "old" + i,
                    text: String(x.text || x.title || x.name || x),
                    done: !!x.done,
                    due: todo.today,
                    doneOn: x.done ? todo.today : ""
                }))
            } else if (data && Array.isArray(data.items)) {
                list = data.items
                if (data.history) hist = data.history
            }
            // first run: build history from tasks already ticked off
            if (Object.keys(hist).length === 0) {
                for (const it of list) {
                    if (it.done && it.doneOn) hist[it.doneOn] = (hist[it.doneOn] || 0) + 1
                    if (Array.isArray(it.doneDates))
                        for (const d of it.doneDates) hist[d] = (hist[d] || 0) + 1
                }
            }
            todo.items = list
            todo.history = hist
            todo.prune()
        }
        onLoadFailed: { todo.items = []; todo.history = {} }
    }

    function save() { file.setText(JSON.stringify({ items: items, history: history }, null, 2)) }
    function setItems(list) { items = list; save() }
    function isRep(it) { return Array.isArray(it.repeat) }

    function add(raw) {
        if (raw.trim() === "") return
        const t = parseTask(raw)
        const list = items.slice()
        if (t.repeat) {
            list.push({ id: String(Date.now()), text: t.text, repeat: t.repeat, doneDates: [] })
            view = t.repeat.indexOf(todayDow) !== -1 ? "today" : "next"
        } else {
            list.push({ id: String(Date.now()), text: t.text, due: t.due, done: false, doneOn: "" })
            view = t.due === today ? "today" : (t.due < today ? "missed" : "next")
        }
        setItems(list)
    }

    function update(id, change) {
        setItems(items.map(it => {
            if (it.id !== id) return it
            const c = Object.assign({}, it)
            change(c)
            return c
        }))
    }

    function bump(delta) {
        const h = Object.assign({}, history)
        h[today] = Math.max(0, (h[today] || 0) + delta)
        if (h[today] === 0) delete h[today]
        history = h
        save()
    }

    function toggle(id) {
        const it = items.find(x => x.id === id)
        if (!it) return
        if (isRep(it)) {
            const has = it.doneDates.indexOf(today) !== -1
            update(id, c => { c.doneDates = has ? c.doneDates.filter(d => d !== today) : c.doneDates.concat([today]) })
            bump(has ? -1 : 1)
        } else if (!it.done) {
            update(id, c => { c.done = true; c.doneOn = today })
            bump(1)
        } else {
            const wasToday = it.doneOn === today
            update(id, c => { c.done = false; c.doneOn = "" })
            if (wasToday) bump(-1)
        }
    }

    function moveToToday(id) { update(id, c => { c.due = today }) }
    function remove(id)      { setItems(items.filter(it => it.id !== id)) }

    function prune() {
        const doneCutoff = addDays(today, -7)
        const keepCutoff = addDays(today, -200)
        let changed = false
        const list = []
        for (const it of items) {
            if (!isRep(it) && it.done && it.doneOn && it.doneOn < doneCutoff) { changed = true; continue }
            if (isRep(it)) {
                const kept = it.doneDates.filter(d => d >= keepCutoff)
                if (kept.length !== it.doneDates.length) {
                    changed = true
                    list.push(Object.assign({}, it, { doneDates: kept }))
                    continue
                }
            }
            list.push(it)
        }
        const h = {}
        for (const k in history) {
            if (k >= keepCutoff) h[k] = history[k]
            else changed = true
        }
        if (changed) { items = list; history = h; save() }
    }

    // ================= views =================
    property var todayList: items
        .filter(it => isRep(it)
            ? it.repeat.indexOf(todayDow) !== -1
            : ((!it.done && it.due === today) || (it.done && it.doneOn === today)))
        .map(it => isRep(it) ? Object.assign({}, it, { isRep: true, done: it.doneDates.indexOf(today) !== -1 }) : it)
        .sort((a, b) => a.done - b.done)

    property var missedList: items
        .filter(it => !isRep(it) && !it.done && it.due < today)
        .sort((a, b) => a.due < b.due ? -1 : 1)

    property var nextList: items
        .filter(it => !isRep(it) && !it.done && it.due > today)
        .sort((a, b) => a.due < b.due ? -1 : 1)
        .concat(items.filter(it => isRep(it)).map(it => Object.assign({}, it, { isRep: true, done: false })))

    property int todayLeft: todayList.filter(it => !it.done).length
    property var shown: view === "today" ? todayList
                      : view === "missed" ? missedList
                      : view === "next" ? nextList : []

    property var preview: parseTask(input.text || "")

    // ================= heatmap numbers =================
    readonly property int weeks: 17
    readonly property var greens: ["#14ffffff", "#0e4429", "#006d32", "#26a641", "#39d353"]
    function level(n) { return n <= 0 ? 0 : n === 1 ? 1 : n <= 3 ? 2 : n <= 5 ? 3 : 4 }
    property string gridStart: addDays(today, -(todayDow + (weeks - 1) * 7))

    property int streak: {
        let n = 0
        let k = (history[today] || 0) > 0 ? today : addDays(today, -1)
        while ((history[k] || 0) > 0) {
            n++
            k = addDays(k, -1)
        }
        return n
    }
    property int weekDone: {
        let s = 0
        for (let i = 0; i < 7; i++) s += history[addDays(today, -i)] || 0
        return s
    }

    // ---------- tabs ----------
    Row {
        x: todo.width - width - 16
        y: 14
        spacing: 4

        Repeater {
            model: [
                { v: "today",  label: "TODAY" },
                { v: "missed", label: "MISSED" },
                { v: "next",   label: "NEXT" },
                { v: "heat",   label: "" }
            ]

            Rectangle {
                id: tab
                required property var modelData
                property int count: modelData.v === "missed" ? todo.missedList.length
                                  : modelData.v === "next"   ? todo.nextList.filter(it => !it.isRep).length
                                  : modelData.v === "today"  ? todo.todayLeft : 0
                property bool on: todo.view === modelData.v

                width: modelData.v === "heat" ? 26 : tabText.implicitWidth + 12
                height: 20
                radius: 10
                color: on ? "#ececec" : (tabArea.containsMouse ? "#1affffff" : "transparent")
                border.color: "#1fffffff"
                border.width: on ? 0 : 1

                Text {
                    id: tabText
                    visible: tab.modelData.v !== "heat"
                    anchors.centerIn: parent
                    text: tab.modelData.label + (tab.count > 0 ? " " + tab.count : "")
                    font.family: "JetBrains Mono"
                    font.pixelSize: 8
                    font.letterSpacing: 0.6
                    color: tab.on ? "#0a0a0b"
                         : (tab.modelData.v === "missed" && tab.count > 0 ? "#f87171" : "#9a9a9a")
                }

                // little 2x2 green squares icon
                Grid {
                    visible: tab.modelData.v === "heat"
                    anchors.centerIn: parent
                    columns: 2
                    spacing: 1.5
                    Repeater {
                        model: ["#26a641", "#0e4429", "#39d353", "#006d32"]
                        Rectangle {
                            required property string modelData
                            width: 4
                            height: 4
                            radius: 1
                            color: modelData
                        }
                    }
                }

                MouseArea {
                    id: tabArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: todo.view = tab.modelData.v
                }
            }
        }
    }

    // ---------- task list ----------
    ListView {
        id: list
        visible: todo.view !== "heat"
        x: 16
        y: 46
        width: todo.width - 32
        height: todo.height - 46 - 50
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        model: todo.shown

        delegate: Rectangle {
            id: row
            required property var modelData
            property bool rep: !!modelData.isRep
            width: list.width
            height: 26
            radius: 7
            color: rowHover.hovered ? "#0fffffff" : "transparent"

            HoverHandler { id: rowHover }

            Rectangle {
                id: check
                x: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                radius: 7
                opacity: (row.rep && todo.view === "next") ? 0 : 1
                color: row.modelData.done ? "#ececec" : "transparent"
                border.color: row.modelData.done ? "#ececec" : "#6e6e6e"
                border.width: 1.2

                Text {
                    anchors.centerIn: parent
                    visible: row.modelData.done
                    text: "✓"
                    font.pixelSize: 9
                    color: "#0a0a0b"
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    enabled: !(row.rep && todo.view === "next")
                    onClicked: todo.toggle(row.modelData.id)
                }
            }

            Text {
                anchors.left: check.right
                anchors.leftMargin: 8
                anchors.right: actions.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: row.modelData.text
                font.family: "Inter"
                font.pixelSize: 11
                font.strikeout: row.modelData.done
                color: row.modelData.done ? "#6e6e6e" : "#dcdcdc"
            }

            Row {
                id: actions
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // due date / repeat label
                Text {
                    visible: (todo.view !== "today" || row.rep) && !rowHover.hovered
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.rep ? (todo.view === "today" ? "↻" : "↻ " + todo.repeatLabel(row.modelData.repeat))
                                  : todo.dueLabel(row.modelData.due)
                    font.family: "JetBrains Mono"
                    font.pixelSize: 8
                    color: todo.view === "missed" ? "#f87171" : "#8a8a8a"
                }

                Text {
                    visible: todo.view !== "today" && !row.rep && rowHover.hovered
                    anchors.verticalCenter: parent.verticalCenter
                    text: "→ today"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 8
                    color: "#dcdcdc"
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        onClicked: todo.moveToToday(row.modelData.id)
                    }
                }

                Text {
                    visible: rowHover.hovered
                    anchors.verticalCenter: parent.verticalCenter
                    text: "×"
                    font.family: "Inter"
                    font.pixelSize: 13
                    color: "#9a9a9a"
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -5
                        onClicked: todo.remove(row.modelData.id)
                    }
                }
            }
        }
    }

    Text {
        visible: todo.view !== "heat" && todo.shown.length === 0
        anchors.horizontalCenter: list.horizontalCenter
        y: list.y + list.height / 2 - height / 2
        text: todo.view === "today" ? "Nothing due today"
            : todo.view === "missed" ? "Nothing missed  ✓"
            : "Nothing upcoming"
        font.family: "Inter"
        font.pixelSize: 11
        color: "#5c5c5c"
    }

    // ---------- activity heatmap ----------
    Item {
        visible: todo.view === "heat"
        x: 16
        y: 48
        width: todo.width - 32
        height: todo.height - 48 - 14

        Grid {
            id: cells
            rows: 7
            flow: Grid.TopToBottom
            spacing: 3

            Repeater {
                model: todo.weeks * 7

                Rectangle {
                    id: cell
                    required property int index
                    property string day: todo.addDays(todo.gridStart, index)
                    property int n: todo.history[day] || 0

                    width: 10
                    height: 10
                    radius: 2
                    opacity: day <= todo.today ? 1 : 0
                    color: todo.greens[todo.level(n)]
                    border.color: day === todo.today ? "#99ffffff" : "transparent"
                    border.width: 1

                    HoverHandler {
                        onHoveredChanged: {
                            if (hovered && cell.day <= todo.today)
                                todo.hoverInfo = cell.n + (cell.n === 1 ? " task · " : " tasks · ")
                                               + Qt.formatDate(todo.fromKey(cell.day), "ddd d MMM")
                            else if (!hovered)
                                todo.hoverInfo = ""
                        }
                    }
                }
            }
        }

        Text {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            text: todo.hoverInfo !== "" ? todo.hoverInfo
                : (todo.streak + " day streak  ·  " + todo.weekDone + " this week")
            font.family: "JetBrains Mono"
            font.pixelSize: 9
            color: "#9a9a9a"
        }

        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            spacing: 2

            Repeater {
                model: todo.greens
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

    // ---------- input + live preview ----------
    Item {
        visible: todo.view !== "heat"
        x: 16
        y: todo.height - 44
        width: todo.width - 32
        height: 30

        Field {
            id: input
            width: parent.width - chip.width - 6
            hint: "New task · 'tmrw', 'daily'"
            onSubmitted: {
                todo.add(input.text)
                input.text = ""
            }
        }

        Rectangle {
            id: chip
            property bool hit: todo.preview.found || todo.preview.repeat !== null
            anchors.right: parent.right
            anchors.verticalCenter: input.verticalCenter
            width: chipText.implicitWidth + 14
            height: 22
            radius: 11
            color: hit ? "#ececec" : "#14ffffff"

            Text {
                id: chipText
                anchors.centerIn: parent
                text: todo.preview.repeat ? "↻ " + todo.repeatLabel(todo.preview.repeat)
                                          : todo.dueLabel(todo.preview.due)
                font.family: "JetBrains Mono"
                font.pixelSize: 8
                color: chip.hit ? "#0a0a0b" : "#8a8a8a"
            }
        }
    }
}
