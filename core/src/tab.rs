//! Leitura de tablatura em texto (o formato de sites e aulas):
//!
//! ```text
//! e|-----------------|
//! B|-----------------|
//! G|------8--6-5-----|
//! D|----6------------|
//! A|-8-8-------------|
//! E|-----------------|
//! ```
//!
//! Cada coluna com número vira um evento (uma nota, ou várias tocadas juntas);
//! `|` no meio da linha vira barra de compasso. Números de dois dígitos
//! (`10`, `12`) contam como uma nota só. Técnicas (`h`, `p`, `/`, `\`, `b`, `~`)
//! ficam guardadas na nota seguinte para a interface mostrar.

use serde::Serialize;

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct TabNote {
    /// Corda: 0 = Mi grave ... 5 = Mi agudo.
    pub string: u8,
    pub fret: u8,
    /// Técnica que liga a nota anterior a esta ("h", "p", "/", "\\", "b", "~"), ou vazio.
    #[serde(skip_serializing_if = "String::is_empty")]
    pub tech: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(untagged)]
pub enum TabEvent {
    Notes { notes: Vec<TabNote> },
    Bar { bar: bool },
}

/// Lê todo o texto (pode ter vários blocos de 6 linhas) e devolve os eventos em ordem.
pub fn parse(text: &str) -> Vec<TabEvent> {
    let mut out: Vec<TabEvent> = Vec::new();
    let mut block: Vec<(Option<char>, &str)> = Vec::new();
    for raw in text.lines() {
        match split_line(raw) {
            Some(line) => block.push(line),
            None => {
                flush(&mut block, &mut out);
            }
        }
    }
    flush(&mut block, &mut out);
    // Sem barras sobrando nas pontas.
    while matches!(out.last(), Some(TabEvent::Bar { .. })) {
        out.pop();
    }
    while matches!(out.first(), Some(TabEvent::Bar { .. })) {
        out.remove(0);
    }
    out
}

pub fn parse_json(text: &str) -> String {
    serde_json::to_string(&parse(text)).unwrap_or_else(|_| "[]".into())
}

/// "e|--3--|" -> (Some('e'), "--3--|"). Linhas sem "|" depois de uma letra de corda não são tab.
fn split_line(raw: &str) -> Option<(Option<char>, &str)> {
    let line = raw.trim();
    let bar = line.find('|')?;
    let label = line[..bar].trim();
    let letter = match label.chars().count() {
        0 => None,
        1 => {
            let c = label.chars().next().unwrap();
            if !"EADGBeadgb".contains(c) {
                return None;
            }
            Some(c)
        }
        _ => return None,
    };
    let body = &line[bar + 1..];
    if !body.contains('-') {
        return None;
    }
    Some((letter, body))
}

fn string_index(letter: Option<char>, line: usize, lines: usize) -> Option<u8> {
    if lines == 6 {
        // Bloco completo: de cima para baixo é Mi agudo ... Mi grave.
        return Some(5 - line as u8);
    }
    Some(match letter? {
        'e' => 5,
        'B' | 'b' => 4,
        'G' | 'g' => 3,
        'D' | 'd' => 2,
        'A' | 'a' => 1,
        'E' => {
            if line == 0 {
                5
            } else {
                0
            }
        }
        _ => return None,
    })
}

fn flush(block: &mut Vec<(Option<char>, &str)>, out: &mut Vec<TabEvent>) {
    if block.is_empty() {
        return;
    }
    let lines = block.len().min(6);
    // Coluna -> notas que começam nela; colunas com barra em alguma linha.
    let width = block
        .iter()
        .map(|(_, b)| b.chars().count())
        .max()
        .unwrap_or(0);
    let mut columns: Vec<Vec<TabNote>> = vec![Vec::new(); width];
    let mut bars = vec![false; width];

    for (i, (letter, body)) in block.iter().take(6).enumerate() {
        let Some(string) = string_index(*letter, i, lines) else {
            continue;
        };
        let chars: Vec<char> = body.chars().collect();
        let mut c = 0;
        let mut tech = String::new();
        while c < chars.len() {
            let ch = chars[c];
            if ch.is_ascii_digit() {
                let start = c;
                let mut n = 0u32;
                while c < chars.len() && chars[c].is_ascii_digit() && c - start < 2 {
                    n = n * 10 + chars[c].to_digit(10).unwrap();
                    c += 1;
                }
                if n <= 24 {
                    columns[start].push(TabNote {
                        string,
                        fret: n as u8,
                        tech: std::mem::take(&mut tech),
                    });
                }
                continue;
            }
            match ch {
                '|' => {
                    // A barra final da linha não conta como compasso no meio.
                    if c + 1 < chars.len() {
                        bars[c] = true;
                    }
                }
                'h' | 'p' | '/' | '\\' | 'b' | '~' => tech = ch.to_string(),
                '-' | ' ' => {}
                _ => {}
            }
            c += 1;
        }
    }

    if !out.is_empty() && !matches!(out.last(), Some(TabEvent::Bar { .. })) {
        out.push(TabEvent::Bar { bar: true });
    }
    for c in 0..width {
        if bars[c] {
            if !matches!(out.last(), Some(TabEvent::Bar { .. })) && !out.is_empty() {
                out.push(TabEvent::Bar { bar: true });
            }
        } else if !columns[c].is_empty() {
            let mut notes = std::mem::take(&mut columns[c]);
            notes.sort_by_key(|n| n.string);
            out.push(TabEvent::Notes { notes });
        }
    }
    block.clear();
}

