import QtQuick
import AraraCypher

// Visão "Tudo" de um trecho: cada acorde num quadro com o braço (detalhado)
// e, embaixo, o pedaço da partitura + tab tocado nele. Se o trecho tem tab
// (riff), ela é cortada nos pontos em que muda o acorde; se não tem, o quadro
// mostra a partitura e a tab colorida da batida.
Flow {
    id: root
    property var section: null         // a parte de verdade
    property var song: null
    property var strum: null
    property int semitones: 0
    property real zoom: 1
    property string keyName: "C"
    property int rev: 0
    spacing: 10

    function t(name) { return Music.transposeChord(name, semitones) }

    // Pedaços da tab: [{ name, tab, events }] na ordem.
    readonly property var segments: {
        rev
        if (!section || !section.tab) return []
        var systems = JSON.parse(Music.tabModel(section.tab))
        var out = []
        for (var s = 0; s < systems.length; ++s) {
            var sys = systems[s]
            var chords = (sys.chords || []).slice().sort(function (a, b) { return a.at - b.at })
            var cuts = chords.map(function (c) { return c.at })
            if (cuts.length === 0 || cuts[0] > 0) {
                cuts.unshift(0)
                chords.unshift({ at: 0, name: out.length ? out[out.length - 1].name : "" })
            }
            for (var i = 0; i < cuts.length; ++i) {
                var a = cuts[i], b = i + 1 < cuts.length ? cuts[i + 1] : sys.events.length
                if (b <= a) continue
                var sub = {
                    chords: [],
                    events: sys.events.slice(a, b),
                    bars: (sys.bars || []).filter(function (x) { return x > a && x < b }).map(function (x) { return x - a })
                }
                out.push({ name: chords[i].name, tab: Music.renderTab(JSON.stringify([sub])), events: sub.events.length, bars: sub.bars.length })
            }
        }
        return out
    }
    // Sem tab: um quadro por acorde, com a batida da parte.
    // Tab sem nomes de acorde em cima: mostra os acordes da parte também.
    readonly property var chordItems: !section ? []
        : section.tab && segments.some(function (g) { return g.name !== "" }) ? [] : (section.chords || [])
    function patternOf(i) {
        var base = strum ? strum.pattern : ["D"]
        var own = section && section.measures ? section.measures[i] : null
        return own && own.length === base.length ? own : base
    }
    function cellsOf(i) {
        var base = strum ? strum.pattern : ["D"]
        var own = section && section.measures ? section.measures[i] : null
        return own && own.length === base.length && section.cells && section.cells[i] ? section.cells[i] : ({})
    }

    // ---- Com tab: pedaços ----
    Repeater {
        model: root.segments
        Rectangle {
            id: seg
            required property var modelData
            readonly property string name: modelData.name
            readonly property var voicing: root.song ? Examples.voicing(root.song, name) : null
            width: Math.max(diag.visible ? diag.implicitWidth * root.zoom + 16 : 0, score.width + 16, title.implicitWidth + 24)
            height: col.implicitHeight + 16
            radius: Theme.radiusSmall
            color: Qt.rgba(Theme.chord.r, Theme.chord.g, Theme.chord.b, Theme.dark ? 0.12 : 0.07)
            Column {
                id: col
                x: 8; y: 8
                width: parent.width - 16
                spacing: 4
                Text {
                    id: title
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: seg.name !== ""
                    text: root.t(Examples.chordName(seg.name))
                    color: Theme.chord
                    font.family: Theme.monoFamily
                    font.pixelSize: (Theme.fontSize + 4) * root.zoom
                    font.weight: Font.Bold
                }
                Item {
                    visible: diag.visible
                    width: parent.width
                    height: diag.implicitHeight * root.zoom
                    BigChordDiagram {
                        id: diag
                        visible: seg.name !== "" && shape !== null
                        scale: root.zoom
                        transformOrigin: Item.Top
                        anchors.horizontalCenter: parent.horizontalCenter
                        chord: Examples.chordName(seg.name)
                        voicing: seg.voicing
                        semitones: root.semitones
                    }
                }
                TabScore {
                    id: score
                    // Pedaço comprido quebra em linhas dentro da largura da tela.
                    width: Math.min(root.width - 16, (48 + seg.modelData.events * 24 + seg.modelData.bars * 12 + 20) * root.zoom)
                    height: implicitHeight
                    tab: seg.modelData.tab
                    keyName: root.keyName
                    zoom: root.zoom
                }
            }
        }
    }

    // ---- Sem tab: acordes com a batida ----
    Repeater {
        model: root.chordItems
        Rectangle {
            id: box
            required property string modelData
            required property int index
            readonly property string name: Examples.chordName(modelData)
            readonly property var voicing: root.song ? Examples.voicing(root.song, modelData) : null
            width: Math.max(big.implicitWidth * root.zoom, notation.width, strumTab.implicitWidth * root.zoom, label.implicitWidth) + 24
            height: inner.implicitHeight + 16
            radius: Theme.radiusSmall
            color: Qt.rgba(Theme.chord.r, Theme.chord.g, Theme.chord.b, Theme.dark ? 0.12 : 0.07)
            Column {
                id: inner
                x: 8; y: 8
                width: parent.width - 16
                spacing: 6
                Text {
                    id: label
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.t(box.name)
                    color: Theme.chord
                    font.family: Theme.monoFamily
                    font.pixelSize: (Theme.fontSize + 4) * root.zoom
                    font.weight: Font.Bold
                }
                Item {
                    visible: big.shape !== null
                    width: parent.width
                    height: big.implicitHeight * root.zoom
                    BigChordDiagram {
                        id: big
                        scale: root.zoom
                        transformOrigin: Item.Top
                        anchors.horizontalCenter: parent.horizontalCenter
                        chord: box.name
                        voicing: box.voicing
                        semitones: root.semitones
                    }
                }
                NotationView {
                    id: notation
                    visible: big.shape !== null
                    anchors.horizontalCenter: parent.horizontalCenter
                    zoom: root.zoom
                    width: implicitWidth
                    height: implicitHeight
                    chord: box.name
                    voicing: box.voicing
                    semitones: root.semitones
                    pattern: root.rev, root.patternOf(box.index)
                }
                Item {
                    width: parent.width
                    height: strumTab.implicitHeight * root.zoom
                    StrumTab {
                        id: strumTab
                        scale: root.zoom
                        transformOrigin: Item.Top
                        anchors.horizontalCenter: parent.horizontalCenter
                        chord: box.name
                        voicing: box.voicing
                        semitones: root.semitones
                        rev: root.rev
                        pattern: root.rev, root.patternOf(box.index).slice()
                        cells: root.rev, JSON.parse(JSON.stringify(root.cellsOf(box.index)))
                        counts: root.strum ? root.strum.counts : []
                    }
                }
            }
        }
    }
}
