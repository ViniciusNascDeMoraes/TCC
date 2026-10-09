//! Decodificador de PNG (o `ImageIO.read` do Java) para um `Canvas`.
//!
//! Suporta o que os assets usam e um pouco mais: tons de cinza, RGB, paleta
//! (1, 2, 4 e 8 bits), cinza com alfa e RGBA, todos sem entrelacamento e com
//! 8 bits por amostra (paleta e cinza tambem com menos). Nao aplica gama: as
//! cores dos mapas dos niveis precisam chegar exatas em `rules.classifyPixel`.

const std = @import("std");
const flate = std.compress.flate;
const Canvas = @import("canvas.zig").Canvas;
const Color = @import("canvas.zig").Color;

pub const Error = error{ InvalidPng, Unsupported, OutOfMemory };

const signature = "\x89PNG\r\n\x1a\n";

const ColorType = enum(u8) {
    gray = 0,
    rgb = 2,
    palette = 3,
    gray_alpha = 4,
    rgba = 6,

    fn channels(t: ColorType) u32 {
        return switch (t) {
            .gray, .palette => 1,
            .gray_alpha => 2,
            .rgb => 3,
            .rgba => 4,
        };
    }
};

const Header = struct {
    width: u32,
    height: u32,
    depth: u8,
    color_type: ColorType,

    fn bitsPerPixel(h: Header) u32 {
        return h.color_type.channels() * h.depth;
    }

    fn stride(h: Header) usize {
        return (@as(usize, h.width) * h.bitsPerPixel() + 7) / 8;
    }
};

fn readU32(bytes: []const u8) u32 {
    return std.mem.readInt(u32, bytes[0..4], .big);
}

pub fn decode(gpa: std.mem.Allocator, data: []const u8) Error!Canvas {
    if (data.len < signature.len or !std.mem.eql(u8, data[0..signature.len], signature)) return error.InvalidPng;

    var header: ?Header = null;
    var palette: []const u8 = &.{};
    var transparency: []const u8 = &.{};
    var idat: std.ArrayList(u8) = .empty;
    defer idat.deinit(gpa);

    var pos: usize = signature.len;
    while (true) {
        if (pos + 8 > data.len) return error.InvalidPng;
        const len = readU32(data[pos..]);
        const kind = data[pos + 4 ..][0..4];
        const body_start = pos + 8;
        if (len > data.len - body_start or data.len - body_start - len < 4) return error.InvalidPng;
        const body = data[body_start..][0..len];
        pos = body_start + len + 4; // + CRC (nao conferido: os assets vem embutidos)

        if (std.mem.eql(u8, kind, "IHDR")) {
            if (len < 13) return error.InvalidPng;
            const color_type = std.enums.fromInt(ColorType, body[9]) orelse return error.InvalidPng;
            header = .{ .width = readU32(body[0..]), .height = readU32(body[4..]), .depth = body[8], .color_type = color_type };
            if (body[12] != 0) return error.Unsupported; // entrelacado
        } else if (std.mem.eql(u8, kind, "PLTE")) {
            palette = body;
        } else if (std.mem.eql(u8, kind, "tRNS")) {
            transparency = body;
        } else if (std.mem.eql(u8, kind, "IDAT")) {
            try idat.appendSlice(gpa, body);
        } else if (std.mem.eql(u8, kind, "IEND")) {
            break;
        }
    }

    const h = header orelse return error.InvalidPng;
    if (h.width == 0 or h.height == 0) return error.InvalidPng;
    switch (h.color_type) {
        .gray, .palette => if (h.depth != 1 and h.depth != 2 and h.depth != 4 and h.depth != 8) return error.Unsupported,
        else => if (h.depth != 8) return error.Unsupported,
    }
    if (h.color_type == .palette and (palette.len == 0 or palette.len % 3 != 0)) return error.InvalidPng;

    const stride = h.stride();
    const raw = try gpa.alloc(u8, (stride + 1) * h.height);
    defer gpa.free(raw);
    try inflate(gpa, idat.items, raw);

    const bpp = @max(1, h.bitsPerPixel() / 8);
    try unfilter(raw, stride, h.height, bpp);

    var canvas = try Canvas.init(gpa, h.width, h.height);
    errdefer canvas.deinit(gpa);
    expand(h, raw, palette, transparency, &canvas);
    return canvas;
}

/// Descompacta os dados zlib dos IDAT, que precisam ter exatamente `out.len` bytes.
fn inflate(gpa: std.mem.Allocator, compressed: []const u8, out: []u8) Error!void {
    const window = try gpa.alloc(u8, flate.max_window_len);
    defer gpa.free(window);
    var input: std.Io.Reader = .fixed(compressed);
    var decompress: flate.Decompress = .init(&input, .zlib, window);
    decompress.reader.readSliceAll(out) catch return error.InvalidPng;
}

