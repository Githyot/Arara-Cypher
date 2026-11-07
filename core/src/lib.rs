//! Núcleo do AraraCypher: tudo que não depende de interface.
//!
//! Este crate é Rust puro, para poder ser testado com `cargo test`
//! sem precisar do Qt instalado.

pub mod chord;

pub use chord::{Accidental, Chord, Note, ParseChordError};
