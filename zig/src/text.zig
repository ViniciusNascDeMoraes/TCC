//! Texto no estilo do `g.setFont(new Font("Bookman Old Style", Font.BOLD, n))`
//! + `g.drawString` do Java.
//!
//! A Bookman Old Style nao pode ser distribuida junto com o jogo, entao ela e
//! lida da pasta de fontes do sistema. Sem ela, tenta o clone livre URW
//! Bookman (Linux), depois as fontes que o Java usaria no lugar (fonte logica
//! "Dialog": Arial/DejaVu Sans) e, por ultimo, a fonte bitmap embutida.

const std = @import("std");
const ttf = @import("ttf.zig");
const gfx = @import("gfx.zig");
const GlyphSet = @import("glyphs.zig").GlyphSet;

const log = std.log.scoped(.text);

/// Tamanhos de fonte usados pelo jogo Java.
pub const Size = enum {
    s20,
    s23,
    s30,
    s40,
    s50,

    fn points(size: Size) u32 {
        return switch (size) {
            .s20 => 20,
            .s23 => 23,
            .s30 => 30,
            .s40 => 40,
            .s50 => 50,
        };
    }
};

const size_count = @typeInfo(Size).@"enum".fields.len;

const candidates = [_][]const u8{
    // Bookman Old Style Bold (Windows / Office).
    "C:/Windows/Fonts/BOOKOSB.TTF",
    // Clone livre da Bookman (pacote fonts-urw-base35 no Linux).
    "/usr/share/fonts/opentype/urw-base35/URWBookman-Demi.otf",
    "/usr/share/fonts/urw-base35/URWBookman-Demi.otf",
    // "Dialog" negrito, a fonte que o Java usa quando a Bookman nao existe.
    "C:/Windows/Fonts/arialbd.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/dejavu-sans-fonts/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    "/usr/share/fonts/liberation-sans/LiberationSans-Bold.ttf",
};

pub const Text = struct {
    sets: [size_count]GlyphSet,

    pub fn load(gpa: std.mem.Allocator, io: std.Io) !Text {
        for (candidates) |path| {
            if (loadFont(gpa, io, path)) |text| return text else |err| switch (err) {
                error.OutOfMemory => return err,
                error.FileNotFound => {},
                else => log.info("fonte {s} ignorada: {s}", .{ path, @errorName(err) }),
            }
        }

        // Fonte bitmap 8x8 embutida, ampliada.
        var text: Text = .{ .sets = undefined };
        for (&text.sets, 0..) |*set, i| {
            errdefer for (text.sets[0..i]) |s| s.deinit(gpa);
            set.* = try GlyphSet.fromBitmap(gpa, Size.points(@enumFromInt(i)));
        }
        return text;
    }

    fn loadFont(gpa: std.mem.Allocator, io: std.Io, path: []const u8) !Text {
        const data = try std.Io.Dir.cwd().readFileAlloc(io, path, gpa, .limited(32 << 20));
        defer gpa.free(data);
        const font = try ttf.Font.parse(data);

        // Todos os glifos sao rasterizados aqui; depois o arquivo nao e mais usado.
        var text: Text = .{ .sets = undefined };
        for (&text.sets, 0..) |*set, i| {
            errdefer for (text.sets[0..i]) |s| s.deinit(gpa);
            set.* = try GlyphSet.fromFont(gpa, font, Size.points(@enumFromInt(i)));
        }
        return text;
    }

    pub fn unload(self: *const Text, gpa: std.mem.Allocator) void {
        for (self.sets) |set| set.deinit(gpa);
    }

    /// `g.getFontMetrics().stringWidth(text)`.
    pub fn width(self: *const Text, text: []const u8, size: Size) i32 {
        return self.sets[@intFromEnum(size)].width(text);
    }

    /// `g.drawString(text, x, y)`: `y` e a linha de base, como no Java.
    pub fn draw(self: *const Text, target: gfx.Canvas, text: []const u8, size: Size, x: i32, y: i32, color: gfx.Color) void {
        self.sets[@intFromEnum(size)].draw(target, text, x, y, color);
    }
};
