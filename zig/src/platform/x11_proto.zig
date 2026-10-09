//! Partes puras do protocolo X11 (sem socket): `DISPLAY`, `.Xauthority`,
//! resposta do setup, montagem de requests e teclas. O protocolo e descrito
//! em "X Window System Protocol" (X.Org); todos os numeros vem de la.
//!
//! O cliente anuncia ordem de bytes little-endian ('l'), entao tudo o que vai
//! e volta pelo socket e little-endian, menos o arquivo `.Xauthority`.

const std = @import("std");
const Key = @import("../platform.zig").Key;

pub const Error = error{ BadSetup, OutOfMemory };

// ---------------------------------------------------------------- DISPLAY

pub const Display = struct {
    /// Vazio ou "unix": socket Unix local.
    host: []const u8,
    /// Numero do display, como texto (comparado com o do `.Xauthority`).
    number: []const u8,
};

/// `[host]:numero[.tela]`.
pub fn parseDisplay(display: []const u8) ?Display {
    const colon = std.mem.lastIndexOfScalar(u8, display, ':') orelse return null;
    const rest = display[colon + 1 ..];
    const end = std.mem.indexOfScalar(u8, rest, '.') orelse rest.len;
    const number = rest[0..end];
    if (number.len == 0) return null;
    for (number) |c| if (!std.ascii.isDigit(c)) return null;
    return .{ .host = display[0..colon], .number = number };
}

// ---------------------------------------------------------------- Xauthority

const family_local = 256;
const family_wild = 65535;
pub const cookie_name = "MIT-MAGIC-COOKIE-1";

/// Procura o cookie MIT-MAGIC-COOKIE-1 do display `number` nesta maquina.
/// O arquivo e uma lista de entradas com campos de tamanho big-endian.
pub fn findCookie(xauthority: []const u8, hostname: []const u8, number: []const u8) ?[16]u8 {
    var pos: usize = 0;
    const Field = struct {
        fn read(data: []const u8, p: *usize) ?[]const u8 {
            if (p.* + 2 > data.len) return null;
            const len = std.mem.readInt(u16, data[p.*..][0..2], .big);
            p.* += 2;
            if (p.* + len > data.len) return null;
            defer p.* += len;
            return data[p.*..][0..len];
        }
    };
    while (pos + 2 <= xauthority.len) {
        const family = std.mem.readInt(u16, xauthority[pos..][0..2], .big);
        pos += 2;
        const address = Field.read(xauthority, &pos) orelse return null;
        const display = Field.read(xauthority, &pos) orelse return null;
        const name = Field.read(xauthority, &pos) orelse return null;
        const data = Field.read(xauthority, &pos) orelse return null;

        const host_ok = family == family_wild or (family == family_local and std.mem.eql(u8, address, hostname));
        const display_ok = display.len == 0 or std.mem.eql(u8, display, number);
        if (host_ok and display_ok and std.mem.eql(u8, name, cookie_name) and data.len == 16) {
            return data[0..16].*;
        }
    }
    return null;
}

// ---------------------------------------------------------------- setup

fn pad4(n: usize) usize {
    return (4 - n % 4) % 4;
}

/// Pedido de conexao, com ou sem cookie.
pub fn setupRequest(buf: *[48]u8, cookie: ?[16]u8) []const u8 {
    @memset(buf, 0);
    buf[0] = 'l';
    std.mem.writeInt(u16, buf[2..4], 11, .little);
    std.mem.writeInt(u16, buf[4..6], 0, .little);
    const c = cookie orelse return buf[0..12];
    std.mem.writeInt(u16, buf[6..8], cookie_name.len, .little);
    std.mem.writeInt(u16, buf[8..10], 16, .little);
    @memcpy(buf[12..][0..cookie_name.len], cookie_name);
    @memcpy(buf[32..48], &c);
    return buf[0..48];
}

