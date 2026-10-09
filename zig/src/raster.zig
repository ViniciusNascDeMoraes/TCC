//! Rasterizacao dos contornos dos glifos com antialiasing.
//!
//! As curvas viram segmentos de reta e cada segmento soma, nas celulas que
//! atravessa, a area com sinal que fica a sua direita (o metodo do font-rs e
//! do stb_truetype). A soma acumulada ao longo de cada linha da a cobertura
//! de cada pixel.

const std = @import("std");

pub const Point = struct {
    x: f32,
    y: f32,

    fn mid(a: Point, b: Point) Point {
        return .{ .x = (a.x + b.x) / 2, .y = (a.y + b.y) / 2 };
    }
};

const Line = struct { p0: Point, p1: Point };

/// Contorno de um glifo em pixels, com o eixo y para baixo. Os pontos chegam
/// em unidades da fonte (y para cima) e sao multiplicados por `scale`.
pub const Path = struct {
    gpa: std.mem.Allocator,
    scale: f32,
    lines: std.ArrayList(Line) = .empty,
    start: Point = .{ .x = 0, .y = 0 },
    current: Point = .{ .x = 0, .y = 0 },

    pub fn init(gpa: std.mem.Allocator, scale: f32) Path {
        return .{ .gpa = gpa, .scale = scale };
    }

    pub fn deinit(self: *Path) void {
        self.lines.deinit(self.gpa);
    }

    pub fn reset(self: *Path) void {
        self.lines.clearRetainingCapacity();
    }

    fn toPixels(self: Path, x: f32, y: f32) Point {
        return .{ .x = x * self.scale, .y = -y * self.scale };
    }

    fn addLine(self: *Path, to: Point) !void {
        if (to.x != self.current.x or to.y != self.current.y) {
            try self.lines.append(self.gpa, .{ .p0 = self.current, .p1 = to });
        }
        self.current = to;
    }

    /// Fecha o contorno atual e comeca outro em (`x`, `y`).
    pub fn moveTo(self: *Path, x: f32, y: f32) !void {
        try self.close();
        self.start = self.toPixels(x, y);
        self.current = self.start;
    }

    pub fn lineTo(self: *Path, x: f32, y: f32) !void {
        try self.addLine(self.toPixels(x, y));
    }

    /// Curva quadratica (TrueType) com controle (`cx`, `cy`).
    pub fn quadTo(self: *Path, cx: f32, cy: f32, x: f32, y: f32) !void {
        const p0 = self.current;
        const p1 = self.toPixels(cx, cy);
        const p2 = self.toPixels(x, y);
        const dx = p0.x - 2 * p1.x + p2.x;
        const dy = p0.y - 2 * p1.y + p2.y;
        // Erro de ~0,1 pixel: o desvio maximo e |p0 - 2p1 + p2| / (4n^2).
        const n = segments(@sqrt(dx * dx + dy * dy) * 2.5);
        for (1..n) |i| {
            const t: f32 = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(n));
            const u = 1 - t;
            try self.addLine(.{
                .x = u * u * p0.x + 2 * u * t * p1.x + t * t * p2.x,
                .y = u * u * p0.y + 2 * u * t * p1.y + t * t * p2.y,
            });
        }
        try self.addLine(p2);
    }

    /// Curva cubica (CFF) com controles (`x1`, `y1`) e (`x2`, `y2`).
    pub fn cubicTo(self: *Path, x1: f32, y1: f32, x2: f32, y2: f32, x: f32, y: f32) !void {
        const p0 = self.current;
        const p1 = self.toPixels(x1, y1);
        const p2 = self.toPixels(x2, y2);
        const p3 = self.toPixels(x, y);
        const ax = p0.x - 2 * p1.x + p2.x;
        const ay = p0.y - 2 * p1.y + p2.y;
        const bx = p1.x - 2 * p2.x + p3.x;
        const by = p1.y - 2 * p2.y + p3.y;
        const dev = @sqrt(@max(ax * ax + ay * ay, bx * bx + by * by));
        const n = segments(dev * 7.5);
        for (1..n) |i| {
            const t: f32 = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(n));
            const u = 1 - t;
            try self.addLine(.{
                .x = u * u * u * p0.x + 3 * u * u * t * p1.x + 3 * u * t * t * p2.x + t * t * t * p3.x,
                .y = u * u * u * p0.y + 3 * u * u * t * p1.y + 3 * u * t * t * p2.y + t * t * t * p3.y,
            });
        }
        try self.addLine(p3);
    }

    pub fn close(self: *Path) !void {
        try self.addLine(self.start);
    }
};

