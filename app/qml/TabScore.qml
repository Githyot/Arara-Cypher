import QtQuick
import AraraCypher

// Riff ou solo em partitura + tablatura, a partir de uma tab em texto.
// As notas vêm do leitor de tab do núcleo (Music.parseTab): cada coluna da
// tab vira uma nota (ou notas juntas), escrita como colcheia, já que a tab em
// texto não diz o ritmo. Barras "|" da tab viram barras de compasso.
// Quebra em várias linhas para caber na largura.
Canvas {
    id: root
    property string tab
    property string keyName: "C"       // tom, para escrever ♯ ou ♭
    property real zoom: 1
    property int startNumber: 0        // número do compasso (0 = não mostra)
    property string label: ""          // nome da parte, em cima da primeira linha

    readonly property var events: tab.length > 0 ? JSON.parse(Music.parseTab(tab)) : []
    readonly property real lw: width / zoom

    readonly property real gap: 9
    readonly property real tabGap: 11
    readonly property real clefW: 48
    readonly property real slotW: 24
    readonly property real barW: 12
    readonly property real topPad: label.length > 0 ? 30 : 18
    readonly property real staffH: gap * 4
    readonly property real rowH: topPad + staffH + gap * 6 + tabGap * 5 + 22

    // Divide os eventos em linhas que cabem na largura.
    readonly property var rows: {
        var out = []
        var avail = Math.max(120, lw - clefW - 8)
        var cur = [], used = 0
        for (var i = 0; i < events.length; ++i) {
            var w = events[i].bar ? barW : slotW
            if (used + w > avail && cur.length > 0) {
                out.push(cur); cur = []; used = 0
                if (events[i].bar) continue
            }
            cur.push(events[i]); used += w
        }
        if (cur.length > 0) out.push(cur)
        return out
    }

    implicitHeight: Math.max(1, rows.length) * rowH * zoom
    visible: events.length > 0

    onRowsChanged: requestPaint()
    onZoomChanged: requestPaint()
    onKeyNameChanged: requestPaint()
    Connections {
        target: Theme
        function onDarkChanged() { root.requestPaint() }
        function onStyleChanged() { root.requestPaint() }
    }

    function drawClef(ctx, color, x, staffTop) {
        var staffBottom = staffTop + staffH
        var yOf = function (step) { return staffBottom - (step - 30) * gap / 2 }
        var top = staffTop - gap * 1.6, bottom = staffBottom + gap * 1.8
        ctx.strokeStyle = color
        ctx.lineWidth = 1.8
        ctx.beginPath()
        ctx.moveTo(x + 2, bottom)
        ctx.bezierCurveTo(x + 4, bottom - gap, x + 4, top + gap * 2, x + 6, top + gap * 0.6)
        ctx.bezierCurveTo(x + 8, top - gap * 0.4, x + 1, top - gap * 0.2, x + 1, top + gap * 1.6)
        ctx.bezierCurveTo(x + 1, top + gap * 3, x + 11, yOf(32) - gap * 0.5, x + 10, yOf(32) + gap * 1.2)
        ctx.bezierCurveTo(x + 9, staffBottom + gap * 0.3, x - 5, staffBottom, x - 4, yOf(32))
        ctx.bezierCurveTo(x - 3, yOf(34) - gap * 0.2, x + 7, yOf(34), x + 7, yOf(32))
        ctx.stroke()
        ctx.beginPath()
        ctx.arc(x, bottom - 1, 2.2, 0, Math.PI * 2)
        ctx.fillStyle = color
        ctx.fill()
        ctx.font = "bold 9px sans-serif"
        ctx.fillText("8", x - 1, bottom + 11)
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        if (events.length === 0) return
        ctx.scale(zoom, zoom)
        var ink = Theme.text, dim = Theme.textDim, accent = Theme.accent
        var open = [40, 45, 50, 55, 59, 64]
        var measure = startNumber

        for (var r = 0; r < rows.length; ++r) {
            var row = rows[r]
            var y0 = r * rowH
            var staffTop = y0 + topPad
            var staffBottom = staffTop + staffH
            var tabTop = staffBottom + gap * 6
            var tabBottom = tabTop + tabGap * 5
            var yOf = function (step) { return staffBottom - (step - 30) * gap / 2 }
            // A última linha termina logo depois da última nota.
            var rowEnd = lw - 1
            if (r === rows.length - 1) {
                var used = clefW + 8
                for (var u = 0; u < row.length; ++u) used += row[u].bar ? barW : slotW
                rowEnd = Math.min(lw - 1, used)
            }

            if (r === 0 && label.length > 0) {
                ctx.fillStyle = accent
                ctx.font = "bold 11px sans-serif"
                ctx.fillText(label.toUpperCase(), clefW, y0 + 12)
            }
            if (measure > 0) {
                ctx.fillStyle = dim
                ctx.font = "11px sans-serif"
                ctx.fillText(String(measure), 14, staffTop - gap * 1.4)
            }

            // Chave, linhas, clave e letras da tab.
            ctx.strokeStyle = ink
            ctx.lineWidth = 2
            ctx.beginPath()
            ctx.moveTo(8, staffTop)
            ctx.bezierCurveTo(2, staffTop + 10, 8, (staffTop + tabBottom) / 2 - 10, 3, (staffTop + tabBottom) / 2)
            ctx.bezierCurveTo(8, (staffTop + tabBottom) / 2 + 10, 2, tabBottom - 10, 8, tabBottom)
            ctx.stroke()
            ctx.strokeStyle = dim
            ctx.lineWidth = 1
            for (var l = 0; l < 5; ++l) {
                var ly = Math.round(staffTop + l * gap) + 0.5
                ctx.beginPath(); ctx.moveTo(12, ly); ctx.lineTo(rowEnd, ly); ctx.stroke()
            }
            for (var t = 0; t < 6; ++t) {
                var ty = Math.round(tabTop + t * tabGap) + 0.5
                ctx.beginPath(); ctx.moveTo(12, ty); ctx.lineTo(rowEnd, ty); ctx.stroke()
            }
            ctx.beginPath(); ctx.moveTo(12.5, staffTop); ctx.lineTo(12.5, tabBottom); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(rowEnd - 0.5, staffTop); ctx.lineTo(rowEnd - 0.5, staffBottom); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(rowEnd - 0.5, tabTop); ctx.lineTo(rowEnd - 0.5, tabBottom); ctx.stroke()
            drawClef(ctx, ink, 22, staffTop)
            ctx.fillStyle = ink
            ctx.font = "bold 11px sans-serif"
            ctx.fillText("T", 30, tabTop + tabGap * 1.4)
            ctx.fillText("A", 30, tabTop + tabGap * 2.7)
            ctx.fillText("B", 30, tabTop + tabGap * 4.0)

            var x = clefW
            var stems = []
            for (var i = 0; i < row.length; ++i) {
                var ev = row[i]
                if (ev.bar) {
                    var bx = Math.round(x + barW / 2) + 0.5
                    ctx.strokeStyle = ink
                    ctx.lineWidth = 1
                    ctx.beginPath(); ctx.moveTo(bx, staffTop); ctx.lineTo(bx, staffBottom); ctx.stroke()
                    ctx.beginPath(); ctx.moveTo(bx, tabTop); ctx.lineTo(bx, tabBottom); ctx.stroke()
                    stems.push(null)
                    x += barW
                    if (measure > 0) measure++
                    continue
                }
                var cx = x + slotW / 2
                // Tab.
                ctx.font = "bold 11px sans-serif"
                for (var k = 0; k < ev.notes.length; ++k) {
                    var n = ev.notes[k]
                    var label2 = String(n.fret)
                    var tyy = tabTop + (5 - n.string) * tabGap
                    var tw = ctx.measureText(label2).width
                    ctx.fillStyle = Theme.card
                    ctx.fillRect(cx - tw / 2 - 2, tyy - 6, tw + 4, 12)
                    ctx.fillStyle = ink
                    ctx.fillText(label2, cx - tw / 2, tyy + 4)
                    if (n.tech) {
                        ctx.fillStyle = accent
                        ctx.font = "10px sans-serif"
                        var tl = n.tech === "/" || n.tech === "\\" ? n.tech : n.tech.toUpperCase()
                        ctx.fillText(tl, cx - slotW / 2 - 2, tyy - 6)
                        ctx.font = "bold 11px sans-serif"
                    }
                }
                // Pauta.
                var minY = 1e9, maxY = -1e9, prevStep = -100
                for (var m = 0; m < ev.notes.length; ++m) {
                    var note = ev.notes[m]
                    var sp = Examples.spell(open[note.string] + note.fret, keyName)
                    var y = yOf(sp.step)
                    minY = Math.min(minY, y); maxY = Math.max(maxY, y)
                    ctx.strokeStyle = dim
                    ctx.lineWidth = 1
                    for (var st = 28; st >= sp.step; st -= 2) {
                        var l1 = Math.round(yOf(st)) + 0.5
                        ctx.beginPath(); ctx.moveTo(cx - 7, l1); ctx.lineTo(cx + 7, l1); ctx.stroke()
                    }
                    for (var st2 = 40; st2 <= sp.step; st2 += 2) {
                        var l2 = Math.round(yOf(st2)) + 0.5
                        ctx.beginPath(); ctx.moveTo(cx - 7, l2); ctx.lineTo(cx + 7, l2); ctx.stroke()
                    }
                    var nx = (sp.step - prevStep === 1) ? cx + 6 : cx
                    prevStep = sp.step
                    ctx.fillStyle = accent
                    ctx.save()
                    ctx.translate(nx, y); ctx.rotate(-0.35); ctx.scale(1.35, 1)
                    ctx.beginPath(); ctx.arc(0, 0, gap / 2 - 0.3, 0, Math.PI * 2); ctx.fill()
                    ctx.restore()
                    if (sp.acc !== 0) {
                        ctx.fillStyle = ink
                        ctx.font = "13px sans-serif"
                        ctx.fillText(sp.acc > 0 ? "♯" : "♭", cx - 15, y + 5)
                    }
                }
                var stTop = minY - gap * 3.5
                ctx.strokeStyle = ink
                ctx.lineWidth = 1.2
                ctx.beginPath(); ctx.moveTo(cx + 4.5, maxY); ctx.lineTo(cx + 4.5, stTop); ctx.stroke()
                stems.push({ x: cx + 4.5, y: stTop })
                x += slotW
            }

            // Colcheias em pares (sem atravessar barra de compasso).
            ctx.strokeStyle = ink
            ctx.fillStyle = ink
            var p = 0
            while (p < stems.length) {
                var a = stems[p], b = p + 1 < stems.length ? stems[p + 1] : null
                if (a && b) {
                    var yb = Math.min(a.y, b.y)
                    ctx.fillRect(a.x - 0.6, yb, b.x - a.x + 1.2, 3.5)
                    ctx.lineWidth = 1.2
                    ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(a.x, yb); ctx.stroke()
                    ctx.beginPath(); ctx.moveTo(b.x, b.y); ctx.lineTo(b.x, yb); ctx.stroke()
                    p += 2
                } else {
                    if (a) {
                        ctx.lineWidth = 1.6
                        ctx.beginPath()
                        ctx.moveTo(a.x, a.y)
                        ctx.bezierCurveTo(a.x + 2, a.y + 5, a.x + 9, a.y + 7, a.x + 6, a.y + 14)
                        ctx.stroke()
                    }
                    p += 1
                }
            }
        }
    }
}