fn paeth(a: u8, b: u8, c: u8) u8 {
    const p = @as(i16, a) + b - c;
    const pa = @abs(p - a);
    const pb = @abs(p - b);
    const pc = @abs(p - c);
    if (pa <= pb and pa <= pc) return a;
    if (pb <= pc) return b;
    return c;
}

/// Desfaz os filtros de cada linha no proprio buffer (cada linha comeca com
/// o byte do filtro).
fn unfilter(raw: []u8, stride: usize, height: u32, bpp: usize) Error!void {
    var prev: ?[]const u8 = null;
    for (0..height) |y| {
        const line = raw[y * (stride + 1) ..][0 .. stride + 1];
        const filter = line[0];
        const cur = line[1..];
        switch (filter) {
            0 => {},
            1 => for (bpp..stride) |i| {
                cur[i] +%= cur[i - bpp];
            },
            2 => if (prev) |up| {
                for (cur, up) |*c, u| c.* +%= u;
            },
            3 => for (0..stride) |i| {
                const left: u16 = if (i >= bpp) cur[i - bpp] else 0;
                const up: u16 = if (prev) |p| p[i] else 0;
                cur[i] +%= @intCast((left + up) / 2);
            },
            4 => for (0..stride) |i| {
                const left = if (i >= bpp) cur[i - bpp] else 0;
                const up = if (prev) |p| p[i] else 0;
                const up_left = if (i >= bpp) (if (prev) |p| p[i - bpp] else 0) else 0;
                cur[i] +%= paeth(left, up, up_left);
            },
            else => return error.InvalidPng,
        }
        prev = cur;
    }
}

/// Amostra `x` de uma linha com `depth` bits por amostra (bits mais altos primeiro).
fn sample(line: []const u8, x: usize, depth: u8) u8 {
    if (depth == 8) return line[x];
    const bit = x * depth;
    const shift: u3 = @intCast(8 - depth - bit % 8);
    const mask: u8 = @intCast((@as(u16, 1) << @intCast(depth)) - 1);
    return (line[bit / 8] >> shift) & mask;
}

fn expand(h: Header, raw: []const u8, palette: []const u8, transparency: []const u8, canvas: *Canvas) void {
    const stride = h.stride();
    var solid = true;
    for (0..h.height) |y| {
        const line = raw[y * (stride + 1) + 1 ..][0..stride];
        const out = canvas.pixels[y * h.width ..][0..h.width];
        for (out, 0..) |*p, x| {
            p.* = switch (h.color_type) {
                .gray => gray: {
                    const v = sample(line, x, h.depth);
                    const max: u16 = (@as(u16, 1) << @intCast(h.depth)) - 1;
                    const scale: u8 = @intCast(255 / max);
                    const key = transparency.len >= 2 and std.mem.readInt(u16, transparency[0..2], .big) == v;
                    break :gray .{ .r = v * scale, .g = v * scale, .b = v * scale, .a = if (key) 0 else 255 };
                },
                .rgb => rgb: {
                    const c: Color = .rgb(line[x * 3], line[x * 3 + 1], line[x * 3 + 2]);
                    const key = transparency.len >= 6 and
                        std.mem.readInt(u16, transparency[0..2], .big) == c.r and
                        std.mem.readInt(u16, transparency[2..4], .big) == c.g and
                        std.mem.readInt(u16, transparency[4..6], .big) == c.b;
                    break :rgb if (key) .{ .r = c.r, .g = c.g, .b = c.b, .a = 0 } else c;
                },
                .palette => pal: {
                    const i: usize = sample(line, x, h.depth);
                    if (i * 3 + 3 > palette.len) break :pal .{ .r = 0, .g = 0, .b = 0 };
                    break :pal .{
                        .r = palette[i * 3],
                        .g = palette[i * 3 + 1],
                        .b = palette[i * 3 + 2],
                        .a = if (i < transparency.len) transparency[i] else 255,
                    };
                },
                .gray_alpha => .{ .r = line[x * 2], .g = line[x * 2], .b = line[x * 2], .a = line[x * 2 + 1] },
                .rgba => .{ .r = line[x * 4], .g = line[x * 4 + 1], .b = line[x * 4 + 2], .a = line[x * 4 + 3] },
            };
            if (p.a != 255) solid = false;
        }
    }
    canvas.solid = solid;
}

const testing = std.testing;

fn checksum(canvas: Canvas) u32 {
    var sum: u32 = 0;
    for (canvas.pixels) |p| sum +%= p.argb();
    return sum;
}

