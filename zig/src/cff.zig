//! Contornos de fontes OpenType com tabela `CFF ` (curvas cubicas), como a
//! URW Bookman do Linux.
//!
//! Le o necessario da Compact Font Format (INDEX, Top DICT, Private DICT,
//! subrotinas) e interpreta as charstrings Type 2. Dicas (hints) sao
//! ignoradas; operadores que a fonte nao deveria usar em glifos latinos (seac,
//! aritmetica, CFF com CID) geram `error.Unsupported`, e o texto passa a usar a
//! proxima fonte da lista.

const std = @import("std");
const Path = @import("raster.zig").Path;

pub const Error = error{ Malformed, Unsupported, OutOfMemory };

/// Uma estrutura INDEX: `count` blocos de bytes indexados.
const Index = struct {
    data: []const u8,
    count: u32 = 0,
    off_size: u8 = 0,
    /// Posicao da tabela de deslocamentos.
    offsets: usize = 0,
    /// Os deslocamentos comecam em 1: o bloco i comeca em `base + offset[i]`.
    base: usize = 0,
    /// Primeiro byte depois do INDEX.
    end: usize,

    fn parse(data: []const u8, pos: usize) Error!Index {
        if (pos + 2 > data.len) return error.Malformed;
        const count = std.mem.readInt(u16, data[pos..][0..2], .big);
        if (count == 0) return .{ .data = data, .end = pos + 2 };
        if (pos + 3 > data.len) return error.Malformed;
        const off_size = data[pos + 2];
        if (off_size < 1 or off_size > 4) return error.Malformed;
        var index: Index = .{
            .data = data,
            .count = count,
            .off_size = off_size,
            .offsets = pos + 3,
            .base = pos + 3 + (@as(usize, count) + 1) * off_size - 1,
            .end = 0,
        };
        index.end = index.base + try index.offset(count);
        if (index.end > data.len) return error.Malformed;
        return index;
    }

    fn offset(self: Index, i: usize) Error!usize {
        const pos = self.offsets + i * self.off_size;
        if (pos + self.off_size > self.data.len) return error.Malformed;
        var value: usize = 0;
        for (self.data[pos..][0..self.off_size]) |b| value = value << 8 | b;
        return value;
    }

    fn get(self: Index, i: usize) Error![]const u8 {
        if (i >= self.count) return error.Malformed;
        const start = self.base + try self.offset(i);
        const end = self.base + try self.offset(i + 1);
        if (start > end or end > self.data.len) return error.Malformed;
        return self.data[start..end];
    }

    /// Ajuste somado ao numero da subrotina chamada (`callsubr`/`callgsubr`).
    fn bias(self: Index) i32 {
        if (self.count < 1240) return 107;
        if (self.count < 33900) return 1131;
        return 32768;
    }
};

/// Operadores de DICT de dois bytes (12 x) viram 1200 + x.
const op_charstrings = 17;
const op_private = 18;
const op_subrs = 19;
const op_charstring_type = 1206;
const op_ros = 1230;

/// Procura o operador `op` no DICT e copia seus operandos para `out`;
/// devolve quantos operandos encontrou ou `null` se o operador nao existe.
fn dictLookup(dict: []const u8, op: u16, out: []f64) Error!?usize {
    var operands: [48]f64 = undefined;
    var n: usize = 0;
    var i: usize = 0;
    while (i < dict.len) {
        const b = dict[i];
        if (b <= 21) {
            var key: u16 = b;
            i += 1;
            if (b == 12) {
                if (i >= dict.len) return error.Malformed;
                key = 1200 + @as(u16, dict[i]);
                i += 1;
            }
            if (key == op) {
                const count = @min(n, out.len);
                @memcpy(out[0..count], operands[0..count]);
                return n;
            }
            n = 0;
            continue;
        }
        if (n == operands.len) return error.Malformed;
        operands[n] = switch (b) {
            28 => blk: {
                if (i + 3 > dict.len) return error.Malformed;
                defer i += 3;
                break :blk @floatFromInt(std.mem.readInt(i16, dict[i + 1 ..][0..2], .big));
            },
            29 => blk: {
                if (i + 5 > dict.len) return error.Malformed;
                defer i += 5;
                break :blk @floatFromInt(std.mem.readInt(i32, dict[i + 1 ..][0..4], .big));
            },
            30 => blk: {
                // Numero real em nibbles; so precisamos pular (vale 0 aqui).
                i += 1;
                while (i < dict.len) : (i += 1) {
                    if (dict[i] & 0x0F == 0x0F or dict[i] >> 4 == 0x0F) break;
                }
                i += 1;
                break :blk 0;
            },
            32...246 => blk: {
                i += 1;
                break :blk @floatFromInt(@as(i32, b) - 139);
            },
            247...254 => blk: {
                if (i + 2 > dict.len) return error.Malformed;
                const b1: i32 = dict[i + 1];
                i += 2;
                break :blk @floatFromInt(if (b <= 250) (@as(i32, b) - 247) * 256 + b1 + 108 else -(@as(i32, b) - 251) * 256 - b1 - 108);
            },
            else => return error.Malformed,
        };
        n += 1;
    }
    return null;
}

