//! Núcleo do AraraCypher: tudo que não depende de interface.
//!
//! Este crate é Rust puro, para poder ser testado com `cargo test`
//! sem precisar do Qt instalado.

pub mod chord;
pub mod library;
pub mod ocr;
pub mod rhythm;
pub mod shape;
pub mod sheet;
pub mod sound;
pub mod tab;

pub use chord::{Accidental, Chord, Note, ParseChordError};
pub use shape::{shape_for, ChordShape};
