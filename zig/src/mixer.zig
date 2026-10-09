//! Mistura dos efeitos sonoros em PCM 16 bits estereo.
//!
//! O Java abre um `Clip` novo a cada `Sound.play`, entao o mesmo som pode
//! tocar sobreposto. Aqui cada som tem `copies` vozes usadas em rodizio:
//! tocar de novo uma voz ocupada a reinicia (como os aliases do raylib).
//!
//! `play` pode ser chamado de qualquer thread; so a thread de audio chama
//! `render` e mexe nas vozes. O unico estado compartilhado sao os contadores
//! atomicos de pedidos.

const std = @import("std");
const wav = @import("wav.zig");

pub const copies = 4;
pub const max_sounds = 8;

const Voice = struct {
    /// Proximo quadro a tocar.
    pos: usize = 0,
    active: bool = false,
};

pub const Mixer = struct {
    sounds: []const wav.Pcm,
    voices: [max_sounds][copies]Voice = @splat(@splat(.{})),
    next: [max_sounds]u8 = @splat(0),
    pending: [max_sounds]std.atomic.Value(u32) = @splat(.init(0)),

    pub fn init(sounds: []const wav.Pcm) Mixer {
        std.debug.assert(sounds.len <= max_sounds);
        return .{ .sounds = sounds };
    }

    /// Pede para tocar o som `id` desde o comeco.
    pub fn play(self: *Mixer, id: usize) void {
        _ = self.pending[id].fetchAdd(1, .release);
    }

    fn startPending(self: *Mixer) void {
        for (0..self.sounds.len) |id| {
            const requests = @min(self.pending[id].swap(0, .acquire), copies);
            for (0..requests) |_| {
                self.voices[id][self.next[id]] = .{ .active = true };
                self.next[id] = (self.next[id] + 1) % copies;
            }
        }
    }

    /// Preenche `out` (amostras intercaladas esquerda/direita) com a soma das
    /// vozes ativas, saturando em 16 bits.
    pub fn render(self: *Mixer, out: []i16) void {
        self.startPending();

        const block = 512;
        const frames = out.len / wav.channels;
        var done: usize = 0;
        while (done < frames) {
            const n: usize = @min(frames - done, block);
            var sum: [block * wav.channels]i32 = @splat(0);
            for (self.sounds, 0..) |pcm, id| {
                for (&self.voices[id]) |*voice| {
                    if (!voice.active) continue;
                    const count = @min(n, pcm.frames() - voice.pos);
                    for (0..count) |f| {
                        sum[f * 2] += pcm.sample(voice.pos + f, 0);
                        sum[f * 2 + 1] += pcm.sample(voice.pos + f, 1);
                    }
                    voice.pos += count;
                    if (voice.pos >= pcm.frames()) voice.active = false;
                }
            }
            for (out[done * wav.channels ..][0 .. n * wav.channels], sum[0 .. n * wav.channels]) |*o, s| {
                o.* = @intCast(std.math.clamp(s, std.math.minInt(i16), std.math.maxInt(i16)));
            }
            done += n;
        }
    }

    fn activeVoices(self: *const Mixer, id: usize) usize {
        var count: usize = 0;
        for (self.voices[id]) |voice| count += @intFromBool(voice.active);
        return count;
    }
};

const testing = std.testing;

fn pcmOf(comptime samples: []const i16) wav.Pcm {
    return .{ .data = std.mem.sliceAsBytes(samples) };
}

test "sem som tocando gera silencio" {
    var mixer: Mixer = .init(&.{pcmOf(&.{ 1, 2 })});
    var out: [8]i16 = @splat(99);
    mixer.render(&out);
    try testing.expectEqualSlices(i16, &@as([8]i16, @splat(0)), &out);
}

test "toca o som e termina" {
    var mixer: Mixer = .init(&.{pcmOf(&.{ 1, -1, 2, -2, 3, -3 })});
    mixer.play(0);
    var out: [4]i16 = undefined;
    mixer.render(&out);
    try testing.expectEqualSlices(i16, &.{ 1, -1, 2, -2 }, &out);
    mixer.render(&out);
    try testing.expectEqualSlices(i16, &.{ 3, -3, 0, 0 }, &out);
    try testing.expectEqual(@as(usize, 0), mixer.activeVoices(0));
}

test "soma sons diferentes e satura" {
    var mixer: Mixer = .init(&.{ pcmOf(&.{ 30000, -30000, 10, 20 }), pcmOf(&.{ 30000, -30000, 5, 5 }) });
    mixer.play(0);
    mixer.play(1);
    var out: [4]i16 = undefined;
    mixer.render(&out);
    try testing.expectEqualSlices(i16, &.{ 32767, -32768, 15, 25 }, &out);
}

test "buffers maiores que um bloco" {
    const samples = comptime blk: {
        @setEvalBranchQuota(10000);
        var s: [3000 * 2]i16 = undefined;
        for (&s, 0..) |*v, i| v.* = @intCast(i % 1000);
        break :blk s;
    };
    var mixer: Mixer = .init(&.{pcmOf(&samples)});
    mixer.play(0);
    var out: [4096]i16 = undefined;
    mixer.render(&out);
    try testing.expectEqualSlices(i16, samples[0..4096], &out);
    mixer.render(&out);
    try testing.expectEqualSlices(i16, samples[4096..], out[0 .. samples.len - 4096]);
    try testing.expectEqual(@as(i16, 0), out[samples.len - 4096]);
}

test "o mesmo som sobrepoe ate quatro vozes" {
    var mixer: Mixer = .init(&.{pcmOf(&.{ 1, 1, 2, 2, 3, 3 })});
    mixer.play(0);
    var out: [2]i16 = undefined;
    mixer.render(&out);
    try testing.expectEqualSlices(i16, &.{ 1, 1 }, &out);
    // Segunda voz comeca enquanto a primeira esta no quadro 1.
    mixer.play(0);
    mixer.render(&out);
    try testing.expectEqualSlices(i16, &.{ 2 + 1, 2 + 1 }, &out);

    for (0..5) |_| mixer.play(0);
    mixer.render(&out);
    try testing.expectEqual(@as(usize, copies), mixer.activeVoices(0));
    try testing.expectEqualSlices(i16, &.{ 4 * 1, 4 * 1 }, &out);
}
