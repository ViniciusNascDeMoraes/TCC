//! Leitura de fontes TrueType/OpenType: mapa de caracteres, larguras e
//! contornos dos glifos (`glyf` com curvas quadraticas ou `CFF ` com cubicas).
//!
//! O tamanho de fonte do Java e o tamanho do "em": um glifo de `n` pontos usa
//! a escala `n / unitsPerEm`.

const std = @import("std");
const cff = @import("cff.zig");
const Path = @import("raster.zig").Path;

pub const Error = error{ Malformed, Unsupported, OutOfMemory };

fn readU16(data: []const u8, offset: usize) Error!u16 {
    if (offset + 2 > data.len) return error.Malformed;
    return std.mem.readInt(u16, data[offset..][0..2], .big);
}

fn readI16(data: []const u8, offset: usize) Error!i16 {
    return @bitCast(try readU16(data, offset));
}

fn readU32(data: []const u8, offset: usize) Error!u32 {
    if (offset + 4 > data.len) return error.Malformed;
    return std.mem.readInt(u32, data[offset..][0..4], .big);
}

/// Conteudo da tabela `tag`, ou `null` se a fonte nao a tem.
fn table(data: []const u8, tag: *const [4]u8) Error!?[]const u8 {
    const num_tables = try readU16(data, 4);
    for (0..num_tables) |i| {
        const record = 12 + i * 16;
        if (record + 16 > data.len) return error.Malformed;
        if (!std.mem.eql(u8, data[record..][0..4], tag)) continue;
        const offset = try readU32(data, record + 8);
        const len = try readU32(data, record + 12);
        if (offset > data.len or len > data.len - offset) return error.Malformed;
        return data[offset..][0..len];
    }
    return null;
}

/// Transformacao afim dos componentes de um glifo composto:
/// x' = a*x + c*y + e, y' = b*x + d*y + f.
const Affine = struct {
    a: f32 = 1,
    b: f32 = 0,
    c: f32 = 0,
    d: f32 = 1,
    e: f32 = 0,
    f: f32 = 0,

    fn apply(m: Affine, x: f32, y: f32) [2]f32 {
        return .{ m.a * x + m.c * y + m.e, m.b * x + m.d * y + m.f };
    }

    /// `parent` aplicada depois de `child`.
    fn then(child: Affine, parent: Affine) Affine {
        return .{
            .a = parent.a * child.a + parent.c * child.b,
            .b = parent.b * child.a + parent.d * child.b,
            .c = parent.a * child.c + parent.c * child.d,
            .d = parent.b * child.c + parent.d * child.d,
            .e = parent.a * child.e + parent.c * child.f + parent.e,
            .f = parent.b * child.e + parent.d * child.f + parent.f,
        };
    }
};

const Cmap = struct {
    subtable: []const u8,
    format: u16,
};

const Outlines = union(enum) {
    glyf: struct { loca: []const u8, glyf: []const u8, long_offsets: bool },
    cff: cff.Cff,
};

