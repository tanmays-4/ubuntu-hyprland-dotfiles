pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: store

    property var lists: [{ id: "tasks", name: "Tasks" }]
    property var items: []
    property var history: ({})
    property bool loaded: false

    // ---------- the day starts at 5:30 AM ----------
    readonly property int dayStartMinutes: 5 * 60 + 30
    SystemClock {
        id: clk
        precision: SystemClock.Minutes
    }
    property string today: key(new Date(clk.date.getTime() - dayStartMinutes * 60000))
    property int todayDow: fromKey(today).getDay()
    onTodayChanged: if (loaded) prune()

    // ---------- date helpers ----------
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
    function groupOf(k) {
        const d = daysBetween(today, k)
        return d < 0 ? "Missed" : d === 0 ? "Today" : d === 1 ? "Tomorrow" : d < 7 ? "This week" : "Later"
    }

    // ---------- plain-English parsing ----------
    function parseTask(raw) {
        let s = " " + raw + " "
        let due = ""
        let repeat = null
        const base = fromKey(today)
        const P = "(?:\\s(?:by|on|due|for))?\\s"
        const MON = "(january|jan|february|feb|march|mar|april|apr|may|june|jun|july|jul|august|aug|september|sept|sep|october|oct|november|nov|december|dec)"
        const DAY = "(sunday|sun|monday|mon|tuesday|tues|tue|wednesday|wed|thursday|thurs|thu|friday|fri|saturday|sat)"
        function cut(m) { s = s.slice(0, m.index) + " " + s.slice(m.index + m[0].length) }

        const repeatRules = [
            ["\\s(?:daily|every ?day)(?=\\s)",                 m => [0,1,2,3,4,5,6]],
            ["(?:\\son)?\\s(?:every weekday|weekdays)(?=\\s)", m => [1,2,3,4,5]],
            ["(?:\\son)?\\s(?:every weekend|weekends)(?=\\s)", m => [0,6]],
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

    // ---------- storage ----------
    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.local/share/dashboard/todo.json"
        onLoaded: store.load(file.text())
        onLoadFailed: store.loaded = true
    }

    function normalize(it) {
        return Object.assign({ list: "tasks", due: "", important: false, myDay: "", done: false,
                               doneOn: "", steps: [], note: "", created: today }, it)
    }

    function load(text) {
        let data = null
        try { data = JSON.parse(text) } catch (e) {}
        let list = []
        let hist = {}
        let ls = [{ id: "tasks", name: "Tasks" }]
        if (Array.isArray(data)) {
            list = data.map((x, i) => ({ id: "old" + i, text: String(x.text || x.title || x.name || x),
                                         done: !!x.done, due: today, doneOn: x.done ? today : "" }))
        } else if (data) {
            if (Array.isArray(data.items)) list = data.items
            if (data.history) hist = data.history
            if (Array.isArray(data.lists) && data.lists.length) ls = data.lists
        }
        list = list.map(normalize)
        if (Object.keys(hist).length === 0) {
            for (const it of list) {
                if (it.done && it.doneOn) hist[it.doneOn] = (hist[it.doneOn] || 0) + 1
                if (Array.isArray(it.doneDates))
                    for (const d of it.doneDates) hist[d] = (hist[d] || 0) + 1
            }
        }
        lists = ls
        items = list
        history = hist
        loaded = true
        prune()
    }

    function save() {
        if (!loaded) return
        file.setText(JSON.stringify({ version: 2, lists: lists, items: items, history: history }, null, 2))
    }

    // ---------- views ----------
    function isRep(it) { return Array.isArray(it.repeat) }

    property var decorated: items.map(it => Object.assign({}, it, isRep(it)
        ? { isRep: true, done: it.doneDates.indexOf(today) !== -1 }
        : { isRep: false }))

    property var myDayItems: decorated.filter(it => it.isRep
        ? it.repeat.indexOf(todayDow) !== -1
        : (it.done ? it.doneOn === today : (it.due === today || it.myDay === today)))

    property var missedItems: decorated.filter(it => !it.isRep && !it.done && it.due !== "" && it.due < today)

    function byDue(a, b) {
        const ad = a.due || "9999-99-99"
        const bd = b.due || "9999-99-99"
        if (ad !== bd) return ad < bd ? -1 : 1
        return (b.important ? 1 : 0) - (a.important ? 1 : 0)
    }

    function viewData(v) {
        let pick
        if (v === "myday") pick = myDayItems
        else if (v === "important") pick = decorated.filter(it => it.important)
        else if (v === "planned") pick = decorated.filter(it => !it.isRep && it.due !== "")
        else if (v === "missed") pick = missedItems
        else if (v === "repeat") pick = decorated.filter(it => it.isRep)
        else pick = decorated.filter(it => it.list === v)

        const active = pick.filter(it => !it.done).sort(byDue)
        const completed = pick.filter(it => it.done)
        let groups
        if (v === "planned") {
            groups = ["Missed", "Today", "Tomorrow", "This week", "Later"]
                .map(l => ({ label: l, rows: active.filter(it => groupOf(it.due) === l) }))
                .filter(g => g.rows.length > 0)
        } else {
            groups = active.length ? [{ label: "", rows: active }] : []
        }
        return { groups: groups, completed: completed, activeCount: active.length }
    }
    function countFor(v) { return viewData(v).activeCount }
    function listName(id) {
        const l = lists.find(x => x.id === id)
        return l ? l.name : "Tasks"
    }

    // ---------- actions ----------
    function newId() { return String(Date.now()) + String(Math.floor(Math.random() * 1000)) }
    function find(id) { return items.find(it => it.id === id) || null }

    function update(id, change) {
        items = items.map(it => {
            if (it.id !== id) return it
            const c = Object.assign({}, it)
            change(c)
            return c
        })
        save()
    }

    function addTask(raw, ctx) {
        if (!raw || raw.trim() === "") return ""
        ctx = ctx || {}
        const t = parseTask(raw)
        const it = normalize({ id: newId(), text: t.text, list: ctx.list || "tasks", important: !!ctx.important })
        const rep = t.repeat || ctx.repeat || null
        if (rep) {
            it.repeat = rep
            it.doneDates = []
        } else {
            it.due = t.found ? t.due : (ctx.defaultDue || "")
            if (ctx.myDay && !t.found) it.myDay = today
        }
        items = items.concat([it])
        save()
        return it.id
    }

    function bump(delta) {
        const h = Object.assign({}, history)
        h[today] = Math.max(0, (h[today] || 0) + delta)
        if (h[today] === 0) delete h[today]
        history = h
        save()
    }

    function toggle(id) {
        const it = find(id)
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

    function toggleImportant(id) { update(id, c => { c.important = !c.important }) }
    function toggleMyDay(id)     { update(id, c => { c.myDay = c.myDay === today ? "" : today }) }
    function setDue(id, k)       { update(id, c => { c.due = k }) }
    function moveToList(id, l)   { update(id, c => { c.list = l }) }
    function rename(id, text) {
        const it = find(id)
        if (it && text.trim() !== "" && it.text !== text.trim()) update(id, c => { c.text = text.trim() })
    }
    function setNote(id, note) {
        const it = find(id)
        if (it && (it.note || "") !== note) update(id, c => { c.note = note })
    }
    function setRepeat(id, days) {
        update(id, c => {
            if (days) {
                c.repeat = days
                c.doneDates = c.doneDates || []
                c.done = false
                c.doneOn = ""
            } else {
                delete c.repeat
                delete c.doneDates
            }
        })
    }
    function remove(id) {
        items = items.filter(it => it.id !== id)
        save()
    }

    function addStep(id, text) {
        if (text.trim() === "") return
        update(id, c => { c.steps = (c.steps || []).concat([{ text: text.trim(), done: false }]) })
    }
    function toggleStep(id, i) { update(id, c => { c.steps = c.steps.map((s, j) => j === i ? { text: s.text, done: !s.done } : s) }) }
    function removeStep(id, i) { update(id, c => { c.steps = c.steps.filter((s, j) => j !== i) }) }

    function addList(name) {
        if (name.trim() === "") return ""
        const l = { id: "l" + newId(), name: name.trim() }
        lists = lists.concat([l])
        save()
        return l.id
    }
    function removeList(id) {
        if (id === "tasks") return
        lists = lists.filter(l => l.id !== id)
        items = items.map(it => it.list === id ? Object.assign({}, it, { list: "tasks" }) : it)
        save()
    }

    function prune() {
        const doneCutoff = addDays(today, -7)
        const keepCutoff = addDays(today, -400)
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
        if (changed) {
            items = list
            history = h
            save()
        }
    }

    // ---------- heatmap numbers ----------
    readonly property var greens: ["#14ffffff", "#0e4429", "#006d32", "#26a641", "#39d353"]
    function level(n) { return n <= 0 ? 0 : n === 1 ? 1 : n <= 3 ? 2 : n <= 5 ? 3 : 4 }
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
}
