pragma Singleton
import QtQuick

// Músicas de exemplo, só com informação musical (acordes, seções, batida).
// A letra fica de fora de propósito: ela tem direitos autorais.
// No passo 2 isto vira o formato de arquivo de verdade da biblioteca.
QtObject {
    readonly property var songs: [
        {
            title: "I Feel So Good Today",
            artist: "Charlie Brown Jr.",
            key: "C#",
            video: "https://www.youtube.com/watch?v=GZgcJF1Ef0A",
            source: "Aula do canal Cifra Music (François Marçal)",
            strum: {
                name: "Sugestão de batida (pop rock)",
                pattern: ["↓", "", "↓", "↑", "", "↑", "↓", "↑"],
                counts: ["1", "e", "2", "e", "3", "e", "4", "e"]
            },
            sections: [
                { name: "Intro", repeat: 5, chords: ["Fm7", "C#5", "Bb9(7)", "F#5(9)"] },
                { name: "Parte A", repeat: 1, chords: ["Fm7", "C#5", "Bb9(7)", "F#5(9)"] },
                { name: "Parte B", repeat: 1, chords: ["C#5", "G#5", "F5", "Bb5", "G#5"] },
                { name: "Solo", repeat: 1, note: "Riff de uma nota só sobre a base", chords: ["Fm7", "C#5", "Bb9(7)", "F#5(9)"] },
                { name: "Parte A (variação)", repeat: 1, chords: ["Fm7", "F#5", "Bb9(7)", "F#5(9)", "Fm7", "C#5", "Bb9(7)", "F#5(9)"] },
                { name: "Parte B", repeat: 1, chords: ["C#5", "G#5", "F5", "Bb5", "G#5"] },
                { name: "Final", repeat: 1, chords: ["Fm7", "C#5", "Bb9(7)", "F#5(9)", "Fm7", "C#5", "Bb9(7)"] }
            ]
        }
    ]
}