/// Quantidade de segmentos para um erro proporcional a `k / n^2`.
fn segments(k: f32) usize {
    const n = @ceil(@sqrt(k));
    return if (n < 1) 1 else if (n > 64) 64 else @intFromFloat(n);
}

/// Retangulo de pixels de um glifo rasterizado, relativo a origem do glifo
/// (na linha de base). A cobertura fica em `pool[offset..][0 .. width * height]`.
pub const Box = struct {
    x0: i32 = 0,
    y0: i32 = 0,
    width: u32 = 0,
    height: u32 = 0,
    offset: usize = 0,
};

/// Rasteriza `path` (ja fechado) e acrescenta a cobertura em `pool`.
pub fn rasterize(gpa: std.mem.Allocator, path: *const Path, pool: *std.ArrayList(u8)) !Box {
    if (path.lines.items.len == 0) return .{ .offset = pool.items.len };

    var min: Point = path.lines.items[0].p0;
    var max: Point = min;
    for (path.lines.items) |line| {
        for ([_]Point{ line.p0, line.p1 }) |p| {
            min = .{ .x = @min(min.x, p.x), .y = @min(min.y, p.y) };
            max = .{ .x = @max(max.x, p.x), .y = @max(max.y, p.y) };
        }
    }
    const x0 = @floor(min.x);
    const y0 = @floor(min.y);
    const width: u32 = @intFromFloat(@ceil(max.x) - x0);
    const height: u32 = @intFromFloat(@ceil(max.y) - y0);
    var box: Box = .{
        .x0 = @intFromFloat(x0),
        .y0 = @intFromFloat(y0),
        .width = width,
        .height = height,
        .offset = pool.items.len,
    };
    if (width == 0 or height == 0) {
        box.width = 0;
        box.height = 0;
        return box;
    }

    // Duas colunas extras: os segmentos podem somar em x = width (e + 1).
    const stride = @as(usize, width) + 2;
    const acc = try gpa.alloc(f32, stride * height);
    defer gpa.free(acc);
    @memset(acc, 0);
    for (path.lines.items) |line| {
        accumulate(acc, stride, height, .{ .x = line.p0.x - x0, .y = line.p0.y - y0 }, .{ .x = line.p1.x - x0, .y = line.p1.y - y0 });
    }

    const out = try pool.addManyAsSlice(gpa, @as(usize, width) * height);
    for (0..height) |y| {
        var sum: f32 = 0;
        for (0..width) |x| {
            sum += acc[y * stride + x];
            const coverage = @min(@abs(sum), 1.0);
            out[y * width + x] = @intFromFloat(@round(coverage * 255));
        }
    }
    return box;
}

/// Soma a area com sinal do segmento p -> q nas celulas de `acc`.
fn accumulate(acc: []f32, stride: usize, height: u32, p: Point, q: Point) void {
    if (p.y == q.y) return;
    const dir: f32, const a: Point, const b: Point = if (p.y < q.y) .{ 1, p, q } else .{ -1, q, p };
    const dxdy = (b.x - a.x) / (b.y - a.y);
    const max_x: f32 = @floatFromInt(stride - 2);
    var x = a.x;
    const y_start: usize = @intFromFloat(@max(a.y, 0));
    const y_end: usize = @min(height, @as(usize, @intFromFloat(@ceil(b.y))));
    for (y_start..y_end) |y| {
        const row = acc[y * stride ..][0..stride];
        const top: f32 = @floatFromInt(y);
        const dy = @min(top + 1, b.y) - @max(top, a.y);
        const x_next = x + dxdy * dy;
        const d = dy * dir;
        // Limita a [0, largura]: erros de arredondamento nao saem da linha.
        const lo = @max(@min(x, x_next), 0);
        const hi = @min(@max(x, x_next), max_x);
        const lo_floor = @floor(lo);
        const lo_i: usize = @intFromFloat(lo_floor);
        const hi_ceil = @ceil(hi);
        const hi_i: usize = @intFromFloat(hi_ceil);
        if (hi_i <= lo_i + 1) {
            // O segmento fica numa unica coluna nesta linha.
            const xmf = 0.5 * (lo + hi) - lo_floor;
            row[lo_i] += d - d * xmf;
            row[lo_i + 1] += d * xmf;
        } else {
            const s = 1 / (hi - lo);
            const lo_frac = lo - lo_floor;
            const a0 = 0.5 * s * (1 - lo_frac) * (1 - lo_frac);
            const hi_frac = hi - hi_ceil + 1;
            const am = 0.5 * s * hi_frac * hi_frac;
            row[lo_i] += d * a0;
            if (hi_i == lo_i + 2) {
                row[lo_i + 1] += d * (1 - a0 - am);
            } else {
                const a1 = s * (1.5 - lo_frac);
                row[lo_i + 1] += d * (a1 - a0);
                for (lo_i + 2..hi_i - 1) |xi| row[xi] += d * s;
                const a2 = a1 + @as(f32, @floatFromInt(hi_i - lo_i - 3)) * s;
                row[hi_i - 1] += d * (1 - a2 - am);
            }
            row[hi_i] += d * am;
        }
        x = x_next;
    }
}

