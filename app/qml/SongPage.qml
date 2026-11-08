import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtMultimedia
import Qt.labs.settings
import AraraCypher

// Visualização de uma cifra: seções com os acordes, tom e transposição, e um
// menu de opções (rolagem automática, colunas, capotraste, afinação, mostrar
// tabs e batidas, metrônomo no BPM da música e pedal passador).
Rectangle {
    id: page
    property var song
    property int semitones: 0
    // Capotraste e afinação escolhidos aqui: mudam as formas, não o som.
    readonly property int songCapo: song && song.capo ? song.capo : 0
    property int capo: songCapo
    property int tuning: 0              // semitons abaixo do padrão (0, 1, 2)
    readonly property int shift: semitones + (songCapo - capo) + tuning

    // Preferências da tela (valem para todas as músicas).
    Settings {
        id: prefs
        category: "musica"
        property int columns: 1
        property bool showTabs: true
        property bool showStrums: true
        property int scrollSpeed: 3
        property bool pedal: true
    }
    function restoreDefaults() {
        prefs.columns = 1; prefs.showTabs = true; prefs.showStrums = true
        prefs.scrollSpeed = 3; prefs.pedal = true
        capo = songCapo; tuning = 0; semitones = 0
        Theme.chordZoom = 1
        viewMode = "tab"; fullScore = false
        scrolling = false; metroVisible = false; metro.running = false
        metro.bpm = songBpm
    }

    // ---- Rolagem automática ----
    property bool scrolling: false
    readonly property var scrollSpeeds: [0, 8, 14, 22, 32, 45, 62, 85]   // pixels por segundo
    Timer {
        interval: 30
        repeat: true
        running: page.scrolling
        onTriggered: {
            var max = flick.contentHeight - flick.height
            if (flick.contentY >= max) { page.scrolling = false; return }
            flick.contentY = Math.min(max, flick.contentY + page.scrollSpeeds[prefs.scrollSpeed] * 0.03)
        }
    }

    // ---- Pedal passador / teclado: Page Down, seta para baixo ou direita avançam. ----
    function page_(dir) {
        var max = Math.max(0, flick.contentHeight - flick.height)
        flick.contentY = Math.max(0, Math.min(max, flick.contentY + dir * flick.height * 0.8))
    }
    focus: true
    Component.onCompleted: forceActiveFocus()
    Keys.onPressed: (e) => {
        if (!prefs.pedal) return
        if (e.key === Qt.Key_PageDown || e.key === Qt.Key_Down || e.key === Qt.Key_Right) { page_(1); e.accepted = true }
        else if (e.key === Qt.Key_PageUp || e.key === Qt.Key_Up || e.key === Qt.Key_Left) { page_(-1); e.accepted = true }
    }

    // ---- Metrônomo no BPM da música ----
    readonly property int songBpm: {
        if (song && song.bpm) return song.bpm
        if (song && song.strums) for (var i = 0; i < song.strums.length; ++i) if (song.strums[i].bpm) return song.strums[i].bpm
        return 80
    }
    property bool metroVisible: false
    QtObject {
        id: metro
        property int bpm: page.songBpm
        property bool running: false
        property real t0: 0
        property int beat: -1
    }
    SoundEffect { id: ticForte; source: Music.clickSound(true); volume: 0.9 }
    SoundEffect { id: ticFraco; source: Music.clickSound(false); volume: 0.6 }
    Timer {
        interval: 5
        repeat: true
        running: metro.running
        onTriggered: {
            var n = Math.floor((Date.now() - metro.t0) / (60000 / metro.bpm))
            if (n !== metro.beat) {
                metro.beat = n
                ;(n % 4 === 0 ? ticForte : ticFraco).play()
            }
        }
    }
    function toggleMetro() {
        if (metro.running) { metro.running = false; return }
        metro.t0 = Date.now()
        metro.beat = -1
        metro.running = true
    }
    property string viewMode: "tab"   // "names" | "diagram" | "big" | "tab" | "score" | "lesson"
    // Na aula, as partes sem tab aparecem como na visualização Tab.
    readonly property string chordMode: viewMode === "lesson" ? "tab" : viewMode
    property bool fullScore: false     // partitura da música inteira, em linhas
    readonly property bool showFullScore: viewMode === "score" && fullScore
    readonly property real zoom: Theme.chordZoom

    // Batidas usadas em alguma parte da música, na ordem.
    readonly property var usedStrums: {
        var out = []
        if (!song || !song.strums) return out
        for (var i = 0; i < song.strums.length; ++i) {
            var used = false
            for (var j = 0; j < song.sections.length; ++j)
                if ((song.sections[j].strum || 0) === i) used = true
            if (used) out.push(song.strums[i])
        }
        return out
    }

    // Partitura da música inteira em blocos: compassos de acordes (um por
    // acorde) e, no meio, os riffs/solos colados como tab.
    readonly property var scoreBlocks: {
        var out = []
        if (!song) return out
        var n = 1
        var cur = null
        for (var i = 0; i < song.sections.length; ++i) {
            var sec = song.sections[i]
            var strum = Examples.strumOf(song, sec)
            for (var j = 0; j < sec.chords.length; ++j) {
                if (!cur) { cur = { tab: "", measures: [] }; out.push(cur) }
                cur.measures.push({
                    chord: Examples.chordName(sec.chords[j]),
                    voicing: Examples.voicing(song, sec.chords[j]),
                    pattern: strum ? strum.pattern : ["D"],
                    number: n++,
                    label: j === 0 ? sec.name : "",
                    repeat: j === sec.chords.length - 1 && sec.repeat > 1 ? sec.repeat : 0
                })
            }
            if (sec.tab && sec.tab.length > 0) {
                cur = null
                var events = JSON.parse(Music.parseTab(sec.tab))
                if (events.length === 0) continue
                var bars = events.filter(function (e) { return e.bar }).length
                out.push({ tab: sec.tab, measures: [], start: n,
                           label: sec.name + (sec.repeat > 1 ? " (" + sec.repeat + "×)" : "") })
                n += bars + 1
            }
        }
        return out
    }
    signal back()
    signal edit()

    signal setAll(bool open)

    // "D · D U · U D U" -> setas para o resumo das batidas.
    function arrows(pattern) {
        return pattern.map(function (p) {
            return p === "" ? "·" : p === "U" ? "↑" : p === "X" ? "×" : "↓"
        }).join(" ")
    }
    function chordList(sec) {
        var names = sec.chords.map(function (c) { return t(Examples.chordName(c)) })
        var s = names.join("  ")
        if (sec.tab) s += (s ? "  · " : "") + "tab"
        if (!s && sec.note) s = sec.note
        return s
    }
    // Nome de uma parte anterior com os mesmos acordes e a mesma tab, ou "".
    function sameAs(i) {
        if (!song) return ""
        var a = song.sections[i]
        if (a.chords.length === 0 && !a.tab) return ""
        for (var j = 0; j < i; ++j) {
            var b = song.sections[j]
            if (b.chords.join(" ") === a.chords.join(" ") && (b.tab || "") === (a.tab || "")
                    && (b.strum || 0) === (a.strum || 0))
                return b.name
        }
        return ""
    }

    color: Theme.window

    function t(chord) { return Music.transposeChord(chord, shift) }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        HeaderBar {
            Layout.fillWidth: true
            title: page.song ? page.song.title : ""
            AppButton {
                text: page.song && page.song.id ? "Editar" : "Editar uma cópia"
                flat: true
                onClicked: page.edit()
            }
            AppButton {
                text: page.scrolling ? "Parar" : "Rolar"
                flat: true
                onClicked: page.scrolling = !page.scrolling
            }
            AppButton { text: "Voltar"; flat: true; onClicked: page.back() }
        }

        Flickable {
            id: flick
            // Rolar com a mão para a rolagem automática.
            onMovementStarted: page.scrolling = false

            ScrollBar.vertical: AppScrollBar {}
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: content.implicitHeight + 2 * Theme.pagePadding
            clip: true

            Column {
                id: content
                y: Theme.pagePadding
                width: Math.min(parent.width - 2 * Theme.pagePadding, prefs.columns > 1 ? 1400 : 720)
                x: (parent.width - width) / 2
                spacing: 14

                // ---- Cabeçalho, tom e como ver ----
                Card {
                    width: parent.width
                    RowLayout {
                        width: parent.width
                        spacing: 8
                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Row {
                                spacing: 8
                                Text {
                                    text: page.song ? page.t(page.song.key) : ""
                                    color: Theme.chord
                                    font.family: Theme.monoFamily
                                    font.pixelSize: 24
                                    font.weight: Font.Bold
                                }
                                Text {
                                    anchors.baseline: parent.children[0].baseline
                                    text: (page.capo ? "capo " + page.capo + "ª casa" : (page.songCapo ? "sem capo" : ""))
                                      + (page.tuning ? " · " + (page.tuning === 1 ? "½ tom abaixo" : "1 tom abaixo") : "")
                                    color: Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 1
                                }
                            }
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: page.song ? [page.song.artist, page.song.source].filter(function (s) { return !!s }).join(" · ") : ""
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 2
                            }
                        }
                        AppButton { iconName: "remove"; onClicked: page.semitones-- }
                        Text {
                            Layout.preferredWidth: 32
                            horizontalAlignment: Text.AlignHCenter
                            text: (page.semitones > 0 ? "+" : "") + page.semitones
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                        AppButton { iconName: "add"; onClicked: page.semitones++ }
                        AppButton {
                            visible: page.semitones !== 0
                            text: "Original"
                            flat: true
                            onClicked: page.semitones = 0
                        }
                    }
                    Flow {
                        width: parent.width
                        spacing: 8
                        SegmentedControl {
                            model: [{ value: "names", label: "Nomes" },
                                    { value: "diagram", label: "Braço" },
                                    { value: "big", label: "Detalhado" },
                                    { value: "tab", label: "Tab" },
                                    { value: "score", label: "Partitura" },
                                    { value: "lesson", label: "Aula" }]
                            current: page.viewMode
                            onActivated: (v) => page.viewMode = v
                        }
                        SegmentedControl {
                            model: [{ value: "0.8", label: "P" },
                                    { value: "1", label: "M" },
                                    { value: "1.4", label: "G" },
                                    { value: "1.8", label: "GG" }]
                            current: String(Theme.chordZoom)
                            onActivated: (v) => Theme.chordZoom = Number(v)
                        }
                        AppButton {
                            text: "Metrônomo"
                            onClicked: page.metroVisible = !page.metroVisible
                        }
                        AppButton {
                            visible: !!(page.song && page.song.video)
                            text: "Vídeo"
                            onClicked: Qt.openUrlExternally(page.song.video)
                        }
                        SegmentedControl {
                            visible: page.viewMode === "score"
                            model: [{ value: "chord", label: "Por acorde" },
                                    { value: "full", label: "Música inteira" }]
                            current: page.fullScore ? "full" : "chord"
                            onActivated: (v) => page.fullScore = (v === "full")
                        }
                    }
                }

                // ---- Opções (como o menu dos apps de cifra) ----
                Collapsible {
                    id: optionsGroup
                    width: parent.width
                    title: "Opções"
                    expanded: false
                    summary: [prefs.columns > 1 ? prefs.columns + " colunas" : "",
                              page.capo !== page.songCapo ? "capo " + page.capo : "",
                              page.tuning ? "afinação " + (page.tuning === 1 ? "½ tom abaixo" : "1 tom abaixo") : "",
                              !prefs.showTabs ? "sem tabs" : "", !prefs.showStrums ? "sem batidas" : "",
                              "rolagem " + prefs.scrollSpeed, page.songBpm + " BPM"]
                             .filter(function (x) { return x !== "" }).join(" · ")
                    Card {
                        width: parent.width
                        component Label: Text {
                            Layout.fillWidth: true
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            wrapMode: Text.WordWrap
                        }
                        component Hint: Text {
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                        }
                        RowLayout {
                            width: parent.width
                            Label { text: "Rolagem automática" }
                            AppButton { iconName: "remove"; onClicked: prefs.scrollSpeed = Math.max(1, prefs.scrollSpeed - 1) }
                            Hint { text: "velocidade " + prefs.scrollSpeed; Layout.preferredWidth: 90; horizontalAlignment: Text.AlignHCenter }
                            AppButton { iconName: "add"; onClicked: prefs.scrollSpeed = Math.min(7, prefs.scrollSpeed + 1) }
                            AppButton { text: page.scrolling ? "Parar" : "Rolar"; suggested: !page.scrolling; onClicked: page.scrolling = !page.scrolling }
                        }
                        RowLayout {
                            width: parent.width
                            Label { text: "Dividir em colunas" }
                            SegmentedControl {
                                model: [{ value: "1", label: "1" }, { value: "2", label: "2" }, { value: "3", label: "3" }]
                                current: String(prefs.columns)
                                onActivated: (v) => prefs.columns = Number(v)
                            }
                        }
                        RowLayout {
                            width: parent.width
                            Label { text: "Capotraste" + (page.capo !== page.songCapo ? " (as formas mudam, o som continua o mesmo)" : "") }
                            AppButton { iconName: "remove"; onClicked: page.capo = Math.max(0, page.capo - 1) }
                            Hint { text: page.capo ? page.capo + "ª casa" : "sem capo"; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignHCenter }
                            AppButton { iconName: "add"; onClicked: page.capo = Math.min(11, page.capo + 1) }
                        }
                        RowLayout {
                            width: parent.width
                            Label { text: "Afinação" }
                            SegmentedControl {
                                model: [{ value: "0", label: "Padrão" }, { value: "1", label: "½ tom abaixo" }, { value: "2", label: "1 tom abaixo" }]
                                current: String(page.tuning)
                                onActivated: (v) => page.tuning = Number(v)
                            }
                        }
                        RowLayout {
                            width: parent.width
                            Label { text: "Tablaturas" }
                            SegmentedControl {
                                model: [{ value: "1", label: "Mostrar" }, { value: "0", label: "Esconder" }]
                                current: prefs.showTabs ? "1" : "0"
                                onActivated: (v) => prefs.showTabs = (v === "1")
                            }
                        }
                        RowLayout {
                            width: parent.width
                            Label { text: "Batidas" }
                            SegmentedControl {
                                model: [{ value: "1", label: "Mostrar" }, { value: "0", label: "Esconder" }]
                                current: prefs.showStrums ? "1" : "0"
                                onActivated: (v) => prefs.showStrums = (v === "1")
                            }
                        }
                        RowLayout {
                            width: parent.width
                            Label { text: "Metrônomo (" + page.songBpm + " BPM" + (page.song && (page.song.bpm || page.songBpm !== 80) ? ", da música)" : ", padrão)") }
                            AppButton { text: page.metroVisible ? "Esconder" : "Mostrar"; onClicked: page.metroVisible = !page.metroVisible }
                        }
                        RowLayout {
                            width: parent.width
                            Label { text: "Pedal passador (Page Down / Page Up ou setas)" }
                            SegmentedControl {
                                model: [{ value: "1", label: "Ligado" }, { value: "0", label: "Desligado" }]
                                current: prefs.pedal ? "1" : "0"
                                onActivated: (v) => prefs.pedal = (v === "1")
                            }
                        }
                        Hint {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: "Afinador e Tocar junto usam o microfone e chegam no próximo passo."
                        }
                        AppButton {
                            text: "Restaurar padrões"
                            onClicked: page.restoreDefaults()
                        }
                    }
                }

                // ---- Batidas (fechadas: só as setas) ----
                Collapsible {
                    id: strumsGroup
                    visible: page.usedStrums.length > 0 && prefs.showStrums
                    width: parent.width
                    title: page.usedStrums.length > 1 ? "Batidas" : "Batida"
                    expanded: false
                    summary: page.usedStrums.map(function (s) { return page.arrows(s.pattern) }).join("   |   ")

                    Repeater {
                        model: page.usedStrums
                        Column {
                            id: strumBlock
                            required property var modelData
                            width: strumsGroup.width
                            spacing: 6
                            Text { visible: page.usedStrums.length > 1; text: strumBlock.modelData.name; color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
                            Card {
                                width: parent.width
                                Row {
                                    spacing: 2
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    Repeater {
                                        model: strumBlock.modelData.pattern
                                        Column {
                                            id: beat
                                            required property string modelData
                                            required property int index
                                            width: 44
                                            spacing: 2
                                            Text {
                                                width: parent.width
                                                horizontalAlignment: Text.AlignHCenter
                                                text: beat.modelData === "" ? "·" : beat.modelData === "U" ? "↑" : "↓"
                                                color: beat.modelData === "" ? Theme.textDim
                                                     : beat.modelData === "X" ? Theme.textDim : Theme.accent
                                                font.pixelSize: 26
                                                font.weight: Font.Bold
                                            }
                                            Text {
                                                width: parent.width
                                                horizontalAlignment: Text.AlignHCenter
                                                text: ({ "B": "baixo", "D": "tudo", "d": "acorde", "U": "agudas", "X": "abafa" })[beat.modelData] || " "
                                                color: Theme.text
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                            }
                                            Text {
                                                width: parent.width
                                                horizontalAlignment: Text.AlignHCenter
                                                text: strumBlock.modelData.counts[beat.index] || ""
                                                color: Theme.textDim
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSize - 2
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                }

                // ---- Partitura da música inteira ----
                Card {
                    id: fullScoreCard
                    visible: page.showFullScore
                    width: parent.width
                    padding: 10
                    readonly property int perRow: Math.max(1, Math.floor((width - 20 - 48 * page.zoom) / (190 * page.zoom)))
                    Repeater {
                        model: page.showFullScore ? page.scoreBlocks : []
                        Column {
                            id: block
                            required property var modelData
                            width: fullScoreCard.width - 20
                            Repeater {
                                model: block.modelData.tab ? 0 : Math.ceil(block.modelData.measures.length / fullScoreCard.perRow)
                                ScoreRow {
                                    required property int index
                                    width: block.width
                                    height: implicitHeight
                                    measures: block.modelData.measures.slice(index * fullScoreCard.perRow,
                                                                             (index + 1) * fullScoreCard.perRow)
                                    pattern: ["D"]
                                    slots: fullScoreCard.perRow
                                    semitones: page.shift
                                    zoom: page.zoom
                                }
                            }
                            TabScore {
                                visible: !!block.modelData.tab
                                width: block.width
                                height: implicitHeight
                                tab: block.modelData.tab || ""
                                label: block.modelData.label || ""
                                startNumber: block.modelData.start || 0
                                keyName: page.song ? page.t(page.song.key) : "C"
                                zoom: page.zoom
                            }
                        }
                    }
                }


                // ---- Seções ----
                RowLayout {
                    visible: !page.showFullScore && !!page.song && page.song.sections.length > 1
                    width: parent.width
                    Text {
                        Layout.fillWidth: true
                        text: "Partes"
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                    }
                    AppButton { text: "Abrir todas"; flat: true; onClicked: page.setAll(true) }
                    AppButton { text: "Fechar todas"; flat: true; onClicked: page.setAll(false) }
                }
                Grid {
                    id: secGrid
                    width: content.width
                    columns: Math.max(1, Math.min(prefs.columns, Math.floor(content.width / 330)))
                    columnSpacing: 16
                    rowSpacing: 14
                    Repeater {
                        model: page.song && !page.showFullScore ? page.song.sections : []
                        Collapsible {
                            id: section
                            required property var modelData
                            required property int index
                            readonly property var strum: Examples.strumOf(page.song, modelData)
                            readonly property string sameAs: page.sameAs(index)
                            width: (secGrid.width - (secGrid.columns - 1) * secGrid.columnSpacing) / secGrid.columns
                            title: modelData.name
                            badge: modelData.repeat > 1 ? modelData.repeat + "×" : ""
                            summary: (sameAs ? "igual a " + sameAs + " · " : "") + page.chordList(modelData)
                            expanded: sameAs === ""
                            Connections {
                                target: page
                                function onSetAll(open) { section.expanded = open }
                            }

                            Card {
                                width: parent.width
                                TabText {
                                    visible: prefs.showTabs && !!section.modelData.tab && ["tab", "score", "lesson"].indexOf(page.viewMode) < 0
                                    width: parent.width
                                    tab: section.modelData.tab || ""
                                    zoom: page.zoom
                                }
                                LessonTab {
                                    visible: prefs.showTabs && !!section.modelData.tab && page.viewMode === "lesson"
                                    width: parent.width
                                    height: implicitHeight
                                    tab: visible ? section.modelData.tab : ""
                                    song: page.song
                                    semitones: page.shift
                                    capo: page.capo
                                    bpm: section.strum && section.strum.bpm ? section.strum.bpm : page.songBpm
                                    zoom: page.zoom
                                    onBeat: (strong) => (strong ? ticForte : ticFraco).play()
                                }
                                TabScore {
                                    visible: prefs.showTabs && !!section.modelData.tab && (page.viewMode === "tab" || page.viewMode === "score")
                                    width: parent.width
                                    height: implicitHeight
                                    tab: visible ? section.modelData.tab : ""
                                    keyName: page.song ? page.t(page.song.key) : "C"
                                    zoom: page.zoom
                                }
                                Flow {
                                    visible: section.modelData.chords.length > 0
                                    width: parent.width
                                    spacing: 8
                                    Repeater {
                                        model: section.modelData.chords
                                        Rectangle {
                                            id: chordBox
                                            required property string modelData
                                            readonly property string chordName: Examples.chordName(modelData)
                                            readonly property var voicing: Examples.voicing(page.song, modelData)
                                            readonly property real zm: page.zoom
                                            readonly property bool diag: page.chordMode === "diagram" && diagram.visible
                                            readonly property bool tab: page.chordMode === "tab" && strumTab.visible
                                            readonly property bool big: page.chordMode === "big" && bigDiagram.visible
                                            readonly property bool score: page.chordMode === "score" && notation.visible
                                            readonly property real contentW: diag ? diagram.implicitWidth * zm : tab ? strumTab.implicitWidth * zm
                                                                           : big ? bigDiagram.implicitWidth * zm
                                                                           : score ? notation.implicitWidth : 0
                                            readonly property real contentH: diag ? diagram.implicitHeight * zm : tab ? strumTab.implicitHeight * zm
                                                                           : big ? bigDiagram.implicitHeight * zm
                                                                           : score ? notation.implicitHeight : 0
                                            width: Math.max(64 * zm, contentW + 16, chordText.implicitWidth + 24)
                                            height: contentH > 0 ? chordText.implicitHeight + contentH + 24 : chordText.implicitHeight + 20
                                            radius: Theme.radiusSmall
                                            color: Qt.rgba(Theme.chord.r, Theme.chord.g, Theme.chord.b, Theme.dark ? 0.16 : 0.09)
                                            Text {
                                                id: chordText
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                y: chordBox.contentH > 0 ? 8 : (parent.height - height) / 2
                                                text: page.t(chordBox.chordName)
                                                color: Theme.chord
                                                font.family: Theme.monoFamily
                                                font.pixelSize: (Theme.fontSize + 4) * chordBox.zm
                                                font.weight: Font.Bold
                                            }
                                            ChordDiagram {
                                                id: diagram
                                                scale: chordBox.zm
                                                transformOrigin: Item.Top
                                                visible: page.chordMode === "diagram" && shape !== null
                                                chord: chordBox.chordName
                                                voicing: chordBox.voicing
                                                semitones: page.shift
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.horizontalCenterOffset: -4
                                                anchors.top: chordText.bottom
                                                anchors.topMargin: 6
                                            }
                                            BigChordDiagram {
                                                id: bigDiagram
                                                scale: chordBox.zm
                                                transformOrigin: Item.Top
                                                visible: page.chordMode === "big" && shape !== null
                                                chord: chordBox.chordName
                                                voicing: chordBox.voicing
                                                semitones: page.shift
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.horizontalCenterOffset: -8
                                                anchors.top: chordText.bottom
                                                anchors.topMargin: 8
                                            }
                                            NotationView {
                                                id: notation
                                                zoom: chordBox.zm
                                                visible: page.chordMode === "score" && shape !== null
                                                width: implicitWidth
                                                height: implicitHeight
                                                chord: chordBox.chordName
                                                voicing: chordBox.voicing
                                                semitones: page.shift
                                                pattern: section.strum ? section.strum.pattern : ["D"]
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.top: chordText.bottom
                                                anchors.topMargin: 4
                                            }
                                            StrumTab {
                                                id: strumTab
                                                scale: chordBox.zm
                                                transformOrigin: Item.Top
                                                visible: page.chordMode === "tab" && shape !== null
                                                chord: chordBox.chordName
                                                voicing: chordBox.voicing
                                                semitones: page.shift
                                                pattern: section.strum ? section.strum.pattern : ["D"]
                                                counts: section.strum ? section.strum.counts : []
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.top: chordText.bottom
                                                anchors.topMargin: 6
                                            }
                                        }
                                    }
                                }
                                Text {
                                    visible: !!section.modelData.note
                                    text: section.modelData.note || ""
                                    color: Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 1
                                    font.italic: true
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: !!page.song && !page.song.id
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "A letra não está incluída porque tem direitos autorais. Acompanhe pelo vídeo."
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    // Metrônomo flutuante, no canto, sem tapar a cifra.
    Rectangle {
        visible: page.metroVisible
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 16
        width: metroRow.implicitWidth + 24
        height: metroRow.implicitHeight + 20
        radius: Theme.radius
        color: Theme.card
        border.width: 1
        border.color: Theme.border
        RowLayout {
            id: metroRow
            anchors.centerIn: parent
            spacing: 8
            Row {
                spacing: 5
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        width: 12; height: 12; radius: 6
                        color: metro.running && ((metro.beat % 4) + 4) % 4 === index
                               ? (index === 0 ? Theme.chord : Theme.accent) : Theme.button
                    }
                }
            }
            AppButton { iconName: "remove"; onClicked: { metro.bpm = Math.max(30, metro.bpm - 2); metro.t0 = Date.now(); metro.beat = -1 } }
            Text {
                text: metro.bpm + " BPM"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 1
                font.weight: Font.Bold
            }
            AppButton { iconName: "add"; onClicked: { metro.bpm = Math.min(240, metro.bpm + 2); metro.t0 = Date.now(); metro.beat = -1 } }
            AppButton { text: metro.running ? "Parar" : "Tocar"; suggested: !metro.running; onClicked: page.toggleMetro() }
            AppButton {
                visible: metro.bpm !== page.songBpm
                text: "BPM da música"
                flat: true
                onClicked: { metro.bpm = page.songBpm; metro.t0 = Date.now(); metro.beat = -1 }
            }
        }
    }
}