pub const Font = struct {
    units_per_em: u16,
    num_glyphs: u16,
    num_hmetrics: u16,
    hmtx: []const u8,
    cmap: Cmap,
    outlines: Outlines,

    /// `data` precisa continuar valido enquanto a fonte for usada.
    pub fn parse(data: []const u8) Error!Font {
        const version = try readU32(data, 0);
        if (version != 0x00010000 and version != 0x74727565 and version != 0x4F54544F) return error.Unsupported;

        const head = try table(data, "head") orelse return error.Malformed;
        const maxp = try table(data, "maxp") orelse return error.Malformed;
        const hhea = try table(data, "hhea") orelse return error.Malformed;
        const hmtx = try table(data, "hmtx") orelse return error.Malformed;
        const cmap = try table(data, "cmap") orelse return error.Malformed;

        const units_per_em = try readU16(head, 18);
        const num_hmetrics = try readU16(hhea, 34);
        if (units_per_em == 0 or num_hmetrics == 0 or hmtx.len < @as(usize, num_hmetrics) * 4) return error.Malformed;

        const outlines: Outlines = if (try table(data, "CFF ")) |cff_table|
            .{ .cff = try cff.Cff.parse(cff_table) }
        else
            .{ .glyf = .{
                .loca = try table(data, "loca") orelse return error.Malformed,
                .glyf = try table(data, "glyf") orelse return error.Malformed,
                .long_offsets = try readI16(head, 50) != 0,
            } };

        return .{
            .units_per_em = units_per_em,
            .num_glyphs = try readU16(maxp, 4),
            .num_hmetrics = num_hmetrics,
            .hmtx = hmtx,
            .cmap = try chooseCmap(cmap),
            .outlines = outlines,
        };
    }

    /// Glifo do caractere `codepoint` (0 = `.notdef` quando nao existe).
    pub fn glyphIndex(self: Font, codepoint: u21) u16 {
        return lookup(self.cmap, codepoint) catch 0;
    }

    /// Avanco horizontal do glifo, em unidades da fonte.
    pub fn advance(self: Font, gid: u16) u16 {
        const i = @min(gid, self.num_hmetrics - 1);
        return readU16(self.hmtx, @as(usize, i) * 4) catch 0;
    }

    /// Desenha o contorno do glifo `gid` em `path` (em unidades da fonte),
    /// com todos os contornos fechados, pronto para `raster.rasterize`.
    pub fn outline(self: Font, gid: u16, path: *Path) Error!void {
        if (gid >= self.num_glyphs) return error.Malformed;
        switch (self.outlines) {
            .cff => |c| try c.outline(gid, path),
            .glyf => try self.glyfOutline(gid, path, .{}, 0),
        }
        try path.close();
    }

    fn glyphData(self: Font, gid: u16) Error![]const u8 {
        const g = self.outlines.glyf;
        const start: usize, const end: usize = if (g.long_offsets)
            .{ try readU32(g.loca, @as(usize, gid) * 4), try readU32(g.loca, (@as(usize, gid) + 1) * 4) }
        else
            .{ @as(usize, try readU16(g.loca, @as(usize, gid) * 2)) * 2, @as(usize, try readU16(g.loca, (@as(usize, gid) + 1) * 2)) * 2 };
        if (start > end or end > g.glyf.len) return error.Malformed;
        return g.glyf[start..end];
    }

    fn glyfOutline(self: Font, gid: u16, path: *Path, transform: Affine, depth: u32) Error!void {
        if (depth > 8) return error.Malformed;
        const glyph = try self.glyphData(gid);
        if (glyph.len == 0) return; // espaco: sem contorno
        const contours = try readI16(glyph, 0);
        if (contours >= 0) {
            try simpleOutline(glyph, @intCast(contours), path, transform);
        } else {
            try self.compositeOutline(glyph, path, transform, depth);
        }
    }

    fn compositeOutline(self: Font, glyph: []const u8, path: *Path, transform: Affine, depth: u32) Error!void {
        const arg_words = 0x0001;
        const args_are_xy = 0x0002;
        const have_scale = 0x0008;
        const more_components = 0x0020;
        const xy_scale = 0x0040;
        const two_by_two = 0x0080;

        var pos: usize = 10;
        while (true) {
            const flags = try readU16(glyph, pos);
            const component = try readU16(glyph, pos + 2);
            pos += 4;
            // Encaixe por pontos (sem deslocamento x/y) nao aparece nas fontes usadas.
            if (flags & args_are_xy == 0) return error.Unsupported;

            var m: Affine = .{};
            if (flags & arg_words != 0) {
                m.e = @floatFromInt(try readI16(glyph, pos));
                m.f = @floatFromInt(try readI16(glyph, pos + 2));
                pos += 4;
            } else {
                if (pos + 2 > glyph.len) return error.Malformed;
                m.e = @floatFromInt(@as(i8, @bitCast(glyph[pos])));
                m.f = @floatFromInt(@as(i8, @bitCast(glyph[pos + 1])));
                pos += 2;
            }
            if (flags & have_scale != 0) {
                m.a = try f2dot14(glyph, pos);
                m.d = m.a;
                pos += 2;
            } else if (flags & xy_scale != 0) {
                m.a = try f2dot14(glyph, pos);
                m.d = try f2dot14(glyph, pos + 2);
                pos += 4;
            } else if (flags & two_by_two != 0) {
                m.a = try f2dot14(glyph, pos);
                m.b = try f2dot14(glyph, pos + 2);
                m.c = try f2dot14(glyph, pos + 4);
                m.d = try f2dot14(glyph, pos + 6);
                pos += 8;
            }
            if (component >= self.num_glyphs) return error.Malformed;
            try self.glyfOutline(component, path, m.then(transform), depth + 1);
            if (flags & more_components == 0) break;
        }
    }
};

fn f2dot14(data: []const u8, offset: usize) Error!f32 {
    return @as(f32, @floatFromInt(try readI16(data, offset))) / 16384;
}

