//! Leitura minima das metricas de uma fonte TrueType/OpenType.
//!
//! O tamanho de fonte do Java e o tamanho do "em"; o raylib (stb_truetype)
//! usa ascent - descent da tabela `hhea`. Estas metricas permitem converter
//! um para o outro e achar a linha de base usada pelo `drawString` do Java.

const std = @import("std");

pub const Metrics = struct {
    units_per_em: i32,
    ascender: i32,
    descender: i32,

    /// Tamanho a pedir ao raylib para obter o mesmo "em" do Java.
    pub fn raylibSize(m: Metrics, java_size: i32) i32 {
        const size: f32 = @floatFromInt(java_size * (m.ascender - m.descender));
        return @intFromFloat(@round(size / @as(f32, @floatFromInt(m.units_per_em))));
    }

    /// Distancia do topo do glifo (posicao do raylib) ate a linha de base.
    pub fn baselineOffset(m: Metrics, java_size: i32) i32 {
        const size: f32 = @floatFromInt(java_size * m.ascender);
        return @intFromFloat(@round(size / @as(f32, @floatFromInt(m.units_per_em))));
    }
};

fn readU16(data: []const u8, offset: usize) ?u16 {
    if (offset + 2 > data.len) return null;
    return std.mem.readInt(u16, data[offset..][0..2], .big);
}

fn readU32(data: []const u8, offset: usize) ?u32 {
    if (offset + 4 > data.len) return null;
    return std.mem.readInt(u32, data[offset..][0..4], .big);
}

fn findTable(data: []const u8, tag: *const [4]u8) ?usize {
    const num_tables = readU16(data, 4) orelse return null;
    for (0..num_tables) |i| {
        const record = 12 + i * 16;
        if (record + 16 > data.len) return null;
        if (std.mem.eql(u8, data[record..][0..4], tag)) {
            const offset = readU32(data, record + 8) orelse return null;
            return offset;
        }
    }
    return null;
}

/// Le `unitsPerEm` (tabela `head`) e ascender/descender (tabela `hhea`).
pub fn parse(data: []const u8) ?Metrics {
    const head = findTable(data, "head") orelse return null;
    const hhea = findTable(data, "hhea") orelse return null;
    const upem = readU16(data, head + 18) orelse return null;
    const asc = readU16(data, hhea + 4) orelse return null;
    const desc = readU16(data, hhea + 6) orelse return null;
    if (upem == 0) return null;
    return .{
        .units_per_em = upem,
        .ascender = @as(i16, @bitCast(asc)),
        .descender = @as(i16, @bitCast(desc)),
    };
}

test "parse le head e hhea" {
    var font = [_]u8{0} ** 128;
    // Diretorio com 2 tabelas.
    std.mem.writeInt(u16, font[4..6], 2, .big);
    @memcpy(font[12..16], "head");
    std.mem.writeInt(u32, font[20..24], 44, .big);
    @memcpy(font[28..32], "hhea");
    std.mem.writeInt(u32, font[36..40], 80, .big);
    std.mem.writeInt(u16, font[44 + 18 ..][0..2], 2048, .big);
    std.mem.writeInt(i16, font[80 + 4 ..][0..2], 1900, .big);
    std.mem.writeInt(i16, font[80 + 6 ..][0..2], -500, .big);

    const m = parse(&font).?;
    try std.testing.expectEqual(@as(i32, 2048), m.units_per_em);
    try std.testing.expectEqual(@as(i32, 1900), m.ascender);
    try std.testing.expectEqual(@as(i32, -500), m.descender);
    try std.testing.expectEqual(@as(i32, 47), m.raylibSize(40));
    try std.testing.expectEqual(@as(i32, 37), m.baselineOffset(40));
    try std.testing.expectEqual(@as(?Metrics, null), parse(font[0..8]));
}
