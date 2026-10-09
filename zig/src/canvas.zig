//! Framebuffer em software: o `BufferedImage` + `Graphics` do Java.
//!
//! Cada pixel e um `Color` de 32 bits no formato 0xAARRGGBB (o `getRGB` do
//! Java). Em memoria (little-endian) os bytes ficam B, G, R, A, que e o
//! formato que o X11 (ZPixmap de 32 bits) e o Win32 (DIB de 32 bits) esperam,
//! entao a imagem final vai para a janela sem conversao.

const std = @import("std");
const builtin = @import("builtin");

comptime {
    if (builtin.cpu.arch.endian() != .little) @compileError("o canvas assume uma CPU little-endian");
}

pub const Color = packed struct(u32) {
    b: u8,
    g: u8,
    r: u8,
    a: u8 = 255,

    pub fn rgb(r: u8, g: u8, b: u8) Color {
        return .{ .r = r, .g = g, .b = b };
    }

    /// Valor 0xAARRGGBB, como o `Color.getRGB()` do Java.
    pub fn argb(c: Color) u32 {
        return @bitCast(c);
    }
};

/// `dst` coberto por `src` com opacidade `alpha` (0 a 255), com arredondamento.
fn mix(dst: u8, src: u8, alpha: u32) u8 {
    const value = @as(u32, src) * alpha + @as(u32, dst) * (255 - alpha);
    return @intCast((value + 127) / 255);
}

fn blend(dst: Color, src: Color, alpha: u32) Color {
    return .{
        .r = mix(dst.r, src.r, alpha),
        .g = mix(dst.g, src.g, alpha),
        .b = mix(dst.b, src.b, alpha),
        .a = 255,
    };
}

/// Parte visivel de um retangulo de `w` x `h` em (`x`, `y`) dentro de
/// `0..limit_w` x `0..limit_h`; `skip_x`/`skip_y` e quanto foi cortado do
/// comeco do retangulo.
const Clip = struct {
    x: u32,
    y: u32,
    w: u32,
    h: u32,
    skip_x: u32,
    skip_y: u32,

    fn init(x: i32, y: i32, w: u32, h: u32, limit_w: u32, limit_h: u32) ?Clip {
        const x0: i64 = @max(x, 0);
        const y0: i64 = @max(y, 0);
        const x1: i64 = @min(@as(i64, x) + w, limit_w);
        const y1: i64 = @min(@as(i64, y) + h, limit_h);
        if (x1 <= x0 or y1 <= y0) return null;
        return .{
            .x = @intCast(x0),
            .y = @intCast(y0),
            .w = @intCast(x1 - x0),
            .h = @intCast(y1 - y0),
            .skip_x = @intCast(x0 - x),
            .skip_y = @intCast(y0 - y),
        };
    }
};

pub const Canvas = struct {
    width: u32,
    height: u32,
    pixels: []Color,
    /// Nenhum pixel com alfa menor que 255: o desenho pode copiar linhas.
    solid: bool = true,

    pub fn init(gpa: std.mem.Allocator, width: u32, height: u32) !Canvas {
        const pixels = try gpa.alloc(Color, @as(usize, width) * height);
        @memset(pixels, .{ .r = 0, .g = 0, .b = 0 });
        return .{ .width = width, .height = height, .pixels = pixels };
    }

    pub fn deinit(self: Canvas, gpa: std.mem.Allocator) void {
        gpa.free(self.pixels);
    }

    pub fn pixel(self: Canvas, x: u32, y: u32) Color {
        return self.pixels[@as(usize, y) * self.width + x];
    }

    fn row(self: Canvas, y: u32) []Color {
        const start = @as(usize, y) * self.width;
        return self.pixels[start..][0..self.width];
    }

    pub fn clear(self: Canvas, color: Color) void {
        @memset(self.pixels, color);
    }

    /// `g.setColor(color); g.fillRect(x, y, w, h)`.
    pub fn fillRect(self: Canvas, x: i32, y: i32, w: u32, h: u32, color: Color) void {
        const clip = Clip.init(x, y, w, h, self.width, self.height) orelse return;
        for (0..clip.h) |dy| {
            const dst = self.row(clip.y + @as(u32, @intCast(dy)))[clip.x..][0..clip.w];
            if (color.a == 255) {
                @memset(dst, color);
            } else {
                for (dst) |*p| p.* = blend(p.*, color, color.a);
            }
        }
    }

    /// Copia o retangulo `w` x `h` de `src` em (`sx`, `sy`) para (`dx`, `dy`),
    /// misturando pela transparencia de cada pixel (o `drawImage` do Java).
    pub fn drawImage(self: Canvas, src: Canvas, sx: u32, sy: u32, w: u32, h: u32, dx: i32, dy: i32) void {
        std.debug.assert(sx + w <= src.width and sy + h <= src.height);
        const clip = Clip.init(dx, dy, w, h, self.width, self.height) orelse return;
        for (0..clip.h) |i| {
            const y: u32 = @intCast(i);
            const from = src.row(sy + clip.skip_y + y)[sx + clip.skip_x ..][0..clip.w];
            const to = self.row(clip.y + y)[clip.x..][0..clip.w];
            if (src.solid) {
                @memcpy(to, from);
                continue;
            }
            for (to, from) |*d, s| {
                switch (s.a) {
                    0 => {},
                    255 => d.* = s,
                    else => d.* = blend(d.*, s, s.a),
                }
            }
        }
    }

    /// `src` inteira ampliada `scale` vezes (vizinho mais proximo) em (0, 0).
    pub fn drawScaled(self: Canvas, src: Canvas, scale: u32) void {
        const w = @min(src.width * scale, self.width);
        const h = @min(src.height * scale, self.height);
        var y: u32 = 0;
        while (y < h) : (y += scale) {
            const from = src.row(y / scale);
            const first = self.row(y)[0..w];
            for (first, 0..) |*d, x| d.* = from[x / scale];
            var copy: u32 = 1;
            while (copy < scale and y + copy < h) : (copy += 1) {
                @memcpy(self.row(y + copy)[0..w], first);
            }
        }
    }

    /// Pinta `color` com a cobertura de `mask` (`w` x `h`, 0 a 255 por pixel)
    /// em (`dx`, `dy`): usado para os glifos do texto.
    pub fn drawMask(self: Canvas, mask: []const u8, w: u32, h: u32, dx: i32, dy: i32, color: Color) void {
        const clip = Clip.init(dx, dy, w, h, self.width, self.height) orelse return;
        for (0..clip.h) |i| {
            const y: u32 = @intCast(i);
            const from = mask[@as(usize, clip.skip_y + y) * w + clip.skip_x ..][0..clip.w];
            const to = self.row(clip.y + y)[clip.x..][0..clip.w];
            for (to, from) |*d, coverage| {
                switch (coverage) {
                    0 => {},
                    255 => d.* = color,
                    else => d.* = blend(d.*, color, coverage),
                }
            }
        }
    }
};

