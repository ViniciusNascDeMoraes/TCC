//! `Main.Sound`: efeitos sonoros.
//!
//! O Java abre um `Clip` novo a cada `Sound.play`, entao o mesmo som pode
//! tocar sobreposto; o `Mixer` faz o mesmo com algumas vozes por som.

const std = @import("std");
const assets = @import("assets");
const wav = @import("wav.zig");
const Mixer = @import("mixer.zig").Mixer;

pub const SoundId = enum {
    /// res/Menu.wav
    menu,
    /// res/Select.wav
    select,
    /// res/Menino.wav
    menino,
    /// res/Monstro.wav
    monstro,
};

/// Os WAVs embutidos, na ordem de `SoundId`, lidos em tempo de compilacao:
/// um arquivo em formato inesperado quebra o build.
pub const pcm = blk: {
    const files = [_]struct { []const u8, []const u8 }{
        .{ "Menu.wav", assets.som_menu },
        .{ "Select.wav", assets.som_select },
        .{ "Menino.wav", assets.som_menino },
        .{ "Monstro.wav", assets.som_monstro },
    };
    std.debug.assert(files.len == std.enums.values(SoundId).len);
    var list: [files.len]wav.Pcm = undefined;
    for (files, &list) |file, *p| {
        p.* = wav.parse(file[1]) catch |err| @compileError("res/" ++ file[0] ++ ": " ++ @errorName(err));
    }
    break :blk list;
};

pub const Sounds = struct {
    /// Sem servidor de audio ninguem consome os pedidos e o som so nao toca,
    /// como o "play sound error" do Java.
    mixer: *Mixer,

    pub fn play(self: Sounds, id: SoundId) void {
        self.mixer.play(@intFromEnum(id));
    }
};