pub const Cff = struct {
    charstrings: Index,
    global_subrs: Index,
    local_subrs: Index,

    /// `table` e o conteudo da tabela `CFF ` da fonte.
    pub fn parse(table: []const u8) Error!Cff {
        if (table.len < 4 or table[0] != 1) return error.Unsupported;
        const names = try Index.parse(table, table[2]);
        const top_dicts = try Index.parse(table, names.end);
        const strings = try Index.parse(table, top_dicts.end);
        const global_subrs = try Index.parse(table, strings.end);
        const top = try top_dicts.get(0);

        var args: [2]f64 = undefined;
        if (try dictLookup(top, op_ros, &args) != null) return error.Unsupported;
        if (try dictLookup(top, op_charstring_type, &args)) |n| {
            if (n != 1 or args[0] != 2) return error.Unsupported;
        }
        if (try dictLookup(top, op_charstrings, &args) != 1) return error.Malformed;
        const charstrings = try Index.parse(table, try toOffset(args[0], table.len));

        var local_subrs: Index = .{ .data = table, .end = 0 };
        if (try dictLookup(top, op_private, &args) == 2) {
            const size = try toOffset(args[0], table.len);
            const start = try toOffset(args[1], table.len);
            if (start + size > table.len) return error.Malformed;
            const private = table[start..][0..size];
            if (try dictLookup(private, op_subrs, &args) == 1) {
                local_subrs = try Index.parse(table, try toOffset(@as(f64, @floatFromInt(start)) + args[0], table.len));
            }
        }
        return .{ .charstrings = charstrings, .global_subrs = global_subrs, .local_subrs = local_subrs };
    }

    pub fn numGlyphs(self: Cff) u32 {
        return self.charstrings.count;
    }

    /// Desenha o glifo `gid` em `path` (em unidades da fonte).
    pub fn outline(self: Cff, gid: u16, path: *Path) Error!void {
        var interp: Interpreter = .{ .cff = &self, .path = path };
        _ = try interp.run(try self.charstrings.get(gid), 0);
        try path.close();
    }
};

fn toOffset(value: f64, limit: usize) Error!usize {
    if (value < 0 or value > @as(f64, @floatFromInt(limit))) return error.Malformed;
    return @intFromFloat(value);
}