const GlyfPoint = struct { x: f32, y: f32, on: bool };

fn simpleOutline(glyph: []const u8, contours: usize, path: *Path, transform: Affine) Error!void {
    if (contours == 0) return;
    const end_pts = 10;
    const points: usize = @as(usize, try readU16(glyph, end_pts + (contours - 1) * 2)) + 1;
    const instructions = try readU16(glyph, end_pts + contours * 2);
    var pos = end_pts + contours * 2 + 2 + instructions;

    // Buffers na pilha bastam para os glifos comuns; so os enormes alocam.
    var pts_buf: [512]GlyfPoint = undefined;
    var flags_buf: [512]u8 = undefined;
    const on_stack = points <= pts_buf.len;
    const pts = if (on_stack) pts_buf[0..points] else try path.gpa.alloc(GlyfPoint, points);
    defer if (!on_stack) path.gpa.free(pts);
    const flags = if (on_stack) flags_buf[0..points] else try path.gpa.alloc(u8, points);
    defer if (!on_stack) path.gpa.free(flags);

    // Flags, com repeticao (bit 3).
    var i: usize = 0;
    while (i < points) {
        if (pos >= glyph.len) return error.Malformed;
        const flag = glyph[pos];
        pos += 1;
        var repeat: usize = 1;
        if (flag & 0x08 != 0) {
            if (pos >= glyph.len) return error.Malformed;
            repeat += glyph[pos];
            pos += 1;
        }
        if (i + repeat > points) return error.Malformed;
        @memset(flags[i..][0..repeat], flag);
        i += repeat;
    }

    // Coordenadas x e depois y, relativas ao ponto anterior.
    for ([_]struct { short: u8, same: u8 }{ .{ .short = 0x02, .same = 0x10 }, .{ .short = 0x04, .same = 0x20 } }, 0..) |bits, axis| {
        var value: i32 = 0;
        for (flags, pts) |flag, *p| {
            if (flag & bits.short != 0) {
                if (pos >= glyph.len) return error.Malformed;
                const delta: i32 = glyph[pos];
                pos += 1;
                value += if (flag & bits.same != 0) delta else -delta;
            } else if (flag & bits.same == 0) {
                value += try readI16(glyph, pos);
                pos += 2;
            }
            if (axis == 0) p.x = @floatFromInt(value) else p.y = @floatFromInt(value);
        }
    }
    for (flags, pts) |flag, *p| {
        const t = transform.apply(p.x, p.y);
        p.* = .{ .x = t[0], .y = t[1], .on = flag & 0x01 != 0 };
    }

    var start: usize = 0;
    for (0..contours) |c| {
        const end = @as(usize, try readU16(glyph, end_pts + c * 2)) + 1;
        if (end <= start or end > points) return error.Malformed;
        try emitContour(pts[start..end], path);
        start = end;
    }
}

/// Um contorno TrueType: entre dois pontos de controle seguidos existe um
/// ponto na curva implicito, no meio deles.
fn emitContour(pts: []const GlyfPoint, path: *Path) Error!void {
    const n = pts.len;
    const first_on = for (pts, 0..) |p, i| {
        if (p.on) break i;
    } else null;

    // Comeca no primeiro ponto na curva e da a volta ate ele; so com pontos
    // de controle, comeca no meio do ultimo com o primeiro.
    const start: GlyfPoint = if (first_on) |f| pts[f] else .{
        .x = (pts[n - 1].x + pts[0].x) / 2,
        .y = (pts[n - 1].y + pts[0].y) / 2,
        .on = true,
    };
    const begin = if (first_on) |f| f + 1 else 0;

    try path.moveTo(start.x, start.y);
    var control: ?GlyfPoint = null;
    for (0..n) |k| {
        const p = pts[(begin + k) % n];
        if (p.on) {
            if (control) |c| try path.quadTo(c.x, c.y, p.x, p.y) else try path.lineTo(p.x, p.y);
            control = null;
        } else {
            if (control) |c| try path.quadTo(c.x, c.y, (c.x + p.x) / 2, (c.y + p.y) / 2);
            control = p;
        }
    }
    if (control) |c| try path.quadTo(c.x, c.y, start.x, start.y);
}

