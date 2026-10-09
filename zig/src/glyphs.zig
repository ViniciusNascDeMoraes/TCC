//! Glifos de uma fonte num tamanho, rasterizados uma vez no carregamento, e o
//! layout de texto do `drawString`/`stringWidth` do Java.
//!
//! Ficam prontos os caracteres ASCII imprimiveis e Latin-1 (U+0020 a U+007E e
//! U+00A0 a U+00FF), o que cobre os acentos do portugues; qualquer outro
//! caractere aparece como "?". O avanco de cada glifo e arredondado para
//! pixels inteiros e nao ha kerning, como no Java sem metricas fracionarias.

const std = @import("std");
const bitmap_font = @import("bitmap_font.zig");
const raster = @import("raster.zig");
const ttf = @import("ttf.zig");
const Canvas = @import("canvas.zig").Canvas;
const Color = @import("canvas.zig").Color;

const Glyph = struct {
    advance: i32 = 0,
    box: raster.Box = .{},
};

fn cached(codepoint: u21) bool {
    return (codepoint >= 0x20 and codepoint <= 0x7E) or (codepoint >= 0xA0 and codepoint <= 0xFF);
}

/// Caractere desenhado no lugar de `codepoint`.
fn slot(codepoint: u21) u8 {
    return if (cached(codepoint)) @intCast(codepoint) else '?';
}

/// Percorre `text` como UTF-8; texto invalido e lido como Latin-1.
const Codepoints = struct {
    text: []const u8,
    utf8: bool,
    i: usize = 0,

    fn init(text: []const u8) Codepoints {
        return .{ .text = text, .utf8 = std.unicode.utf8ValidateSlice(text) };
    }

    fn next(self: *Codepoints) ?u21 {
        if (self.i >= self.text.len) return null;
        if (!self.utf8) {
            defer self.i += 1;
            return self.text[self.i];
        }
        const len = std.unicode.utf8ByteSequenceLength(self.text[self.i]) catch unreachable;
        defer self.i += len;
        return std.unicode.utf8Decode(self.text[self.i..][0..len]) catch unreachable;
    }
};

pub const GlyphSet = struct {
    glyphs: [256]Glyph = @splat(.{}),
    coverage: []u8 = &.{},

    /// Rasteriza os glifos de `font` com o "em" de `points` pixels. Falha se
    /// algum glifo usa um recurso que o leitor de fontes nao suporta.
    pub fn fromFont(gpa: std.mem.Allocator, font: ttf.Font, points: u32) !GlyphSet {
        const scale = @as(f64, @floatFromInt(points)) / @as(f64, @floatFromInt(font.units_per_em));
        var path: raster.Path = .init(gpa, @floatCast(scale));
        defer path.deinit();
        var pool: std.ArrayList(u8) = .empty;
        errdefer pool.deinit(gpa);

        var set: GlyphSet = .{};
        for (0..256) |cp| {
            if (!cached(@intCast(cp))) continue;
            const gid = font.glyphIndex(@intCast(cp));
            path.reset();
            try font.outline(gid, &path);
            set.glyphs[cp] = .{
                .advance = @intFromFloat(@round(@as(f64, @floatFromInt(font.advance(gid))) * scale)),
                .box = try raster.rasterize(gpa, &path, &pool),
            };
        }
        set.coverage = try pool.toOwnedSlice(gpa);
        return set;
    }

    /// Fonte bitmap embutida ampliada para `points` (escala inteira).
    pub fn fromBitmap(gpa: std.mem.Allocator, points: u32) !GlyphSet {
        const s: u32 = @max(1, (points + 5) / 10);
        var pool: std.ArrayList(u8) = .empty;
        errdefer pool.deinit(gpa);

        var set: GlyphSet = .{};
        for (0..256) |cp| {
            const rows = bitmap_font.glyph(@intCast(cp)) orelse continue;
            const last = bitmap_font.lastColumn(rows) orelse {
                set.glyphs[cp] = .{ .advance = @intCast(4 * s), .box = .{ .offset = pool.items.len } };
                continue;
            };
            const w = (@as(u32, last) + 1) * s;
            const h = 8 * s;
            const box: raster.Box = .{ .x0 = 0, .y0 = -@as(i32, @intCast(bitmap_font.baseline_row * s)), .width = w, .height = h, .offset = pool.items.len };
            const out = try pool.addManyAsSlice(gpa, w * h);
            for (0..h) |y| {
                for (0..w) |x| {
                    const lit = (rows[y / s] >> @intCast(x / s)) & 1 != 0;
                    out[y * w + x] = if (lit) 255 else 0;
                }
            }
            set.glyphs[cp] = .{ .advance = @intCast((@as(u32, last) + 2) * s), .box = box };
        }
        set.coverage = try pool.toOwnedSlice(gpa);
        return set;
    }

    pub fn deinit(self: GlyphSet, gpa: std.mem.Allocator) void {
        gpa.free(self.coverage);
    }

    /// `g.getFontMetrics().stringWidth(text)`.
    pub fn width(self: *const GlyphSet, text: []const u8) i32 {
        var total: i32 = 0;
        var it: Codepoints = .init(text);
        while (it.next()) |cp| total += self.glyphs[slot(cp)].advance;
        return total;
    }

    /// `g.drawString(text, x, y)`: `y` e a linha de base.
    pub fn draw(self: *const GlyphSet, target: Canvas, text: []const u8, x: i32, y: i32, color: Color) void {
        var pen = x;
        var it: Codepoints = .init(text);
        while (it.next()) |cp| {
            const g = self.glyphs[slot(cp)];
            const mask = self.coverage[g.box.offset..][0 .. @as(usize, g.box.width) * g.box.height];
            target.drawMask(mask, g.box.width, g.box.height, pen + g.box.x0, y + g.box.y0, color);
            pen += g.advance;
        }
    }
};

