//! Testes da logica pura (`zig build test`): nada aqui abre janela nem
//! dispositivo de audio.

test {
    _ = @import("rules.zig");
    _ = @import("camera.zig");
    _ = @import("canvas.zig");
    _ = @import("png.zig");
    _ = @import("ttf.zig");
}
