import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import AraraCypher

// Visualização de uma cifra: seções com os acordes, tom e transposição.
// Por enquanto lê as músicas de exemplo; o editor de verdade chega no passo 2.
Rectangle {
    id: page
    property var song
    property int semitones: 0
    property string viewMode: "tab"   // "names" | "diagram" | "big" | "tab" | "score"
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

    // Todos os compassos da música em sequência: um por acorde de cada parte.
    readonly property var allMeasures: {
        var out = []
        if (!song) return out
        var n = 1
        for (var i = 0; i < song.sections.length; ++i) {
            var sec = song.sections[i]
            for (var j = 0; j < sec.chords.length; ++j) {
                var strum = Examples.strumOf(song, sec)
                out.push({
                    chord: Examples.chordName(sec.chords[j]),
                    voicing: Examples.voicing(song, sec.chords[j]),
                    pattern: strum ? strum.pattern : ["D"],
                    number: n++,
                    label: j === 0 ? sec.name : "",
                    repeat: j === sec.chords.length - 1 && sec.repeat > 1 ? sec.repeat : 0
                })
            }
        }
        return out
    }
    signal back()

    color: Theme.window

    function t(chord) { return Music.transposeChord(chord, semitones) }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        HeaderBar {
            Layout.fillWidth: true
            title: page.song ? page.song.title : ""
            AppButton { text: "Voltar"; flat: true; onClicked: page.back() }
        }

        Flickable {

            ScrollBar.vertical: AppScrollBar {}
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: content.implicitHeight + 2 * Theme.pagePadding
            clip: true

            Column {
                id: content
                y: Theme.pagePadding
                width: Math.min(parent.width - 2 * Theme.pagePadding, 720)
                x: (parent.width - width) / 2
                spacing: 14

                // ---- Cabeçalho da música ----
                Column {
                    width: parent.width
                    spacing: 2
                    Text {
                        text: page.song ? page.song.artist : ""
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize + 2
                    }
                    Text {
                        visible: !!(page.song && page.song.source)
                        text: page.song ? page.song.source : ""
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                    }
                }

                // ---- Tom e transposição ----
                Card {
                    width: parent.width
                    RowLayout {
                        width: parent.width
                        spacing: 8
                        Column {
                            Layout.fillWidth: true
                            Text {
                                text: "Tom"
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 1
                            }
                            Text {
                                text: page.song ? page.t(page.song.key) : ""
                                color: Theme.chord
                                font.family: Theme.monoFamily
                                font.pixelSize: 26
                                font.weight: Font.Bold
                            }
                            Text {
                                visible: !!(page.song && page.song.capo)
                                text: page.song && page.song.capo
                                      ? "Capotraste na " + page.song.capo + "ª casa (soa em "
                                        + Music.transposeChord(page.t(page.song.key), page.song.capo) + ")"
                                      : ""
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 1
                            }
                        }
                        AppButton { iconName: "remove"; onClicked: page.semitones-- }
                        Text {
                            Layout.preferredWidth: 44
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
                    Rectangle { width: parent.width; height: 1; color: Theme.border; opacity: 0.6 }
                    RowLayout {
                        width: parent.width
                        Text {
                            Layout.fillWidth: true
                            text: "Ver acordes como"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                        SegmentedControl {
                            model: [{ value: "names", label: "Nomes" },
                                    { value: "diagram", label: "Braço" },
                                    { value: "big", label: "Detalhado" },
                                    { value: "tab", label: "Tab" },
                                    { value: "score", label: "Partitura" }]
                            current: page.viewMode
                            onActivated: (v) => page.viewMode = v
                        }
                    }
                    RowLayout {
                        width: parent.width
                        Text {
                            Layout.fillWidth: true
                            text: "Tamanho"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                        SegmentedControl {
                            model: [{ value: "0.8", label: "P" },
                                    { value: "1", label: "M" },
                                    { value: "1.4", label: "G" },
                                    { value: "1.8", label: "GG" }]
                            current: String(Theme.chordZoom)
                            onActivated: (v) => Theme.chordZoom = Number(v)
                        }
                    }
                    RowLayout {
                        visible: page.viewMode === "score"
                        width: parent.width
                        Text {
                            Layout.fillWidth: true
                            text: "Partitura"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                        SegmentedControl {
                            model: [{ value: "chord", label: "Por acorde" },
                                    { value: "full", label: "Música inteira" }]
                            current: page.fullScore ? "full" : "chord"
                            onActivated: (v) => page.fullScore = (v === "full")
                        }
                    }
                    AppButton {
                        visible: !!(page.song && page.song.video)
                        text: "Assistir à aula no YouTube"
                        suggested: true
                        onClicked: Qt.openUrlExternally(page.song.video)
                    }
                }

                // ---- Batidas ----
                Repeater {
                    model: page.usedStrums
                    Column {
                        id: strumBlock
                        required property var modelData
                        width: content.width
                        spacing: 6
                        SectionTitle { text: strumBlock.modelData.name }
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

                // ---- Partitura da música inteira ----
                Card {
                    id: fullScoreCard
                    visible: page.showFullScore
                    width: parent.width
                    padding: 10
                    readonly property int perRow: Math.max(1, Math.floor((width - 20 - 48 * page.zoom) / (190 * page.zoom)))
                    Repeater {
                        model: page.showFullScore ? Math.ceil(page.allMeasures.length / fullScoreCard.perRow) : 0
                        ScoreRow {
                            required property int index
                            width: parent.width
                            height: implicitHeight
                            measures: page.allMeasures.slice(index * fullScoreCard.perRow,
                                                             (index + 1) * fullScoreCard.perRow)
                            pattern: ["D"]
                            semitones: page.semitones
                            zoom: page.zoom
                        }
                    }
                }

                // ---- Seções ----
                Repeater {
                    model: page.song && !page.showFullScore ? page.song.sections : []
                    Column {
                        id: section
                        required property var modelData
                        readonly property var strum: Examples.strumOf(page.song, modelData)
                        width: content.width
                        spacing: 6

                        Row {
                            spacing: 8
                            SectionTitle { text: section.modelData.name }
                            Rectangle {
                                visible: section.modelData.repeat > 1
                                anchors.verticalCenter: parent.verticalCenter
                                width: repeatText.implicitWidth + 12
                                height: repeatText.implicitHeight + 4
                                radius: height / 2
                                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
                                Text {
                                    id: repeatText
                                    anchors.centerIn: parent
                                    text: section.modelData.repeat + "×"
                                    color: Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 2
                                    font.weight: Font.Bold
                                }
                            }
                        }

                        Card {
                            width: parent.width
                            Flow {
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
                                        readonly property bool diag: page.viewMode === "diagram" && diagram.visible
                                        readonly property bool tab: page.viewMode === "tab" && strumTab.visible
                                        readonly property bool big: page.viewMode === "big" && bigDiagram.visible
                                        readonly property bool score: page.viewMode === "score" && notation.visible
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
                                            visible: page.viewMode === "diagram" && shape !== null
                                            chord: chordBox.chordName
                                            voicing: chordBox.voicing
                                            semitones: page.semitones
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.horizontalCenterOffset: -4
                                            anchors.top: chordText.bottom
                                            anchors.topMargin: 6
                                        }
                                        BigChordDiagram {
                                            id: bigDiagram
                                            scale: chordBox.zm
                                            transformOrigin: Item.Top
                                            visible: page.viewMode === "big" && shape !== null
                                            chord: chordBox.chordName
                                            voicing: chordBox.voicing
                                            semitones: page.semitones
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.horizontalCenterOffset: -8
                                            anchors.top: chordText.bottom
                                            anchors.topMargin: 8
                                        }
                                        NotationView {
                                            id: notation
                                            zoom: chordBox.zm
                                            visible: page.viewMode === "score" && shape !== null
                                            width: implicitWidth
                                            height: implicitHeight
                                            chord: chordBox.chordName
                                            voicing: chordBox.voicing
                                            semitones: page.semitones
                                            pattern: section.strum ? section.strum.pattern : ["D"]
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.top: chordText.bottom
                                            anchors.topMargin: 4
                                        }
                                        StrumTab {
                                            id: strumTab
                                            scale: chordBox.zm
                                            transformOrigin: Item.Top
                                            visible: page.viewMode === "tab" && shape !== null
                                            chord: chordBox.chordName
                                            voicing: chordBox.voicing
                                            semitones: page.semitones
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

                Text {
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
}
