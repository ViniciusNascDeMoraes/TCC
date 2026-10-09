//! Texto no estilo do `g.setFont(new Font("Bookman Old Style", Font.BOLD, n))`
//! + `g.drawString` do Java.
//!
//! A Bookman Old Style nao pode ser distribuida junto com o jogo, entao ela e
//! lida da pasta de fontes do sistema ou do usuario. Sem ela, tenta o clone
//! livre URW Bookman (Linux), depois as fontes que o Java usaria no lugar
//! (fonte logica "Dialog": Arial/DejaVu Sans) e, por ultimo, a fonte bitmap
//! embutida.

const std = @import("std");
const builtin = @import("builtin");
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

/// Uma fonte procurada pelos nomes de arquivo nas pastas de fontes do
/// Windows e do usuario (vindas do ambiente) e em pastas fixas do sistema.
const Candidate = struct {
    files: []const []const u8,
    system_dirs: []const []const u8 = &.{},
};

const candidates = [_]Candidate{
    // Bookman Old Style Bold (Windows / Office, ou copiada para as fontes do usuario).
    .{ .files = &.{ "BOOKOSB.TTF", "bookosb.ttf" } },
    // Clone livre da Bookman (pacotes fonts-urw-base35 / urw-base35-fonts / gsfonts).
    .{ .files = &.{"URWBookman-Demi.otf"}, .system_dirs = &.{
        "/usr/share/fonts/opentype/urw-base35",
        "/usr/share/fonts/urw-base35",
        "/usr/share/fonts/gsfonts",
    } },
    // "Dialog" negrito, a fonte que o Java usa quando a Bookman nao existe.
    .{ .files = &.{"arialbd.ttf"} },
    .{ .files = &.{"DejaVuSans-Bold.ttf"}, .system_dirs = &.{
        "/usr/share/fonts/truetype/dejavu",
        "/usr/share/fonts/TTF",
        "/usr/share/fonts/dejavu-sans-fonts",
    } },
    .{ .files = &.{"LiberationSans-Bold.ttf"}, .system_dirs = &.{
        "/usr/share/fonts/truetype/liberation",
        "/usr/share/fonts/liberation-sans",
    } },
};

/// Pastas de fontes do Windows (do sistema e do usuario) e do usuario no
/// Linux, conforme as variaveis de ambiente que existirem.
fn userDirs(gpa: std.mem.Allocator, env: *const std.process.Environ.Map) !std.ArrayList([]u8) {
    var dirs: std.ArrayList([]u8) = .empty;
    errdefer {
        for (dirs.items) |d| gpa.free(d);
        dirs.deinit(gpa);
    }
    if (builtin.os.tag == .windows) {
        try dirs.append(gpa, try std.fmt.allocPrint(gpa, "{s}/Fonts", .{env.get("WINDIR") orelse "C:/Windows"}));
        if (env.get("LOCALAPPDATA")) |dir| try dirs.append(gpa, try std.fmt.allocPrint(gpa, "{s}/Microsoft/Windows/Fonts", .{dir}));
    } else {
        if (env.get("XDG_DATA_HOME")) |dir| {
            try dirs.append(gpa, try std.fmt.allocPrint(gpa, "{s}/fonts", .{dir}));
        } else if (env.get("HOME")) |home| {
            try dirs.append(gpa, try std.fmt.allocPrint(gpa, "{s}/.local/share/fonts", .{home}));
        }
        if (env.get("HOME")) |home| try dirs.append(gpa, try std.fmt.allocPrint(gpa, "{s}/.fonts", .{home}));
    }
    return dirs;
}

pub const Text = struct {
    sets: [size_count]GlyphSet,

    pub fn load(gpa: std.mem.Allocator, io: std.Io, env: *const std.process.Environ.Map) !Text {
        var dirs = try userDirs(gpa, env);
        defer {
            for (dirs.items) |d| gpa.free(d);
            dirs.deinit(gpa);
        }
        for (candidates) |candidate| {
            for (candidate.files) |file| {
                for (dirs.items) |dir| {
                    if (try tryFont(gpa, io, dir, file)) |text| return text;
                }
                for (candidate.system_dirs) |dir| {
                    if (try tryFont(gpa, io, dir, file)) |text| return text;
                }
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

    /// A fonte `dir/file`, ou `null` se ela nao existe ou nao serve.
    fn tryFont(gpa: std.mem.Allocator, io: std.Io, dir: []const u8, file: []const u8) !?Text {
        var buf: [std.fs.max_path_bytes]u8 = undefined;
        const path = std.fmt.bufPrint(&buf, "{s}/{s}", .{ dir, file }) catch return null;
        return loadFont(gpa, io, path) catch |err| switch (err) {
            error.OutOfMemory => err,
            error.FileNotFound => null,
            else => {
                log.info("fonte {s} ignorada: {s}", .{ path, @errorName(err) });
                return null;
            },
        };
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
