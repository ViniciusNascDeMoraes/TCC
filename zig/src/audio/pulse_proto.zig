//! Partes puras do protocolo nativo do PulseAudio (que o pipewire-pulse
//! tambem atende): pacotes, "tagstruct" e os comandos que o jogo usa.
//!
//! Cada pacote tem um descritor de 20 bytes big-endian (tamanho, canal,
//! deslocamento alto/baixo, flags) seguido dos dados. Comandos vao no canal
//! 0xFFFFFFFF como uma tagstruct: cada valor e precedido de um byte de tipo.
//! Os numeros seguem `pulsecore/native-common.h` e `pulsecore/tagstruct.h`.

const std = @import("std");

pub const Error = error{ BadPacket, OutOfMemory };

pub const control_channel = 0xFFFFFFFF;
/// Versao do protocolo anunciada, sem os bits de memoria compartilhada
/// (todo o audio vai pelo proprio socket).
pub const protocol_version = 32;
/// A partir desta versao o CREATE_PLAYBACK_STREAM tem todos os campos abaixo.
pub const min_server_version = 22;
pub const cookie_len = 256;

pub const command = struct {
    pub const err = 0;
    pub const reply = 2;
    pub const create_playback_stream = 3;
    pub const auth = 8;
    pub const set_client_name = 9;
    pub const request = 61;
    pub const playback_stream_killed = 64;
};

const tag = struct {
    const string = 't';
    const string_null = 'N';
    const u32_ = 'L';
    const u8_ = 'B';
    const arbitrary = 'x';
    const boolean_true = '1';
    const boolean_false = '0';
    const sample_spec = 'a';
    const channel_map = 'm';
    const cvolume = 'v';
    const proplist = 'P';
};

pub fn descriptor(length: u32, channel: u32) [20]u8 {
    var d: [20]u8 = @splat(0);
    std.mem.writeInt(u32, d[0..4], length, .big);
    std.mem.writeInt(u32, d[4..8], channel, .big);
    return d;
}

pub const Descriptor = struct { length: u32, channel: u32 };

pub fn parseDescriptor(d: *const [20]u8) Descriptor {
    return .{ .length = std.mem.readInt(u32, d[0..4], .big), .channel = std.mem.readInt(u32, d[4..8], .big) };
}

/// Monta a tagstruct de um comando.
pub const Writer = struct {
    buf: std.ArrayList(u8) = .empty,
    gpa: std.mem.Allocator,

    pub fn deinit(w: *Writer) void {
        w.buf.deinit(w.gpa);
    }

    fn raw32(w: *Writer, v: u32) !void {
        try w.buf.appendSlice(w.gpa, &std.mem.toBytes(std.mem.nativeToBig(u32, v)));
    }

    pub fn u32_(w: *Writer, v: u32) !void {
        try w.buf.append(w.gpa, tag.u32_);
        try w.raw32(v);
    }

    pub fn u8_(w: *Writer, v: u8) !void {
        try w.buf.appendSlice(w.gpa, &.{ tag.u8_, v });
    }

    pub fn boolean(w: *Writer, v: bool) !void {
        try w.buf.append(w.gpa, if (v) tag.boolean_true else tag.boolean_false);
    }

    pub fn string(w: *Writer, s: ?[]const u8) !void {
        const v = s orelse return w.buf.append(w.gpa, tag.string_null);
        try w.buf.append(w.gpa, tag.string);
        try w.buf.appendSlice(w.gpa, v);
        try w.buf.append(w.gpa, 0);
    }

    pub fn arbitrary(w: *Writer, data: []const u8) !void {
        try w.buf.append(w.gpa, tag.arbitrary);
        try w.raw32(@intCast(data.len));
        try w.buf.appendSlice(w.gpa, data);
    }

    /// Lista de propriedades: chave, tamanho e valor (com o terminador).
    pub fn proplist(w: *Writer, pairs: []const [2][]const u8) !void {
        try w.buf.append(w.gpa, tag.proplist);
        for (pairs) |pair| {
            try w.string(pair[0]);
            try w.u32_(@intCast(pair[1].len + 1));
            try w.buf.append(w.gpa, tag.arbitrary);
            try w.raw32(@intCast(pair[1].len + 1));
            try w.buf.appendSlice(w.gpa, pair[1]);
            try w.buf.append(w.gpa, 0);
        }
        try w.buf.append(w.gpa, tag.string_null);
    }

    /// Inicio de todo comando: numero do comando e "tag" (id do pedido).
    pub fn begin(w: *Writer, cmd: u32, request_tag: u32) !void {
        w.buf.clearRetainingCapacity();
        try w.u32_(cmd);
        try w.u32_(request_tag);
    }
};

pub fn auth(w: *Writer, request_tag: u32, cookie: *const [cookie_len]u8) !void {
    try w.begin(command.auth, request_tag);
    try w.u32_(protocol_version);
    try w.arbitrary(cookie);
}

pub fn setClientName(w: *Writer, request_tag: u32, name: []const u8) !void {
    try w.begin(command.set_client_name, request_tag);
    try w.proplist(&.{.{ "application.name", name }});
}