/// Estado da execucao de uma charstring Type 2.
const Interpreter = struct {
    cff: *const Cff,
    path: *Path,
    stack: [48]f32 = undefined,
    sp: usize = 0,
    x: f32 = 0,
    y: f32 = 0,
    stems: usize = 0,
    width_done: bool = false,

    fn push(self: *Interpreter, value: f32) Error!void {
        if (self.sp == self.stack.len) return error.Malformed;
        self.stack[self.sp] = value;
        self.sp += 1;
    }

    fn need(self: *Interpreter, count: usize) Error!void {
        if (self.sp < count) return error.Malformed;
    }

    /// O primeiro operador que limpa a pilha pode trazer a largura do glifo
    /// como argumento extra no inicio; ela vem do `hmtx`, entao e descartada.
    fn dropWidth(self: *Interpreter, has_extra: bool) void {
        if (self.width_done) return;
        self.width_done = true;
        if (has_extra and self.sp > 0) {
            std.mem.copyForwards(f32, self.stack[0 .. self.sp - 1], self.stack[1..self.sp]);
            self.sp -= 1;
        }
    }

    fn moveTo(self: *Interpreter, dx: f32, dy: f32) Error!void {
        self.x += dx;
        self.y += dy;
        try self.path.moveTo(self.x, self.y);
    }

    fn lineTo(self: *Interpreter, dx: f32, dy: f32) Error!void {
        self.x += dx;
        self.y += dy;
        try self.path.lineTo(self.x, self.y);
    }

    fn curveTo(self: *Interpreter, dx1: f32, dy1: f32, dx2: f32, dy2: f32, dx3: f32, dy3: f32) Error!void {
        const x1 = self.x + dx1;
        const y1 = self.y + dy1;
        const x2 = x1 + dx2;
        const y2 = y1 + dy2;
        self.x = x2 + dx3;
        self.y = y2 + dy3;
        try self.path.cubicTo(x1, y1, x2, y2, self.x, self.y);
    }

    fn countStems(self: *Interpreter) void {
        self.dropWidth(self.sp % 2 == 1);
        self.stems += self.sp / 2;
        self.sp = 0;
    }

    /// Executa `code`; devolve `true` ao encontrar `endchar`.
    fn run(self: *Interpreter, code: []const u8, depth: u32) Error!bool {
        if (depth > 10) return error.Malformed;
        var i: usize = 0;
        while (i < code.len) {
            const b = code[i];
            i += 1;
            switch (b) {
                32...246 => try self.push(@floatFromInt(@as(i32, b) - 139)),
                247...254 => {
                    if (i >= code.len) return error.Malformed;
                    const b1: i32 = code[i];
                    i += 1;
                    try self.push(@floatFromInt(if (b <= 250) (@as(i32, b) - 247) * 256 + b1 + 108 else -(@as(i32, b) - 251) * 256 - b1 - 108));
                },
                28 => {
                    if (i + 2 > code.len) return error.Malformed;
                    try self.push(@floatFromInt(std.mem.readInt(i16, code[i..][0..2], .big)));
                    i += 2;
                },
                255 => {
                    if (i + 4 > code.len) return error.Malformed;
                    const fixed = std.mem.readInt(i32, code[i..][0..4], .big);
                    try self.push(@as(f32, @floatFromInt(fixed)) / 65536);
                    i += 4;
                },
                // hstem, vstem, hstemhm, vstemhm
                1, 3, 18, 23 => self.countStems(),
                // hintmask, cntrmask: argumentos que sobraram sao um vstem implicito.
                19, 20 => {
                    self.countStems();
                    i += (self.stems + 7) / 8;
                },
                21 => { // rmoveto
                    self.dropWidth(self.sp > 2);
                    try self.need(2);
                    try self.moveTo(self.stack[0], self.stack[1]);
                    self.sp = 0;
                },
                22 => { // hmoveto
                    self.dropWidth(self.sp > 1);
                    try self.need(1);
                    try self.moveTo(self.stack[0], 0);
                    self.sp = 0;
                },
                4 => { // vmoveto
                    self.dropWidth(self.sp > 1);
                    try self.need(1);
                    try self.moveTo(0, self.stack[0]);
                    self.sp = 0;
                },
                5 => { // rlineto
                    var k: usize = 0;
                    while (k + 2 <= self.sp) : (k += 2) try self.lineTo(self.stack[k], self.stack[k + 1]);
                    self.sp = 0;
                },
                6, 7 => { // hlineto, vlineto: alternam horizontal e vertical
                    var horizontal = b == 6;
                    for (self.stack[0..self.sp]) |d| {
                        if (horizontal) try self.lineTo(d, 0) else try self.lineTo(0, d);
                        horizontal = !horizontal;
                    }
                    self.sp = 0;
                },
                8 => { // rrcurveto
                    try self.curves(0, self.sp);
                    self.sp = 0;
                },
                24 => { // rcurveline
                    try self.need(8);
                    const curve_end = self.sp - 2;
                    try self.curves(0, curve_end);
                    try self.lineTo(self.stack[curve_end], self.stack[curve_end + 1]);
                    self.sp = 0;
                },
                25 => { // rlinecurve
                    try self.need(8);
                    const line_end = self.sp - 6;
                    var k: usize = 0;
                    while (k + 2 <= line_end) : (k += 2) try self.lineTo(self.stack[k], self.stack[k + 1]);
                    try self.curves(line_end, self.sp);
                    self.sp = 0;
                },
                26 => { // vvcurveto: dx1? {dya dxb dyb dyc}+
                    var k: usize = 0;
                    var dx1: f32 = 0;
                    if (self.sp % 2 == 1) {
                        dx1 = self.stack[0];
                        k = 1;
                    }
                    while (k + 4 <= self.sp) : (k += 4) {
                        const s = self.stack[k..];
                        try self.curveTo(dx1, s[0], s[1], s[2], 0, s[3]);
                        dx1 = 0;
                    }
                    self.sp = 0;
                },
                27 => { // hhcurveto: dy1? {dxa dxb dyb dxc}+
                    var k: usize = 0;
                    var dy1: f32 = 0;
                    if (self.sp % 2 == 1) {
                        dy1 = self.stack[0];
                        k = 1;
                    }
                    while (k + 4 <= self.sp) : (k += 4) {
                        const s = self.stack[k..];
                        try self.curveTo(s[0], dy1, s[1], s[2], s[3], 0);
                        dy1 = 0;
                    }
                    self.sp = 0;
                },
                30, 31 => { // vhcurveto, hvcurveto: alternam a direcao inicial
                    try self.need(4);
                    var horizontal = b == 31;
                    var k: usize = 0;
                    while (k + 4 <= self.sp) : (k += 4) {
                        const s = self.stack[k..];
                        const last: f32 = if (self.sp - k == 5) s[4] else 0;
                        if (horizontal) {
                            try self.curveTo(s[0], 0, s[1], s[2], last, s[3]);
                        } else {
                            try self.curveTo(0, s[0], s[1], s[2], s[3], last);
                        }
                        horizontal = !horizontal;
                    }
                    self.sp = 0;
                },
                10, 29 => { // callsubr, callgsubr
                    try self.need(1);
                    self.sp -= 1;
                    const subrs = if (b == 10) self.cff.local_subrs else self.cff.global_subrs;
                    const index = @as(i32, @intFromFloat(self.stack[self.sp])) + subrs.bias();
                    if (index < 0) return error.Malformed;
                    if (try self.run(try subrs.get(@intCast(index)), depth + 1)) return true;
                },
                11 => return false, // return
                14 => { // endchar
                    self.dropWidth(self.sp == 1 or self.sp == 5);
                    // Com 4 argumentos e o "seac" (acento composto) do Type 1.
                    if (self.sp >= 4) return error.Unsupported;
                    return true;
                },
                12 => {
                    if (i >= code.len) return error.Malformed;
                    const op = code[i];
                    i += 1;
                    try self.flex(op);
                    self.sp = 0;
                },
                else => return error.Unsupported,
            }
        }
        return false;
    }

    /// Grupos de 6 argumentos de `rrcurveto` em `stack[from..to]`.
    fn curves(self: *Interpreter, from: usize, to: usize) Error!void {
        var k = from;
        while (k + 6 <= to) : (k += 6) {
            const s = self.stack[k..];
            try self.curveTo(s[0], s[1], s[2], s[3], s[4], s[5]);
        }
    }

    /// Operadores `flex`: duas curvas cubicas seguidas.
    fn flex(self: *Interpreter, op: u8) Error!void {
        const s = self.stack[0..self.sp];
        switch (op) {
            35 => { // flex
                try self.need(13);
                try self.curveTo(s[0], s[1], s[2], s[3], s[4], s[5]);
                try self.curveTo(s[6], s[7], s[8], s[9], s[10], s[11]);
            },
            34 => { // hflex
                try self.need(7);
                try self.curveTo(s[0], 0, s[1], s[2], s[3], 0);
                try self.curveTo(s[4], 0, s[5], -s[2], s[6], 0);
            },
            36 => { // hflex1
                try self.need(9);
                try self.curveTo(s[0], s[1], s[2], s[3], s[4], 0);
                try self.curveTo(s[5], 0, s[6], s[7], s[8], -(s[1] + s[3] + s[7]));
            },
            37 => { // flex1: o ultimo ponto volta na direcao de menor deslocamento
                try self.need(11);
                var dx: f32 = 0;
                var dy: f32 = 0;
                var k: usize = 0;
                while (k < 10) : (k += 2) {
                    dx += s[k];
                    dy += s[k + 1];
                }
                const start_x = self.x;
                const start_y = self.y;
                try self.curveTo(s[0], s[1], s[2], s[3], s[4], s[5]);
                const x1 = self.x + s[6];
                const y1 = self.y + s[7];
                const x2 = x1 + s[8];
                const y2 = y1 + s[9];
                const end_x, const end_y = if (@abs(dx) > @abs(dy)) .{ x2 + s[10], start_y } else .{ start_x, y2 + s[10] };
                try self.curveTo(s[6], s[7], s[8], s[9], end_x - x2, end_y - y2);
            },
            else => return error.Unsupported,
        }
    }
};

