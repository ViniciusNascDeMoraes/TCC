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
    const files = [_][]const u8{ assets.som_menu, assets.som_select, assets.som_menino, assets.som_monstro };
    var list: [files.len]wav.Pcm = undefined;
    for (files, &list, std.enums.values(SoundId)) |file, *p, id| {
        p.* = wav.parse(file) catch |err| @compileError("res/" ++ @tagName(id) ++ ".wav: " ++ @errorName(err));
    }
    break :blk list;
};

pub const Sounds = struct {
    /// Sem dispositivo de audio o som so nao toca, como o "play sound error" do Java.
    mixer: ?*Mixer = null,

    pub fn play(self: Sounds, id: SoundId) void {
        if (self.mixer) |mixer| mixer.play(@intFromEnum(id));
    }
};
