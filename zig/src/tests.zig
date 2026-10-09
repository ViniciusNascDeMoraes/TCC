//! Testes da logica pura (`zig build test`): nada aqui abre janela nem
//! dispositivo de audio.

const std = @import("std");
const builtin = @import("builtin");

test {
    _ = @import("rules.zig");
    _ = @import("camera.zig");
    _ = @import("canvas.zig");
    _ = @import("png.zig");
    _ = @import("wav.zig");
    _ = @import("mixer.zig");
    _ = @import("raster.zig");
    _ = @import("cff.zig");
    _ = @import("ttf.zig");
    _ = @import("bitmap_font.zig");
    _ = @import("glyphs.zig");
    _ = @import("platform.zig");
    _ = @import("platform/x11_proto.zig");
    _ = @import("audio/pulse_proto.zig");
    // Os backends nao rodam nos testes, mas precisam compilar.
    if (builtin.os.tag == .linux) {
        std.testing.refAllDecls(@import("platform/x11.zig").Window);
        std.testing.refAllDecls(@import("audio.zig").Audio);
    }
}