/// O que interessa da resposta de sucesso do setup (tela 0).
pub const Setup = struct {
    rid_base: u32,
    rid_mask: u32,
    /// Em unidades de 4 bytes.
    max_request_len: u16,
    min_keycode: u8,
    max_keycode: u8,
    root: u32,
    root_width: u16,
    root_height: u16,
    root_depth: u8,
    /// Bits por pixel das imagens de profundidade 24, se a tela tem esse formato.
    bpp24: ?u8,
    lsb_first: bool,
    true_color_bgr: bool,

    /// A imagem do jogo (pixels de 32 bits 0x00RRGGBB) pode ir direto.
    pub fn supported(s: Setup) bool {
        return s.root_depth == 24 and s.bpp24 == 32 and s.lsb_first and s.true_color_bgr;
    }

    /// Identificador novo numero `n` (janela, pixmap, GC).
    pub fn resourceId(s: Setup, n: u32) u32 {
        return s.rid_base | (n << @intCast(@ctz(s.rid_mask)));
    }
};

fn rd16(data: []const u8, offset: usize) Error!u16 {
    if (offset + 2 > data.len) return error.BadSetup;
    return std.mem.readInt(u16, data[offset..][0..2], .little);
}

fn rd32(data: []const u8, offset: usize) Error!u32 {
    if (offset + 4 > data.len) return error.BadSetup;
    return std.mem.readInt(u32, data[offset..][0..4], .little);
}

/// `reply` e a resposta inteira (8 bytes de cabecalho + dados adicionais).
pub fn parseSetup(reply: []const u8) Error!Setup {
    if (reply.len < 40 or reply[0] != 1) return error.BadSetup;
    const vendor_len = try rd16(reply, 24);
    const n_screens = reply[28];
    const n_formats = reply[29];
    if (n_screens == 0) return error.BadSetup;

    var bpp24: ?u8 = null;
    var pos: usize = 40 + vendor_len + pad4(vendor_len);
    for (0..n_formats) |_| {
        if (pos + 8 > reply.len) return error.BadSetup;
        if (reply[pos] == 24) bpp24 = reply[pos + 1];
        pos += 8;
    }

    // Tela 0.
    const screen = pos;
    if (screen + 40 > reply.len) return error.BadSetup;
    const root_visual = try rd32(reply, screen + 32);
    const n_depths = reply[screen + 39];
    var true_color_bgr = false;
    pos = screen + 40;
    for (0..n_depths) |_| {
        if (pos + 8 > reply.len) return error.BadSetup;
        const n_visuals = try rd16(reply, pos + 2);
        pos += 8;
        for (0..n_visuals) |_| {
            if (pos + 24 > reply.len) return error.BadSetup;
            if (try rd32(reply, pos) == root_visual) {
                true_color_bgr = reply[pos + 4] == 4 and // TrueColor
                    try rd32(reply, pos + 8) == 0xFF0000 and
                    try rd32(reply, pos + 12) == 0x00FF00 and
                    try rd32(reply, pos + 16) == 0x0000FF;
            }
            pos += 24;
        }
    }

    return .{
        .rid_base = try rd32(reply, 12),
        .rid_mask = try rd32(reply, 16),
        .max_request_len = try rd16(reply, 26),
        .min_keycode = reply[34],
        .max_keycode = reply[35],
        .root = try rd32(reply, screen),
        .root_width = try rd16(reply, screen + 20),
        .root_height = try rd16(reply, screen + 22),
        .root_depth = reply[screen + 38],
        .bpp24 = bpp24,
        .lsb_first = reply[30] == 0,
        .true_color_bgr = true_color_bgr,
    };
}

// ---------------------------------------------------------------- requests

pub const opcode = struct {
    pub const create_window = 1;
    pub const map_window = 8;
    pub const intern_atom = 16;
    pub const change_property = 18;
    pub const get_input_focus = 43;
    pub const create_pixmap = 53;
    pub const create_gc = 55;
    pub const copy_area = 62;
    pub const put_image = 72;
    pub const query_extension = 98;
    pub const get_keyboard_mapping = 101;
};

