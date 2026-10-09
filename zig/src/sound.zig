//! `Main.Sound`: efeitos sonoros.
//!
//! O Java abre um `Clip` novo a cada `Sound.play`, entao o mesmo som pode
//! tocar sobreposto. Aqui cada som tem algumas copias (aliases) usadas em
//! rodizio para ter o mesmo efeito.

const rl = @import("raylib");
const assets = @import("assets");

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

const copies = 4;
const count = @typeInfo(SoundId).@"enum".fields.len;

pub const Sounds = struct {
    sources: [count]rl.Sound = undefined,
    aliases: [count][copies - 1]rl.Sound = undefined,
    /// Sem dispositivo de audio (ou com WAV invalido) o som so nao toca,
    /// como o "play sound error" do Java.
    valid: [count]bool = @splat(false),
    next: [count]u8 = @splat(0),

    /// Requer `InitAudioDevice` antes.
    pub fn load() Sounds {
        var self: Sounds = .{};
        if (!rl.IsAudioDeviceReady()) return self;

        const files = [count][]const u8{ assets.som_menu, assets.som_select, assets.som_menino, assets.som_monstro };
        for (files, 0..) |wav, i| {
            const wave = rl.LoadWaveFromMemory(".wav", wav.ptr, @intCast(wav.len));
            defer rl.UnloadWave(wave);
            self.sources[i] = rl.LoadSoundFromWave(wave);
            self.valid[i] = rl.IsSoundValid(self.sources[i]);
            if (!self.valid[i]) continue;
            for (&self.aliases[i]) |*alias| alias.* = rl.LoadSoundAlias(self.sources[i]);
        }
        return self;
    }

    pub fn unload(self: *Sounds) void {
        for (&self.aliases, self.sources, self.valid) |*aliases, source, valid| {
            if (!valid) continue;
            for (aliases) |alias| rl.UnloadSoundAlias(alias);
            rl.UnloadSound(source);
        }
    }

    pub fn play(self: *Sounds, id: SoundId) void {
        const i = @intFromEnum(id);
        if (!self.valid[i]) return;
        const n = self.next[i];
        self.next[i] = (n + 1) % copies;
        rl.PlaySound(if (n == 0) self.sources[i] else self.aliases[i][n - 1]);
    }
};