const testing = std.testing;

fn rect(path: *Path, x0: f32, y0: f32, x1: f32, y1: f32) !void {
    try path.moveTo(x0, y0);
    try path.lineTo(x1, y0);
    try path.lineTo(x1, y1);
    try path.lineTo(x0, y1);
    try path.close();
}

fn coverageSum(pool: []const u8) u32 {
    var sum: u32 = 0;
    for (pool) |c| sum += c;
    return sum;
}

test "quadrado alinhado aos pixels fica todo coberto" {
    var path: Path = .init(testing.allocator, 1);
    defer path.deinit();
    var pool: std.ArrayList(u8) = .empty;
    defer pool.deinit(testing.allocator);
    // y para cima em unidades da fonte: o quadrado fica acima da linha de base.
    try rect(&path, 1, 0, 4, 2);
    const box = try rasterize(testing.allocator, &path, &pool);
    try testing.expectEqual(Box{ .x0 = 1, .y0 = -2, .width = 3, .height = 2, .offset = 0 }, box);
    for (pool.items) |c| try testing.expectEqual(@as(u8, 255), c);
}

test "meio pixel de cobertura nas bordas" {
    var path: Path = .init(testing.allocator, 1);
    defer path.deinit();
    var pool: std.ArrayList(u8) = .empty;
    defer pool.deinit(testing.allocator);
    // Sentido contrario (horario): a cobertura e a mesma.
    try path.moveTo(0.5, 0);
    try path.lineTo(0.5, 1);
    try path.lineTo(2.5, 1);
    try path.lineTo(2.5, 0);
    try path.close();
    const box = try rasterize(testing.allocator, &path, &pool);
    try testing.expectEqual(@as(u32, 3), box.width);
    try testing.expectEqualSlices(u8, &.{ 128, 255, 128 }, pool.items);
}

test "contorno inverso abre um buraco" {
    var path: Path = .init(testing.allocator, 1);
    defer path.deinit();
    var pool: std.ArrayList(u8) = .empty;
    defer pool.deinit(testing.allocator);
    try rect(&path, 0, 0, 3, 3);
    try path.moveTo(1, 1);
    try path.lineTo(1, 2);
    try path.lineTo(2, 2);
    try path.lineTo(2, 1);
    try path.close();
    _ = try rasterize(testing.allocator, &path, &pool);
    try testing.expectEqualSlices(u8, &.{ 255, 255, 255, 255, 0, 255, 255, 255, 255 }, pool.items);
}

test "area coberta de um circulo e de um triangulo" {
    var path: Path = .init(testing.allocator, 10);
    defer path.deinit();
    var pool: std.ArrayList(u8) = .empty;
    defer pool.deinit(testing.allocator);
    // Circulo de raio 2 (20 px) com quatro cubicas.
    const k = 0.5523 * 2.0;
    try path.moveTo(2, 0);
    try path.cubicTo(2, k, k, 2, 0, 2);
    try path.cubicTo(-k, 2, -2, k, -2, 0);
    try path.cubicTo(-2, -k, -k, -2, 0, -2);
    try path.cubicTo(k, -2, 2, -k, 2, 0);
    try path.close();
    _ = try rasterize(testing.allocator, &path, &pool);
    const area = @as(f32, @floatFromInt(coverageSum(pool.items))) / 255;
    try testing.expectApproxEqRel(std.math.pi * 400.0, area, 0.01);

    path.reset();
    pool.clearRetainingCapacity();
    try path.moveTo(0, 0);
    try path.quadTo(1, 1, 3, 0);
    try path.close();
    _ = try rasterize(testing.allocator, &path, &pool);
    // Area sob a parabola: 2/3 * base * altura do controle / 2 = 30 * 5 * 2 / 3.
    const quad_area = @as(f32, @floatFromInt(coverageSum(pool.items))) / 255;
    try testing.expectApproxEqRel(@as(f32, 100), quad_area, 0.02);
}

test "contorno vazio nao gera pixels" {
    var path: Path = .init(testing.allocator, 1);
    defer path.deinit();
    var pool: std.ArrayList(u8) = .empty;
    defer pool.deinit(testing.allocator);
    const box = try rasterize(testing.allocator, &path, &pool);
    try testing.expectEqual(@as(u32, 0), box.width);
    try testing.expectEqual(@as(usize, 0), pool.items.len);
}