/// Escolhe a subtabela Unicode do `cmap`: formato 4 (BMP) ou 12.
fn chooseCmap(cmap: []const u8) Error!Cmap {
    const count = try readU16(cmap, 2);
    var best: ?Cmap = null;
    var best_rank: u8 = 0;
    for (0..count) |i| {
        const record = 4 + i * 8;
        const platform = try readU16(cmap, record);
        const encoding = try readU16(cmap, record + 2);
        const offset = try readU32(cmap, record + 4);
        if (offset >= cmap.len) return error.Malformed;
        const subtable = cmap[offset..];
        const format = try readU16(subtable, 0);
        const unicode = platform == 0 or (platform == 3 and (encoding == 1 or encoding == 10));
        if (!unicode or (format != 4 and format != 12)) continue;
        const rank: u8 = if (platform == 3 and format == 4) 4 else if (format == 4) 3 else if (platform == 3) 2 else 1;
        if (rank > best_rank) {
            best = .{ .subtable = subtable, .format = format };
            best_rank = rank;
        }
    }
    return best orelse error.Unsupported;
}

fn lookup(cmap: Cmap, codepoint: u21) Error!u16 {
    const s = cmap.subtable;
    if (cmap.format == 12) {
        const groups = try readU32(s, 12);
        for (0..groups) |i| {
            const g = 16 + i * 12;
            const first = try readU32(s, g);
            const last = try readU32(s, g + 4);
            if (codepoint >= first and codepoint <= last) {
                return @truncate(try readU32(s, g + 8) + (codepoint - first));
            }
        }
        return 0;
    }

    if (codepoint > 0xFFFF) return 0;
    const c: u16 = @intCast(codepoint);
    const seg_x2: usize = try readU16(s, 6);
    const end_codes = 14;
    const start_codes = end_codes + seg_x2 + 2;
    const deltas = start_codes + seg_x2;
    const range_offsets = deltas + seg_x2;
    var i: usize = 0;
    while (i < seg_x2) : (i += 2) {
        if (c > try readU16(s, end_codes + i)) continue;
        const start = try readU16(s, start_codes + i);
        if (c < start) return 0;
        const delta = try readU16(s, deltas + i);
        const range_offset = try readU16(s, range_offsets + i);
        if (range_offset == 0) return c +% delta;
        // `idRangeOffset` e relativo a posicao da propria entrada.
        const glyph = try readU16(s, range_offsets + i + range_offset + @as(usize, c - start) * 2);
        return if (glyph == 0) 0 else glyph +% delta;
    }
    return 0;
}

const testing = std.testing;

