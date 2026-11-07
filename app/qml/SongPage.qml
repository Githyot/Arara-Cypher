import QtQuick
import QtQuick.Layouts
import AraraCypher

// Visualização de uma cifra: seções com os acordes, tom e transposição.
// Por enquanto lê as músicas de exemplo; o editor de verdade chega no passo 2.
Rectangle {
    id: page
    property var song
    property int semitones: 0
    property string viewMode: "tab"   // "names" | "diagram" | "tab"
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
                        visible: page.song && page.song.source
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
                                    { value: "tab", label: "Tab" }]
                            current: page.viewMode
                            onActivated: (v) => page.viewMode = v
                        }
                    }
                    AppButton {
                        visible: page.song && page.song.video
                        text: "Assistir à aula no YouTube"
                        suggested: true
                        onClicked: Qt.openUrlExternally(page.song.video)
                    }
                }

                // ---- Batida ----
                Column {
                    width: parent.width
                    spacing: 6
                    visible: page.song && page.song.strum
                    SectionTitle { text: page.song && page.song.strum ? page.song.strum.name : "" }
                    Card {
                        width: parent.width
                        Row {
                            spacing: 2
                            anchors.horizontalCenter: parent.horizontalCenter
                            Repeater {
                                model: page.song && page.song.strum ? page.song.strum.pattern : []
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
                                        text: page.song.strum.counts[beat.index]
                                        color: Theme.textDim
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize - 2
                                    }
                                }
                            }
                        }
                    }
                }

                // ---- Seções ----
                Repeater {
                    model: page.song ? page.song.sections : []
                    Column {
                        id: section
                        required property var modelData
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
                                        readonly property bool diag: page.viewMode === "diagram" && diagram.visible
                                        readonly property bool tab: page.viewMode === "tab" && strumTab.visible
                                        readonly property real contentW: diag ? diagram.implicitWidth : tab ? strumTab.implicitWidth : 0
                                        readonly property real contentH: diag ? diagram.implicitHeight : tab ? strumTab.implicitHeight : 0
                                        width: Math.max(64, contentW + 16, chordText.implicitWidth + 24)
                                        height: contentH > 0 ? chordText.implicitHeight + contentH + 24 : 44
                                        radius: Theme.radiusSmall
                                        color: Qt.rgba(Theme.chord.r, Theme.chord.g, Theme.chord.b, Theme.dark ? 0.16 : 0.09)
                                        Text {
                                            id: chordText
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            y: chordBox.contentH > 0 ? 8 : (parent.height - height) / 2
                                            text: page.t(chordBox.modelData)
                                            color: Theme.chord
                                            font.family: Theme.monoFamily
                                            font.pixelSize: Theme.fontSize + 4
                                            font.weight: Font.Bold
                                        }
                                        ChordDiagram {
                                            id: diagram
                                            visible: page.viewMode === "diagram" && shape !== null
                                            chord: chordBox.modelData
                                            semitones: page.semitones
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.horizontalCenterOffset: -4
                                            anchors.top: chordText.bottom
                                            anchors.topMargin: 6
                                        }
                                        StrumTab {
                                            id: strumTab
                                            visible: page.viewMode === "tab" && shape !== null
                                            chord: chordBox.modelData
                                            semitones: page.semitones
                                            pattern: page.song && page.song.strum ? page.song.strum.pattern : ["D"]
                                            counts: page.song && page.song.strum ? page.song.strum.counts : []
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
