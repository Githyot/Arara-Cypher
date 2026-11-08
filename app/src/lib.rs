//! Ponte entre o núcleo em Rust e a interface em QML.

pub mod bridge;

/// Para o microfone (cpp/mic.cpp): frequência da nota que está soando, ou 0.
///
/// # Safety
/// `ptr` deve apontar para `len` amostras válidas.
#[no_mangle]
pub unsafe extern "C" fn arara_pitch(ptr: *const f32, len: usize, rate: u32) -> f32 {
    if ptr.is_null() {
        return 0.0;
    }
    let x = std::slice::from_raw_parts(ptr, len);
    araracypher_core::pitch::detect(x, rate).unwrap_or(0.0)
}

/// Para o microfone: força de cada uma das 12 notas (Dó = 0) em `out[0..12]`.
///
/// # Safety
/// `ptr` deve apontar para `len` amostras válidas e `out` para 12 floats.
#[no_mangle]
pub unsafe extern "C" fn arara_chroma(ptr: *const f32, len: usize, rate: u32, out: *mut f32) {
    if ptr.is_null() || out.is_null() {
        return;
    }
    let x = std::slice::from_raw_parts(ptr, len);
    let c = araracypher_core::pitch::chroma(x, rate);
    std::slice::from_raw_parts_mut(out, 12).copy_from_slice(&c);
}