pub const atom = struct {
    pub const atom_type = 4;
    pub const string = 31;
    pub const wm_name = 39;
    pub const wm_normal_hints = 40;
    pub const wm_size_hints = 41;
    pub const wm_class = 67;
};

pub const event_mask = struct {
    pub const key_press = 0x1;
    pub const key_release = 0x2;
    pub const focus_change = 0x200000;
};

/// Monta requests em `buf`; o tamanho (em unidades de 4 bytes) e preenchido
/// por `end`.
pub const Builder = struct {
    buf: *std.ArrayList(u8),
    gpa: std.mem.Allocator,
    start: usize = 0,

    pub fn begin(self: *Builder, op: u8, data: u8) !void {
        self.start = self.buf.items.len;
        try self.buf.appendSlice(self.gpa, &.{ op, data, 0, 0 });
    }

    pub fn u8_(self: *Builder, v: u8) !void {
        try self.buf.append(self.gpa, v);
    }

    pub fn u16_(self: *Builder, v: u16) !void {
        try self.buf.appendSlice(self.gpa, &std.mem.toBytes(std.mem.nativeToLittle(u16, v)));
    }

    pub fn u32_(self: *Builder, v: u32) !void {
        try self.buf.appendSlice(self.gpa, &std.mem.toBytes(std.mem.nativeToLittle(u32, v)));
    }

    pub fn bytes(self: *Builder, data: []const u8) !void {
        try self.buf.appendSlice(self.gpa, data);
        try self.buf.appendNTimes(self.gpa, 0, pad4(data.len));
    }

    pub fn end(self: *Builder) void {
        const len = self.buf.items.len - self.start;
        std.debug.assert(len % 4 == 0);
        std.mem.writeInt(u16, self.buf.items[self.start + 2 ..][0..2], @intCast(len / 4), .little);
    }
};

/// Cabecalho do PutImage (ZPixmap, profundidade 24) de `rows` linhas de
/// `width` pixels de 32 bits, que vem logo depois sem preenchimento.
pub fn putImageHeader(drawable: u32, gc: u32, width: u16, rows: u16, y: u16) [24]u8 {
    var h: [24]u8 = undefined;
    h[0] = opcode.put_image;
    h[1] = 2; // ZPixmap
    std.mem.writeInt(u16, h[2..4], @intCast(6 + @as(u32, width) * rows), .little);
    std.mem.writeInt(u32, h[4..8], drawable, .little);
    std.mem.writeInt(u32, h[8..12], gc, .little);
    std.mem.writeInt(u16, h[12..14], width, .little);
    std.mem.writeInt(u16, h[14..16], rows, .little);
    std.mem.writeInt(u16, h[16..18], 0, .little);
    std.mem.writeInt(u16, h[18..20], y, .little);
    h[20] = 0; // left-pad
    h[21] = 24; // depth
    h[22] = 0;
    h[23] = 0;
    return h;
}

/// Linhas por PutImage dentro do limite de tamanho de request do servidor.
pub fn rowsPerPutImage(max_request_len: u16, width: u32) u32 {
    const max_bytes = @as(u32, max_request_len) * 4;
    return @max(1, (max_bytes - 24) / (width * 4));
}

// ---------------------------------------------------------------- pacotes

/// Tamanho do pacote (erro, resposta ou evento) que comeca em `data`, ou
/// `null` se ainda nao chegaram bytes suficientes para saber.
pub fn packetLength(data: []const u8) ?usize {
    if (data.len < 32) return null;
    const code = data[0] & 0x7F;
    // Respostas (1) e eventos genericos (35) tem dados extras.
    if (code == 1 or code == 35) return 32 + @as(usize, std.mem.readInt(u32, data[4..8], .little)) * 4;
    return 32;
}