/// Um bloco da tab para a visualização de aula: notas com a coluna onde
/// aparecem, o acorde escrito em cima e a seta de batida embaixo de cada nota.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct System {
    /// Largura do bloco, em colunas de texto.
    pub width: usize,
    pub chords: Vec<LessonChord>,
    pub events: Vec<LessonEvent>,
    /// Colunas com barra de compasso no meio da linha.
    pub bars: Vec<usize>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct LessonChord {
    pub col: usize,
    pub name: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct LessonEvent {
    pub col: usize,
    pub notes: Vec<TabNote>,
    /// "D" (para baixo), "U" (para cima) ou vazio.
    #[serde(skip_serializing_if = "String::is_empty")]
    pub arrow: String,
}

pub fn lesson(text: &str) -> Vec<System> {
    let mut out = Vec::new();
    let mut block: Vec<&str> = Vec::new();
    for line in text.lines().chain(std::iter::once("")) {
        if line.trim().is_empty() {
            if let Some(sys) = lesson_block(&block) {
                out.push(sys);
            }
            block.clear();
        } else {
            block.push(line);
        }
    }
    out
}

pub fn lesson_json(text: &str) -> String {
    serde_json::to_string(&lesson(text)).unwrap_or_else(|_| "[]".into())
}

fn lesson_block(block: &[&str]) -> Option<System> {
    let first_tab = block.iter().position(|l| split_line(l).is_some())?;
    let tab_lines: Vec<(Option<char>, &str)> = block.iter().filter_map(|l| split_line(l)).collect();
    // Onde começa o corpo da tab ("E|" = 2 colunas), para alinhar acordes e setas.
    let offset = block[first_tab].trim_start().find('|')?
        + 1
        + (block[first_tab].len() - block[first_tab].trim_start().len());
    let lines = tab_lines.len().min(6);
    let width = tab_lines
        .iter()
        .map(|(_, b)| b.chars().count())
        .max()
        .unwrap_or(0);
    let mut columns: Vec<Vec<TabNote>> = vec![Vec::new(); width];
    let mut bars = Vec::new();
    for (i, (letter, body)) in tab_lines.iter().take(6).enumerate() {
        let Some(string) = string_index(*letter, i, lines) else {
            continue;
        };
        let chars: Vec<char> = body.chars().collect();
        let mut c = 0;
        let mut tech = String::new();
        while c < chars.len() {
            let ch = chars[c];
            if ch.is_ascii_digit() {
                let start = c;
                let mut n = 0u32;
                while c < chars.len() && chars[c].is_ascii_digit() && c - start < 2 {
                    n = n * 10 + chars[c].to_digit(10).unwrap();
                    c += 1;
                }
                if n <= 24 {
                    columns[start].push(TabNote {
                        string,
                        fret: n as u8,
                        tech: std::mem::take(&mut tech),
                    });
                }
                continue;
            }
            match ch {
                '|' if c + 1 < chars.len() && c > 0 && !bars.contains(&c) => bars.push(c),
                'h' | 'p' | '/' | '\\' | 'b' | '~' => tech = ch.to_string(),
                _ => {}
            }
            c += 1;
        }
    }
    // Notas de duas casas em cordas diferentes que começam uma coluna depois
    // ("12" em cima de "3") ficam no mesmo evento.
    let mut events: Vec<LessonEvent> = Vec::new();
    for (col, notes) in columns.into_iter().enumerate() {
        if notes.is_empty() {
            continue;
        }
        match events.last_mut() {
            Some(last)
                if col == last.col + 1
                    && !notes
                        .iter()
                        .any(|n| last.notes.iter().any(|m| m.string == n.string)) =>
            {
                last.notes.extend(notes);
            }
            _ => events.push(LessonEvent {
                col,
                notes,
                arrow: String::new(),
            }),
        }
    }
    for e in &mut events {
        e.notes.sort_by_key(|n| n.string);
    }
    bars.sort();

    let body_col = |i: usize| i.checked_sub(offset);
    let mut chords = Vec::new();
    for line in &block[..first_tab] {
        if crate::sheet::chord_line(line.trim()).is_none() {
            continue;
        }
        let chars: Vec<char> = line.chars().collect();
        let mut i = 0;
        while i < chars.len() {
            if chars[i].is_whitespace() {
                i += 1;
                continue;
            }
            let start = i;
            while i < chars.len() && !chars[i].is_whitespace() {
                i += 1;
            }
            let word: String = chars[start..i].iter().collect();
            if crate::sheet::is_chord_token(&word) {
                chords.push(LessonChord {
                    col: body_col(start).unwrap_or(0),
                    name: word,
                });
            }
        }
    }
    let last_tab = block.iter().rposition(|l| split_line(l).is_some())?;
    for line in &block[last_tab + 1..] {
        if !crate::sheet::is_arrow_line(line) {
            continue;
        }
        for (i, ch) in line.chars().enumerate() {
            let arrow = match ch {
                '↓' | '⇣' => "D",
                '↑' | '⇡' => "U",
                _ => continue,
            };
            let Some(col) = body_col(i) else { continue };
            // A nota mais próxima (até 3 colunas) que ainda não tem seta.
            if let Some(e) = events
                .iter_mut()
                .filter(|e| e.arrow.is_empty() && e.col.abs_diff(col) <= 3)
                .min_by_key(|e| e.col.abs_diff(col))
            {
                e.arrow = arrow.into();
            }
        }
    }
    Some(System {
        width,
        chords,
        events,
        bars,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn frets(ev: &[TabEvent]) -> Vec<String> {
        ev.iter()
            .map(|e| match e {
                TabEvent::Bar { .. } => "|".to_string(),
                TabEvent::Notes { notes } => notes
                    .iter()
                    .map(|n| format!("{}:{}{}", n.string, n.tech, n.fret))
                    .collect::<Vec<_>>()
                    .join("+"),
            })
            .collect()
    }

    #[test]
    fn reads_single_notes_and_two_digit_frets() {
        let t = "\
E|-----------------------|
B|-----------------------|
G|------8--6-5-----------|
D|----6---------8/10-----|
A|-8-8-------------------|
E|-----------------------|";
        let ev = parse(t);
        assert_eq!(
            frets(&ev),
            ["1:8", "1:8", "2:6", "3:8", "3:6", "3:5", "2:8", "2:/10"]
        );
    }

    #[test]
    fn lesson_blocks_with_chords_and_arrows() {
        let t = concat!(
            "   Em7(9)     D\n",
            "E|------------|\n",
            "B|------------|\n",
            "G|----12------|\n",
            "D|----13------|\n",
            "A|------------|\n",
            "E|--0-----11--|\n",
            "    ↓ ↑   ↓\n",
            "\n",
            "   Bm\n",
            "E|--2--|"
        );
        let l = lesson(t);
        assert_eq!(l.len(), 2);
        let a = &l[0];
        assert_eq!(
            a.chords[0],
            LessonChord {
                col: 1,
                name: "Em7(9)".into()
            }
        );
        assert_eq!(a.chords[1].name, "D");
        assert_eq!(a.events.len(), 3);
        assert_eq!((a.events[0].col, a.events[0].arrow.as_str()), (2, "D"));
        assert_eq!(a.events[1].notes.len(), 2);
        assert_eq!(a.events[1].arrow, "U");
        assert_eq!(a.events[2].arrow, "D");
        assert_eq!(l[1].events[0].notes[0].fret, 2);
    }

    #[test]
    fn chords_bars_and_blocks() {
        let t = "\
e|--0--|--3--|
B|--1--|--0--|
G|--0--|--0--|
D|--2--|--0--|
A|--3--|--2--|
E|-----|--3--|

e|-5-|
B|---|
G|---|
D|---|
A|---|
E|---|";
        let ev = parse(t);
        assert_eq!(
            frets(&ev),
            [
                "1:3+2:2+3:0+4:1+5:0",
                "|",
                "0:3+1:2+2:0+3:0+4:0+5:3",
                "|",
                "5:5"
            ]
        );
        assert!(parse("Uma linha de letra\nE outra").is_empty());
        assert_eq!(
            parse_json("e|-3-|\nB|---|\nG|---|\nD|---|\nA|---|\nE|---|"),
            r#"[{"notes":[{"string":5,"fret":3}]}]"#
        );
    }
}