const testing = std.testing;

test "fonte bitmap: larguras, acentos e caracteres desconhecidos" {
    const set = try GlyphSet.fromBitmap(testing.allocator, 20);
    defer set.deinit(testing.allocator);
    // Escala 2: "A" ocupa as colunas 0 a 5 e avanca 7 colunas.
    try testing.expectEqual(@as(i32, 14), set.width("A"));
    try testing.expectEqual(@as(i32, 8), set.width(" "));
    try testing.expectEqual(set.width("?"), set.width("€"));
    try testing.expect(set.width("é") > 0);
    // Bytes que nao sao UTF-8 valido sao lidos como Latin-1.
    try testing.expectEqual(set.width("é"), set.width("\xE9"));

    const target = try Canvas.init(testing.allocator, 20, 20);
    defer target.deinit(testing.allocator);
    const red: Color = .rgb(255, 0, 0);
    set.draw(target, "A", 1, 15, red);
    // Linha 0 do "A" (0x0C): colunas 2 e 3, ampliadas, em y = 15 - 14.
    try testing.expectEqual(red, target.pixel(1 + 4, 1));
    try testing.expectEqual(Color.rgb(0, 0, 0), target.pixel(1, 1));
    try testing.expectEqual(red, target.pixel(1, 1 + 4));
}

test "larguras das fontes do sistema seguem o hmtx" {
    const cases = [_]struct { path: []const u8, widths: [4]i32 }{
        .{ .path = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", .widths = .{ 224, 189, 388, 260 } },
        .{ .path = "/usr/share/fonts/opentype/urw-base35/URWBookman-Demi.otf", .widths = .{ 205, 175, 347, 241 } },
        .{ .path = "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf", .widths = .{ 193, 161, 324, 218 } },
    };
    var found = false;
    for (cases) |case| {
        const data = std.Io.Dir.cwd().readFileAlloc(testing.io, case.path, testing.allocator, .limited(32 << 20)) catch continue;
        defer testing.allocator.free(data);
        found = true;
        const font = try ttf.Font.parse(data);
        const s40 = try GlyphSet.fromFont(testing.allocator, font, 40);
        defer s40.deinit(testing.allocator);
        const s50 = try GlyphSet.fromFont(testing.allocator, font, 50);
        defer s50.deinit(testing.allocator);
        const s20 = try GlyphSet.fromFont(testing.allocator, font, 20);
        defer s20.deinit(testing.allocator);
        try testing.expectEqual(case.widths[0], s40.width("Novo jogo"));
        try testing.expectEqual(case.widths[1], s40.width("Créditos"));
        try testing.expectEqual(case.widths[2], s50.width("Carregando..."));
        try testing.expectEqual(case.widths[3], s20.width("Vá para a área amarela"));
    }
    if (!found) return error.SkipZigTest;
}
