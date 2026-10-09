//! Leitura de arquivos WAV (o `AudioSystem.getAudioInputStream` do Java).
//!
//! O mixer trabalha num formato fixo, PCM de 16 bits, estereo, 44100 Hz, que
//! e o formato de todos os sons do jogo. Como os WAVs ficam embutidos, `parse`
//! roda em tempo de compilacao e um arquivo em outro formato quebra o build.

const std = @import("std");

pub const sample_rate = 44100;
pub const channels = 2;
pub const bytes_per_frame = channels * 2;

pub const Error = error{ InvalidWav, Unsupported };

/// Amostras PCM 16 bits little-endian intercaladas (esquerda, direita).
pub const Pcm = struct {
    data: []const u8,

    pub fn frames(self: Pcm) usize {
        return self.data.len / bytes_per_frame;
    }

    /// Amostra do canal `channel` no quadro `frame`.
    pub fn sample(self: Pcm, frame: usize, channel: usize) i16 {
        const offset = (frame * channels + channel) * 2;
        return std.mem.readInt(i16, self.data[offset..][0..2], .little);
    }
};

fn readU16(bytes: []const u8) u16 {
    return std.mem.readInt(u16, bytes[0..2], .little);
}

fn readU32(bytes: []const u8) u32 {
    return std.mem.readInt(u32, bytes[0..4], .little);
}

pub fn parse(bytes: []const u8) Error!Pcm {
    if (bytes.len < 12 or !std.mem.eql(u8, bytes[0..4], "RIFF") or !std.mem.eql(u8, bytes[8..12], "WAVE")) {
        return error.InvalidWav;
    }

    var format_ok = false;
    var pos: usize = 12;
    // Os chunks `LIST`/`id3 ` podem vir antes ou depois do `data`.
    while (pos + 8 <= bytes.len) {
        const id = bytes[pos..][0..4];
        const size = readU32(bytes[pos + 4 ..]);
        const body_start = pos + 8;
        const body = bytes[body_start..][0..@min(size, bytes.len - body_start)];

        if (std.mem.eql(u8, id, "fmt ")) {
            if (body.len < 16) return error.InvalidWav;
            const tag = readU16(body[0..]);
            if (tag != 1 or readU16(body[2..]) != channels or readU32(body[4..]) != sample_rate or readU16(body[14..]) != 16) {
                return error.Unsupported;
            }
            format_ok = true;
        } else if (std.mem.eql(u8, id, "data")) {
            if (!format_ok) return error.InvalidWav;
            return .{ .data = body[0 .. body.len - body.len % bytes_per_frame] };
        }
        // Chunks de tamanho impar tem um byte de preenchimento.
        pos = body_start + @as(usize, size) + size % 2;
    }
    return error.InvalidWav;
}

const testing = std.testing;

test "le os sons do jogo" {
    const assets = @import("assets");
    const cases = [_]struct { []const u8, usize, [2]i16 }{
        .{ assets.som_menu, 14848, .{ -67, -6 } },
        .{ assets.som_select, 91008, .{ 0, 0 } },
        .{ assets.som_menino, 54164, .{ -1, -23 } },
        .{ assets.som_monstro, 9152, .{ 0, 0 } },
    };
    for (cases) |case| {
        const pcm = try parse(case[0]);
        try testing.expectEqual(case[1], pcm.frames());
        try testing.expectEqual(case[2][0], pcm.sample(0, 0));
        try testing.expectEqual(case[2][1], pcm.sample(0, 1));
    }
    // Funciona em tempo de compilacao, como `sound.zig` usa.
    const menu = comptime parse(assets.som_menu) catch unreachable;
    try testing.expectEqual(@as(usize, 14848), menu.frames());
}

test "pula chunks de tamanho impar e rejeita outros formatos" {
    const fmt = "fmt " ++ "\x10\x00\x00\x00" ++ "\x01\x00\x02\x00" ++ "\x44\xac\x00\x00" ++ "\x10\xb1\x02\x00" ++ "\x04\x00\x10\x00";
    const list = "LIST" ++ "\x03\x00\x00\x00" ++ "abc" ++ "\x00";
    const data = "data" ++ "\x04\x00\x00\x00" ++ "\x01\x00\xff\xff";
    const body = "WAVE" ++ fmt ++ list ++ data;
    const file = "RIFF" ++ "\x00\x00\x00\x00" ++ body;
    const pcm = try parse(file);
    try testing.expectEqual(@as(usize, 1), pcm.frames());
    try testing.expectEqual(@as(i16, 1), pcm.sample(0, 0));
    try testing.expectEqual(@as(i16, -1), pcm.sample(0, 1));

    const mono = "RIFF" ++ "\x00\x00\x00\x00" ++ "WAVE" ++ "fmt " ++ "\x10\x00\x00\x00" ++ "\x01\x00\x01\x00" ++ "\x44\xac\x00\x00" ++ "\x88\x58\x01\x00" ++ "\x02\x00\x10\x00" ++ data;
    try testing.expectError(error.Unsupported, parse(mono));
    try testing.expectError(error.InvalidWav, parse("RIFF\x00\x00\x00\x00WAVE"));
    try testing.expectError(error.InvalidWav, parse("nada"));
}