const testing = std.testing;

const white: Color = .rgb(255, 255, 255);
const black: Color = .rgb(0, 0, 0);
const red: Color = .rgb(255, 0, 0);

test "Color e 0xAARRGGBB e BGRA na memoria" {
    const c: Color = .rgb(0x09, 0x9C, 0x93);
    try testing.expectEqual(@as(u32, 0xFF099C93), c.argb());
    try testing.expectEqualSlices(u8, &.{ 0x93, 0x9C, 0x09, 0xFF }, std.mem.asBytes(&c));
}

test "fillRect recorta nas bordas" {
    const c = try Canvas.init(testing.allocator, 4, 3);
    defer c.deinit(testing.allocator);
    c.fillRect(-2, 1, 4, 10, red);
    try testing.expectEqual(black, c.pixel(0, 0));
    try testing.expectEqual(red, c.pixel(0, 1));
    try testing.expectEqual(red, c.pixel(1, 2));
    try testing.expectEqual(black, c.pixel(2, 1));
    c.fillRect(10, 0, 2, 2, red);
    c.fillRect(0, 0, 0, 2, red);
}

test "drawImage respeita alfa e deslocamento negativo" {
    var src = try Canvas.init(testing.allocator, 3, 1);
    defer src.deinit(testing.allocator);
    src.solid = false;
    src.pixels[0] = .{ .r = 255, .g = 0, .b = 0, .a = 0 };
    src.pixels[1] = .{ .r = 255, .g = 255, .b = 255, .a = 255 };
    src.pixels[2] = .{ .r = 255, .g = 255, .b = 255, .a = 128 };

    const dst = try Canvas.init(testing.allocator, 3, 1);
    defer dst.deinit(testing.allocator);
    dst.drawImage(src, 0, 0, 3, 1, 0, 0);
    try testing.expectEqual(black, dst.pixel(0, 0));
    try testing.expectEqual(white, dst.pixel(1, 0));
    try testing.expectEqual(Color.rgb(128, 128, 128), dst.pixel(2, 0));

    dst.clear(black);
    dst.drawImage(src, 0, 0, 3, 1, -1, 0);
    try testing.expectEqual(white, dst.pixel(0, 0));
    try testing.expectEqual(black, dst.pixel(2, 0));
}

test "drawImage de imagem opaca copia o recorte" {
    const src = try Canvas.init(testing.allocator, 4, 4);
    defer src.deinit(testing.allocator);
    src.pixels[1 * 4 + 2] = red;
    const dst = try Canvas.init(testing.allocator, 2, 2);
    defer dst.deinit(testing.allocator);
    dst.drawImage(src, 2, 1, 2, 2, 0, 0);
    try testing.expectEqual(red, dst.pixel(0, 0));
    try testing.expectEqual(black, dst.pixel(1, 1));
}

test "drawScaled amplia por vizinho mais proximo" {
    const src = try Canvas.init(testing.allocator, 2, 2);
    defer src.deinit(testing.allocator);
    src.pixels[1] = red;
    const dst = try Canvas.init(testing.allocator, 8, 8);
    defer dst.deinit(testing.allocator);
    dst.drawScaled(src, 4);
    for (0..8) |y| {
        for (0..8) |x| {
            const expected = if (x >= 4 and y < 4) red else black;
            try testing.expectEqual(expected, dst.pixel(@intCast(x), @intCast(y)));
        }
    }
}

test "drawMask mistura pela cobertura" {
    const dst = try Canvas.init(testing.allocator, 3, 1);
    defer dst.deinit(testing.allocator);
    dst.drawMask(&.{ 0, 128, 255 }, 3, 1, 0, 0, white);
    try testing.expectEqual(black, dst.pixel(0, 0));
    try testing.expectEqual(Color.rgb(128, 128, 128), dst.pixel(1, 0));
    try testing.expectEqual(white, dst.pixel(2, 0));
    dst.drawMask(&.{ 255, 255 }, 1, 2, 2, -1, red);
    try testing.expectEqual(red, dst.pixel(2, 0));
}