/// Stream de reproducao S16LE estereo 44100 Hz com `tlength` bytes de buffer
/// alvo (o padrao do servidor seria 2 s de atraso).
pub fn createPlaybackStream(w: *Writer, request_tag: u32, name: []const u8, tlength: u32) !void {
    const none = 0xFFFFFFFF;
    try w.begin(command.create_playback_stream, request_tag);
    try w.buf.appendSlice(w.gpa, &.{ tag.sample_spec, 3, 2 }); // S16LE, 2 canais
    try w.raw32(44100);
    try w.buf.appendSlice(w.gpa, &.{ tag.channel_map, 2, 1, 2 }); // frente esquerda, direita
    try w.u32_(none); // sink: o padrao
    try w.string(null);
    try w.u32_(none); // maxlength
    try w.boolean(false); // corked
    try w.u32_(tlength);
    try w.u32_(none); // prebuf
    try w.u32_(none); // minreq
    try w.u32_(0); // syncid
    try w.buf.appendSlice(w.gpa, &.{ tag.cvolume, 2 }); // volume normal nos 2 canais
    try w.raw32(0x10000);
    try w.raw32(0x10000);
    // no_remap, no_remix, fix_format, fix_rate, fix_channels, no_move, variable_rate
    for (0..7) |_| try w.boolean(false);
    try w.boolean(false); // muted
    try w.boolean(true); // adjust_latency
    try w.proplist(&.{.{ "media.name", name }});
    // volume_set, early_requests, muted_set, dont_inhibit_auto_suspend,
    // fail_on_suspend, relative_volume, passthrough
    for (0..7) |_| try w.boolean(false);
    try w.u8_(0); // nenhum formato extra
}

/// Le uma tagstruct recebida.
pub const Reader = struct {
    data: []const u8,
    pos: usize = 0,

    pub fn u32_(r: *Reader) Error!u32 {
        if (r.pos + 5 > r.data.len or r.data[r.pos] != tag.u32_) return error.BadPacket;
        defer r.pos += 5;
        return std.mem.readInt(u32, r.data[r.pos + 1 ..][0..4], .big);
    }
};

pub const Command = struct {
    cmd: u32,
    tag: u32,
    rest: Reader,
};

pub fn parseCommand(payload: []const u8) Error!Command {
    var r: Reader = .{ .data = payload };
    const cmd = try r.u32_();
    const t = try r.u32_();
    return .{ .cmd = cmd, .tag = t, .rest = r };
}

const testing = std.testing;

test "descritor" {
    const d = descriptor(276, control_channel);
    try testing.expectEqualSlices(u8, &([_]u8{ 0, 0, 1, 0x14, 0xFF, 0xFF, 0xFF, 0xFF } ++ [_]u8{0} ** 12), &d);
    try testing.expectEqual(Descriptor{ .length = 276, .channel = control_channel }, parseDescriptor(&d));
}

test "AUTH e SET_CLIENT_NAME como a libpulse" {
    var w: Writer = .{ .gpa = testing.allocator };
    defer w.deinit();
    const cookie: [cookie_len]u8 = @splat(0xAB);
    try auth(&w, 0, &cookie);
    try testing.expectEqual(@as(usize, 276), w.buf.items.len);
    try testing.expectEqualSlices(u8, &.{ 'L', 0, 0, 0, 8, 'L', 0, 0, 0, 0, 'L', 0, 0, 0, 32, 'x', 0, 0, 1, 0, 0xAB }, w.buf.items[0..21]);

    try setClientName(&w, 1, "Vacina");
    const expected = "L\x00\x00\x00\x09L\x00\x00\x00\x01P" ++ "tapplication.name\x00" ++ "L\x00\x00\x00\x07" ++ "x\x00\x00\x00\x07Vacina\x00" ++ "N";
    try testing.expectEqualSlices(u8, expected, w.buf.items);
}

test "CREATE_PLAYBACK_STREAM igual ao capturado do paplay" {
    var w: Writer = .{ .gpa = testing.allocator };
    defer w.deinit();
    try createPlaybackStream(&w, 2, "Vacina", 7056);
    // Bytes do paplay 16.1 (strace, sem shm) ate a lista de propriedades e depois dela.
    var before: [73]u8 = undefined;
    _ = try std.fmt.hexToBytes(&before, "4c000000034c000000026103020000ac446d0201024cffffffff4e4cffffffff304c00001b904cffffffff4cffffffff4c000000007602000100000001000030303030303030303150");
    var after: [9]u8 = undefined;
    _ = try std.fmt.hexToBytes(&after, "303030303030304200");
    try testing.expectEqualSlices(u8, &before, w.buf.items[0..before.len]);
    try testing.expectEqualSlices(u8, &after, w.buf.items[w.buf.items.len - after.len ..]);
    const props = "tmedia.name\x00" ++ "L\x00\x00\x00\x07" ++ "x\x00\x00\x00\x07Vacina\x00" ++ "N";
    try testing.expectEqualSlices(u8, props, w.buf.items[before.len .. w.buf.items.len - after.len]);
}

test "le REQUEST e REPLY" {
    const request = "L\x00\x00\x00\x3dL\xff\xff\xff\xffL\x00\x00\x00\x00L\x00\x00\x10\x00";
    var c = try parseCommand(request);
    try testing.expectEqual(@as(u32, command.request), c.cmd);
    try testing.expectEqual(@as(u32, 0), try c.rest.u32_());
    try testing.expectEqual(@as(u32, 4096), try c.rest.u32_());
    try testing.expectError(error.BadPacket, c.rest.u32_());
    try testing.expectError(error.BadPacket, parseCommand("B\x00"));
}