/// Monta uma fonte TrueType minima com 4 glifos:
/// 0 vazio, 1 quadrado 100x100, 2 composto (glifo 1 deslocado e com escala
/// 0,5) e 3 so com pontos de controle. `cmap`: A..C -> 1..3 e U+00E9 -> 2.
fn buildTestFont(gpa: std.mem.Allocator) ![]u8 {
    const W = struct {
        list: std.ArrayList(u8) = .empty,
        gpa: std.mem.Allocator,
        fn u16be(w: *@This(), v: u16) !void {
            try w.list.appendSlice(w.gpa, &std.mem.toBytes(std.mem.nativeToBig(u16, v)));
        }
        fn i16be(w: *@This(), v: i16) !void {
            try w.u16be(@bitCast(v));
        }
        fn u32be(w: *@This(), v: u32) !void {
            try w.list.appendSlice(w.gpa, &std.mem.toBytes(std.mem.nativeToBig(u32, v)));
        }
        fn pad(w: *@This(), len: usize) !void {
            try w.list.appendNTimes(w.gpa, 0, len);
        }
    };

    // glyf
    var glyf: W = .{ .gpa = gpa };
    defer glyf.list.deinit(gpa);
    var loca: [5]u32 = undefined;
    loca[0] = 0;
    loca[1] = 0;
    // Glifo 1: um contorno, 4 pontos na curva, coordenadas de 16 bits.
    try glyf.i16be(1);
    try glyf.pad(8);
    try glyf.u16be(3);
    try glyf.u16be(0);
    try glyf.list.appendSlice(gpa, &.{ 0x01 | 0x08, 3 });
    for ([_]i16{ 0, 100, 0, -100 }) |x| try glyf.i16be(x);
    for ([_]i16{ 0, 0, 100, 0 }) |y| try glyf.i16be(y);
    loca[2] = @intCast(glyf.list.items.len);
    // Glifo 2: composto, argumentos de 16 bits, x/y, escala unica.
    try glyf.i16be(-1);
    try glyf.pad(8);
    try glyf.u16be(0x0001 | 0x0002 | 0x0008);
    try glyf.u16be(1);
    try glyf.i16be(200);
    try glyf.i16be(50);
    try glyf.i16be(0x2000); // 0,5 em F2Dot14
    loca[3] = @intCast(glyf.list.items.len);
    // Glifo 3: quatro pontos de controle (um "circulo"), coordenadas curtas.
    try glyf.i16be(1);
    try glyf.pad(8);
    try glyf.u16be(3);
    try glyf.u16be(0);
    // x: +50 (curto positivo), +50, -50, -50; y: 0, +50, +50, -50.
    try glyf.list.appendSlice(gpa, &.{ 0x02 | 0x10 | 0x20, 0x02 | 0x10 | 0x04 | 0x20, 0x02 | 0x04 | 0x20, 0x02 | 0x04 });
    try glyf.list.appendSlice(gpa, &.{ 50, 50, 50, 50 });
    try glyf.list.appendSlice(gpa, &.{ 50, 50, 50 });
    loca[4] = @intCast(glyf.list.items.len);

    // cmap formato 4 com 3 segmentos: 65..67 (delta), 0xE9 (glyphIdArray), 0xFFFF.
    var cmap: W = .{ .gpa = gpa };
    defer cmap.list.deinit(gpa);
    try cmap.u16be(0);
    try cmap.u16be(1);
    try cmap.u16be(3);
    try cmap.u16be(1);
    try cmap.u32be(12);
    try cmap.u16be(4);
    try cmap.u16be(0); // tamanho (nao usado)
    try cmap.u16be(0);
    try cmap.u16be(6);
    try cmap.pad(6);
    for ([_]u16{ 67, 0xE9, 0xFFFF }) |v| try cmap.u16be(v);
    try cmap.u16be(0);
    for ([_]u16{ 65, 0xE9, 0xFFFF }) |v| try cmap.u16be(v);
    for ([_]u16{ @bitCast(@as(i16, 1 - 65)), 0, 1 }) |v| try cmap.u16be(v);
    for ([_]u16{ 0, 4, 0 }) |v| try cmap.u16be(v);
    try cmap.u16be(2);

    var head: [54]u8 = @splat(0);
    std.mem.writeInt(u16, head[18..20], 1000, .big);
    std.mem.writeInt(u16, head[50..52], 1, .big);
    var maxp: [6]u8 = @splat(0);
    std.mem.writeInt(u16, maxp[4..6], 4, .big);
    var hhea: [36]u8 = @splat(0);
    std.mem.writeInt(u16, hhea[34..36], 2, .big);
    var hmtx: [8]u8 = @splat(0);
    std.mem.writeInt(u16, hmtx[0..2], 500, .big);
    std.mem.writeInt(u16, hmtx[4..6], 600, .big);
    var loca_bytes: [20]u8 = undefined;
    for (loca, 0..) |v, i| std.mem.writeInt(u32, loca_bytes[i * 4 ..][0..4], v, .big);

    const tables = [_]struct { tag: *const [4]u8, data: []const u8 }{
        .{ .tag = "cmap", .data = cmap.list.items },
        .{ .tag = "glyf", .data = glyf.list.items },
        .{ .tag = "head", .data = &head },
        .{ .tag = "hhea", .data = &hhea },
        .{ .tag = "hmtx", .data = &hmtx },
        .{ .tag = "loca", .data = &loca_bytes },
        .{ .tag = "maxp", .data = &maxp },
    };
    var out: W = .{ .gpa = gpa };
    errdefer out.list.deinit(gpa);
    try out.u32be(0x00010000);
    try out.u16be(tables.len);
    try out.pad(6);
    var offset: u32 = 12 + tables.len * 16;
    for (tables) |t| {
        try out.list.appendSlice(gpa, t.tag);
        try out.u32be(0);
        try out.u32be(offset);
        try out.u32be(@intCast(t.data.len));
        offset += @intCast(t.data.len);
    }
    for (tables) |t| try out.list.appendSlice(gpa, t.data);
    return out.list.toOwnedSlice(gpa);
}

const raster = @import("raster.zig");

fn rasterizeGlyph(font: Font, gid: u16, scale: f32, pool: *std.ArrayList(u8)) !raster.Box {
    var path: Path = .init(testing.allocator, scale);
    defer path.deinit();
    try font.outline(gid, &path);
    return raster.rasterize(testing.allocator, &path, pool);
}