pub const event = struct {
    pub const err = 0;
    pub const reply = 1;
    pub const key_press = 2;
    pub const key_release = 3;
    pub const focus_out = 10;
    pub const client_message = 33;
    pub const mapping_notify = 34;
};

// ---------------------------------------------------------------- teclas

/// Tecla do jogo para um keysym (`keysymdef.h`); maiusculas contam como minusculas.
pub fn keyFromKeysym(keysym: u32) ?Key {
    return switch (keysym) {
        'w', 'W' => .w,
        'a', 'A' => .a,
        's', 'S' => .s,
        'd', 'D' => .d,
        0xFF0D, 0xFF8D => .enter, // Return, KP_Enter
        0xFF1B => .escape,
        else => null,
    };
}

const testing = std.testing;

test "parseDisplay" {
    try testing.expectEqualDeep(Display{ .host = "", .number = "0" }, parseDisplay(":0").?);
    try testing.expectEqualDeep(Display{ .host = "", .number = "1" }, parseDisplay(":1.0").?);
    try testing.expectEqualDeep(Display{ .host = "unix", .number = "2" }, parseDisplay("unix:2").?);
    try testing.expectEqualDeep(Display{ .host = "localhost", .number = "10" }, parseDisplay("localhost:10.0").?);
    try testing.expectEqual(@as(?Display, null), parseDisplay("wayland-0"));
    try testing.expectEqual(@as(?Display, null), parseDisplay(":"));
}

fn xauthEntry(comptime family: u16, comptime address: []const u8, comptime number: []const u8, comptime name: []const u8, comptime data: []const u8) []const u8 {
    const be = struct {
        fn u16be(comptime v: u16) [2]u8 {
            return .{ @intCast(v >> 8), @intCast(v & 0xFF) };
        }
    };
    return &(be.u16be(family) ++ be.u16be(address.len) ++ address[0..address.len].* ++
        be.u16be(number.len) ++ number[0..number.len].* ++
        be.u16be(name.len) ++ name[0..name.len].* ++
        be.u16be(data.len) ++ data[0..data.len].*);
}

test "findCookie escolhe a entrada desta maquina e deste display" {
    const cookie_a = "AAAAAAAAAAAAAAAA";
    const cookie_b = "BBBBBBBBBBBBBBBB";
    const file = comptime xauthEntry(family_local, "outra", "0", cookie_name, cookie_a) ++
        xauthEntry(family_local, "maquina", "1", cookie_name, cookie_a) ++
        xauthEntry(family_local, "maquina", "0", "XDM-AUTHORIZATION-1", cookie_a) ++
        xauthEntry(family_local, "maquina", "0", cookie_name, cookie_b);
    try testing.expectEqualSlices(u8, cookie_b, &findCookie(file, "maquina", "0").?);
    try testing.expectEqual(@as(?[16]u8, null), findCookie(file, "maquina", "7"));
    const wild = comptime xauthEntry(family_wild, "", "", cookie_name, cookie_a);
    try testing.expectEqualSlices(u8, cookie_a, &findCookie(wild, "x", "3").?);
    try testing.expectEqual(@as(?[16]u8, null), findCookie(file[0..5], "maquina", "0"));
}