test "decodifica os assets com as mesmas cores do Java" {
    const assets = @import("assets");
    // Largura, altura e soma dos pixels 0xAARRGGBB, conferidas com o PIL.
    const cases = [_]struct { []const u8, u32, u32, u32 }{
        .{ assets.game_over, 960, 640, 0x98f75123 },
        .{ assets.spritesheet, 800, 600, 0x043ee60f },
        .{ assets.tela_creditos, 960, 640, 0xd71cbea1 },
        .{ assets.tela_fim, 960, 640, 0x12c7291e },
        .{ assets.tela_menu, 960, 640, 0x942174ff },
        .{ assets.tela_vacina, 960, 640, 0x2ba3ca81 },
        .{ assets.vacinando, 960, 640, 0x461a1e7c },
        .{ assets.vacinando1, 960, 640, 0x446f2793 },
        .{ assets.vacinando2, 960, 640, 0x452b9bf6 },
        .{ assets.vacinando3, 960, 640, 0x439cd89e },
        .{ assets.level1, 15, 45, 0xa7ae78d4 },
        .{ assets.level2, 15, 10, 0x9b6f1c01 },
        .{ assets.level3, 43, 60, 0xa34dd150 },
    };
    for (cases) |case| {
        const canvas = try decode(testing.allocator, case[0]);
        defer canvas.deinit(testing.allocator);
        try testing.expectEqual(case[1], canvas.width);
        try testing.expectEqual(case[2], canvas.height);
        try testing.expectEqual(case[3], checksum(canvas));
    }
}

test "pixels conhecidos do spritesheet e dos niveis" {
    const assets = @import("assets");
    const sheet = try decode(testing.allocator, assets.spritesheet);
    defer sheet.deinit(testing.allocator);
    try testing.expect(!sheet.solid);
    try testing.expectEqual(@as(u32, 0xFFFFFFFF), sheet.pixel(0, 0).argb());
    try testing.expectEqual(@as(u32, 0xFF267F00), sheet.pixel(16, 0).argb());
    try testing.expectEqual(@as(u32, 0xFF7F0000), sheet.pixel(104, 8).argb());
    try testing.expectEqual(@as(u8, 0), sheet.pixel(32, 0).a);
    var transparent: usize = 0;
    for (sheet.pixels) |p| {
        if (p.a == 0) transparent += 1 else try testing.expectEqual(@as(u8, 255), p.a);
    }
    try testing.expectEqual(@as(usize, 6846), transparent);

    // level1.png tem paleta de 4 bits; o jogador fica em (11, 43).
    const level1 = try decode(testing.allocator, assets.level1);
    defer level1.deinit(testing.allocator);
    try testing.expect(level1.solid);
    try testing.expectEqual(@as(u32, 0xFF0026FF), level1.pixel(11, 43).argb());

    const menu = try decode(testing.allocator, assets.tela_menu);
    defer menu.deinit(testing.allocator);
    try testing.expectEqual(@as(u32, 0xFF099C93), menu.pixel(0, 0).argb());
}

test "filtros sub, up, average e paeth" {
    // 2 linhas RGB de 2 pixels, ja sem zlib: testa so `unfilter`.
    var raw = [_]u8{
        1, 10, 20, 30, 5, 5, 5,
        4, 1,  1,  1,  2, 2, 2,
    };
    try unfilter(&raw, 6, 2, 3);
    try testing.expectEqualSlices(u8, &.{ 10, 20, 30, 15, 25, 35 }, raw[1..7]);
    // Paeth: primeiro pixel usa "cima" (10, 20, 30); o segundo escolhe entre
    // esquerda (11, 21, 31), cima (15, 25, 35) e diagonal (10, 20, 30).
    try testing.expectEqualSlices(u8, &.{ 11, 21, 31, 17, 27, 37 }, raw[8..14]);

    // Average: (esquerda + cima) / 2, com a esquerda ja decodificada.
    var avg = [_]u8{ 0, 100, 50, 3, 10, 20 };
    try unfilter(&avg, 2, 2, 1);
    try testing.expectEqualSlices(u8, &.{ 10 + 50, 20 + 55 }, avg[4..6]);

    var bad = [_]u8{ 9, 0 };
    try testing.expectError(error.InvalidPng, unfilter(&bad, 1, 1, 1));
}

test "amostras de menos de 8 bits" {
    try testing.expectEqual(@as(u8, 0xA), sample(&.{0xAB}, 0, 4));
    try testing.expectEqual(@as(u8, 0xB), sample(&.{0xAB}, 1, 4));
    try testing.expectEqual(@as(u8, 1), sample(&.{0b1000_0000}, 0, 1));
    try testing.expectEqual(@as(u8, 2), sample(&.{0b0010_0000}, 1, 2));
}

test "entrada invalida ou truncada gera erro" {
    const assets = @import("assets");
    try testing.expectError(error.InvalidPng, decode(testing.allocator, "nao e png"));
    try testing.expectError(error.InvalidPng, decode(testing.allocator, assets.level3[0 .. assets.level3.len / 2]));
}