test "fonte sintetica: cmap, larguras e glifos simples e compostos" {
    const data = try buildTestFont(testing.allocator);
    defer testing.allocator.free(data);
    const font = try Font.parse(data);
    try testing.expectEqual(@as(u16, 1000), font.units_per_em);
    try testing.expectEqual(@as(u16, 1), font.glyphIndex('A'));
    try testing.expectEqual(@as(u16, 3), font.glyphIndex('C'));
    try testing.expectEqual(@as(u16, 2), font.glyphIndex(0xE9));
    try testing.expectEqual(@as(u16, 0), font.glyphIndex('D'));
    try testing.expectEqual(@as(u16, 0), font.glyphIndex(0x1F600));
    try testing.expectEqual(@as(u16, 500), font.advance(0));
    try testing.expectEqual(@as(u16, 600), font.advance(3));

    var pool: std.ArrayList(u8) = .empty;
    defer pool.deinit(testing.allocator);
    // Escala 0,1: o quadrado de 100 vira 10x10 pixels acima da linha de base.
    const square = try rasterizeGlyph(font, 1, 0.1, &pool);
    try testing.expectEqual(raster.Box{ .x0 = 0, .y0 = -10, .width = 10, .height = 10, .offset = 0 }, square);
    // Composto: 50x50 deslocado de (200, 50) -> 5x5 pixels em (20, -10).
    const composite = try rasterizeGlyph(font, 2, 0.1, &pool);
    try testing.expectEqual(@as(i32, 20), composite.x0);
    try testing.expectEqual(@as(i32, -10), composite.y0);
    try testing.expectEqual(@as(u32, 5), composite.width);
    // So pontos de controle: curva fechada dentro do losango (0..100, -50..50).
    const round = try rasterizeGlyph(font, 3, 0.1, &pool);
    try testing.expect(round.width > 0 and round.width <= 10 and round.height <= 10);
    const empty = try rasterizeGlyph(font, 0, 0.1, &pool);
    try testing.expectEqual(@as(u32, 0), empty.width);
}

test "fonte invalida gera erro" {
    try testing.expectError(error.Malformed, Font.parse(&.{ 0, 1, 0, 0 }));
    try testing.expectError(error.Unsupported, Font.parse("ttcf\x00\x00\x00\x00"));
    const data = try buildTestFont(testing.allocator);
    defer testing.allocator.free(data);
    try testing.expectError(error.Malformed, Font.parse(data[0 .. data.len / 2]));
}

// Fontes do sistema, quando instaladas: todos os glifos Latin-1 precisam
// ser lidos e rasterizados.
test "fontes do sistema" {
    const cases = [_]struct { path: []const u8, upem: u16, a_gid: u16, a_adv: u16, e_gid: u16 }{
        .{ .path = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", .upem = 2048, .a_gid = 36, .a_adv = 1585, .e_gid = 171 },
        .{ .path = "/usr/share/fonts/opentype/urw-base35/URWBookman-Demi.otf", .upem = 1000, .a_gid = 34, .a_adv = 720, .e_gid = 207 },
        .{ .path = "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf", .upem = 2048, .a_gid = 36, .a_adv = 1479, .e_gid = 171 },
    };
    var found = false;
    for (cases) |case| {
        const data = std.Io.Dir.cwd().readFileAlloc(testing.io, case.path, testing.allocator, .limited(32 << 20)) catch continue;
        defer testing.allocator.free(data);
        found = true;
        const font = try Font.parse(data);
        try testing.expectEqual(case.upem, font.units_per_em);
        try testing.expectEqual(case.a_gid, font.glyphIndex('A'));
        try testing.expectEqual(case.a_adv, font.advance(case.a_gid));
        try testing.expectEqual(case.e_gid, font.glyphIndex(0xE9));

        var pool: std.ArrayList(u8) = .empty;
        defer pool.deinit(testing.allocator);
        const scale = 40 / @as(f32, @floatFromInt(font.units_per_em));
        for ([_][2]u21{ .{ 33, 126 }, .{ 160, 255 } }) |range| {
            for (range[0]..range[1] + 1) |cp| {
                _ = try rasterizeGlyph(font, font.glyphIndex(@intCast(cp)), scale, &pool);
            }
        }
        // "A" de 40 pontos: cobertura cheia em algum pixel e altura plausivel.
        pool.clearRetainingCapacity();
        const a = try rasterizeGlyph(font, case.a_gid, scale, &pool);
        try testing.expect(a.height >= 25 and a.height <= 32);
        try testing.expect(a.y0 + @as(i32, @intCast(a.height)) <= 1);
        try testing.expect(std.mem.indexOfScalar(u8, pool.items, 255) != null);
    }
    if (!found) return error.SkipZigTest;
}