test "setupRequest" {
    var buf: [48]u8 = undefined;
    try testing.expectEqualSlices(u8, &.{ 'l', 0, 11, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, setupRequest(&buf, null));
    const req = setupRequest(&buf, @splat(7));
    try testing.expectEqual(@as(usize, 48), req.len);
    try testing.expectEqual(@as(u8, 18), req[6]);
    try testing.expectEqual(@as(u8, 16), req[8]);
    try testing.expectEqualStrings(cookie_name, req[12..30]);
    try testing.expectEqual(@as(u8, 7), req[47]);
}

test "parseSetup le a tela 0" {
    var r: [40 + 8 + 16 + 40 + 8 + 24]u8 = @splat(0);
    r[0] = 1;
    std.mem.writeInt(u32, r[12..16], 0x0400000, .little);
    std.mem.writeInt(u32, r[16..20], 0x01FFFFF, .little);
    std.mem.writeInt(u16, r[24..26], 5, .little); // fornecedor "Teste" + 3 de preenchimento
    std.mem.writeInt(u16, r[26..28], 65535, .little);
    r[28] = 1;
    r[29] = 2;
    r[34] = 8;
    r[35] = 255;
    @memcpy(r[40..45], "Teste");
    // Formatos: profundidade 1 -> 1 bpp, 24 -> 32 bpp.
    r[48] = 1;
    r[49] = 1;
    r[56] = 24;
    r[57] = 32;
    const s = 64;
    std.mem.writeInt(u32, r[s..][0..4], 0x123, .little);
    std.mem.writeInt(u16, r[s + 20 ..][0..2], 1920, .little);
    std.mem.writeInt(u16, r[s + 22 ..][0..2], 1080, .little);
    std.mem.writeInt(u32, r[s + 32 ..][0..4], 0x21, .little);
    r[s + 38] = 24;
    r[s + 39] = 1;
    r[s + 40] = 24;
    std.mem.writeInt(u16, r[s + 42 ..][0..2], 1, .little);
    const v = s + 48;
    std.mem.writeInt(u32, r[v..][0..4], 0x21, .little);
    r[v + 4] = 4;
    std.mem.writeInt(u32, r[v + 8 ..][0..4], 0xFF0000, .little);
    std.mem.writeInt(u32, r[v + 12 ..][0..4], 0x00FF00, .little);
    std.mem.writeInt(u32, r[v + 16 ..][0..4], 0x0000FF, .little);

    const setup = try parseSetup(&r);
    try testing.expect(setup.supported());
    try testing.expectEqual(@as(u32, 0x123), setup.root);
    try testing.expectEqual(@as(u16, 1920), setup.root_width);
    try testing.expectEqual(@as(u8, 8), setup.min_keycode);
    try testing.expectEqual(@as(u32, 0x0400000), setup.resourceId(0));
    try testing.expectEqual(@as(u32, 0x0400002), setup.resourceId(2));

    r[57] = 24; // 24 bpp: a imagem precisaria ser convertida
    try testing.expect(!(try parseSetup(&r)).supported());
    try testing.expectError(error.BadSetup, parseSetup(r[0..70]));
}

test "PutImage cabe no limite de tamanho" {
    try testing.expectEqual(@as(u32, 68), rowsPerPutImage(65535, 960));
    const h = putImageHeader(1, 2, 960, 68, 0);
    try testing.expectEqual(@as(u16, 6 + 960 * 68), std.mem.readInt(u16, h[2..4], .little));
    try testing.expect(@as(u32, std.mem.readInt(u16, h[2..4], .little)) <= 65535);
}

test "Builder preenche o tamanho" {
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(testing.allocator);
    var b: Builder = .{ .buf = &buf, .gpa = testing.allocator };
    try b.begin(opcode.intern_atom, 0);
    try b.u16_(12);
    try b.u16_(0);
    try b.bytes("WM_PROTOCOLS");
    b.end();
    try testing.expectEqual(@as(usize, 20), buf.items.len);
    try testing.expectEqual(@as(u8, 5), buf.items[2]);
}

test "packetLength e keyFromKeysym" {
    var p: [32]u8 = @splat(0);
    p[0] = 1;
    std.mem.writeInt(u32, p[4..8], 3, .little);
    try testing.expectEqual(@as(?usize, 44), packetLength(&p));
    p[0] = 2 | 0x80;
    try testing.expectEqual(@as(?usize, 32), packetLength(&p));
    try testing.expectEqual(@as(?usize, null), packetLength(p[0..10]));
    try testing.expectEqual(@as(?Key, .w), keyFromKeysym('W'));
    try testing.expectEqual(@as(?Key, .enter), keyFromKeysym(0xFF8D));
    try testing.expectEqual(@as(?Key, null), keyFromKeysym('q'));
}