const testing = std.testing;
const raster = @import("raster.zig");

/// Monta um CFF minimo com uma subrotina local e uma charstring.
fn buildCff(comptime charstring: []const u8, comptime subr: []const u8) []const u8 {
    const header = [_]u8{ 1, 0, 4, 1 };
    const name_index = [_]u8{ 0, 1, 1, 1, 2, 'A' };
    // Top DICT: CharStrings (17) e Private (18); offsets fixos abaixo.
    const strings_index = [_]u8{ 0, 0 };
    const gsubrs_index = [_]u8{ 0, 0 };
    const top_index_len = 5 + 7; // cabecalho do INDEX + o `top` abaixo
    const charstrings_pos = header.len + name_index.len + top_index_len + strings_index.len + gsubrs_index.len;
    const charstrings_index = [_]u8{ 0, 1, 1, 1, 1 + charstring.len } ++ charstring[0..charstring.len].*;
    const private_pos = charstrings_pos + charstrings_index.len;
    const private = [_]u8{ 2 + 139, op_subrs }; // Subrs logo depois do Private DICT
    const subrs_index = [_]u8{ 0, 1, 1, 1, 1 + subr.len } ++ subr[0..subr.len].*;
    const top = [_]u8{ 28, 0, charstrings_pos, op_charstrings, private.len + 139, private_pos + 139, op_private };
    const top_index = [_]u8{ 0, 1, 1, 1, 1 + top.len } ++ top;
    return &(header ++ name_index ++ top_index ++ strings_index ++ gsubrs_index ++ charstrings_index ++ private ++ subrs_index);
}

test "interpreta um glifo com largura, hints, subrotina e endchar" {
    // largura 500 + hstemhm(2 stems) + hintmask(1 byte) + rmoveto 10 20 +
    // callsubr (subr 0 com bias 107: -107) + endchar.
    const t = 139;
    const charstring = [_]u8{ 247 + ((500 - 108) >> 8), (500 - 108) & 0xFF, t + 0, t + 10, t + 0, t + 10, 18, 19, 0xC0, t + 10, t + 20, 21, t - 107, 10, 14 };
    // Subrotina: quadrado de 30 com rlineto e hlineto/vlineto, depois return.
    const subr = [_]u8{ t + 30, t + 0, 5, t + 30, 7, t - 30, 6, 11 };
    const cff = try Cff.parse(buildCff(&charstring, &subr));
    try testing.expectEqual(@as(u32, 1), cff.numGlyphs());

    var path: raster.Path = .init(testing.allocator, 1);
    defer path.deinit();
    try cff.outline(0, &path);
    var pool: std.ArrayList(u8) = .empty;
    defer pool.deinit(testing.allocator);
    const box = try raster.rasterize(testing.allocator, &path, &pool);
    try testing.expectEqual(raster.Box{ .x0 = 10, .y0 = -50, .width = 30, .height = 30, .offset = 0 }, box);
    for (pool.items) |c| try testing.expectEqual(@as(u8, 255), c);
}

test "seac e operadores desconhecidos sao rejeitados" {
    const t = 139;
    const seac = [_]u8{ t, t, t, t, 14 };
    const cff = try Cff.parse(buildCff(&seac, &.{11}));
    var path: raster.Path = .init(testing.allocator, 1);
    defer path.deinit();
    try testing.expectError(error.Unsupported, cff.outline(0, &path));

    const unknown = [_]u8{ 12, 9 };
    const cff2 = try Cff.parse(buildCff(&unknown, &.{11}));
    try testing.expectError(error.Unsupported, cff2.outline(0, &path));
}

test "curvas: hvcurveto com argumento final e flex" {
    const t = 139;
    // hvcurveto 10 10 10 10 5 + hflex + endchar a partir de rmoveto 0 0.
    const charstring = [_]u8{ t, t, 21, t + 10, t + 10, t + 10, t + 10, t + 5, 31, t + 1, t + 2, t + 3, t + 4, t + 5, t + 6, t + 7, 12, 34, 14 };
    const cff = try Cff.parse(buildCff(&charstring, &.{11}));
    var path: raster.Path = .init(testing.allocator, 1);
    defer path.deinit();
    try cff.outline(0, &path);
    // Fim da hvcurveto: (10 + 10 + 5, 10 + 10); o hflex anda 1+2+4+5+6+7 em x.
    const last = path.lines.items[path.lines.items.len - 2].p1;
    try testing.expectApproxEqAbs(@as(f32, 25 + 25), last.x, 0.001);
    try testing.expectApproxEqAbs(@as(f32, -20), last.y, 0.001);
}
