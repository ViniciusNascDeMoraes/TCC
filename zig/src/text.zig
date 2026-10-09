//! Texto no estilo do `g.setFont(new Font("Bookman Old Style", Font.BOLD, n))`
//! + `g.drawString` do Java.
//!
//! A Bookman Old Style nao pode ser distribuida junto com o jogo, entao ela e
//! lida da pasta de fontes do sistema. Sem ela, tenta o clone livre URW
//! Bookman (Linux), depois as fontes que o Java usaria no lugar (fonte logica
//! "Dialog": Arial/DejaVu Sans) e, por ultimo, a fonte padrao do raylib.

const rl = @import("raylib");
const ttf = @import("ttf.zig");

/// Tamanhos de fonte usados pelo jogo Java.
pub const Size = enum {
    s20,
    s23,
    s30,
    s40,
    s50,

    fn points(size: Size) i32 {
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

const candidates = [_][:0]const u8{
    // Bookman Old Style Bold (Windows / Office).
    "C:/Windows/Fonts/BOOKOSB.TTF",
    // Clone livre da Bookman (pacote fonts-urw-base35 no Linux).
    "/usr/share/fonts/opentype/urw-base35/URWBookman-Demi.otf",
    // "Dialog" negrito, a fonte que o Java usa quando a Bookman nao existe.
    "C:/Windows/Fonts/arialbd.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
};

pub const Text = struct {
    fonts: [size_count]rl.Font,
    /// Distancia, em pixels, do topo do texto ate a linha de base.
    baselines: [size_count]i32,
    /// Tamanho passado ao `DrawTextEx`.
    draw_sizes: [size_count]f32,
    spacings: [size_count]f32,
    owns_fonts: bool,

    pub fn load() Text {
        if (loadSystemFont()) |text| return text;

        // Fonte padrao do raylib (bitmap de 10 px) ampliada.
        const font = rl.GetFontDefault();
        var text: Text = .{
            .fonts = @splat(font),
            .baselines = undefined,
            .draw_sizes = undefined,
            .spacings = undefined,
            .owns_fonts = false,
        };
        for (0..size_count) |i| {
            const points = Size.points(@enumFromInt(i));
            text.baselines[i] = @divTrunc(points * 8, 10);
            text.draw_sizes[i] = @floatFromInt(points);
            text.spacings[i] = @floatFromInt(@divTrunc(points, 10));
        }
        return text;
    }

    fn loadSystemFont() ?Text {
        // ASCII e Latin-1 imprimiveis, para os acentos do portugues.
        var codepoints: [95 + 96]c_int = undefined;
        for (codepoints[0..95], 32..) |*codepoint, c| codepoint.* = @intCast(c);
        for (codepoints[95..], 160..) |*codepoint, c| codepoint.* = @intCast(c);

        for (candidates) |path| {
            if (!rl.FileExists(path)) continue;
            var len: c_int = 0;
            const data = rl.LoadFileData(path, &len);
            if (data == null) continue;
            defer rl.UnloadFileData(data);

            const metrics = ttf.parse(data[0..@intCast(len)]) orelse continue;
            var text: Text = .{
                .fonts = undefined,
                .baselines = undefined,
                .draw_sizes = undefined,
                .spacings = @splat(0),
                .owns_fonts = true,
            };
            var loaded: usize = 0;
            while (loaded < size_count) : (loaded += 1) {
                const points = Size.points(@enumFromInt(loaded));
                const font = rl.LoadFontFromMemory(rl.GetFileExtension(path), data, len, metrics.raylibSize(points), &codepoints, codepoints.len);
                if (!rl.IsFontValid(font)) break;
                text.fonts[loaded] = font;
                text.baselines[loaded] = metrics.baselineOffset(points);
                text.draw_sizes[loaded] = @floatFromInt(font.baseSize);
            }
            if (loaded == size_count) return text;
            for (text.fonts[0..loaded]) |font| rl.UnloadFont(font);
        }
        return null;
    }

    pub fn unload(self: Text) void {
        if (!self.owns_fonts) return;
        for (self.fonts) |font| rl.UnloadFont(font);
    }

    /// `g.getFontMetrics().stringWidth(text)`.
    pub fn width(self: Text, text: [:0]const u8, size: Size) i32 {
        const i = @intFromEnum(size);
        return @intFromFloat(rl.MeasureTextEx(self.fonts[i], text, self.draw_sizes[i], self.spacings[i]).x);
    }

    /// `g.drawString(text, x, y)`: `y` e a linha de base, como no Java.
    pub fn draw(self: Text, text: [:0]const u8, size: Size, x: i32, y: i32, color: rl.Color) void {
        const i = @intFromEnum(size);
        const position: rl.Vector2 = .{
            .x = @floatFromInt(x),
            .y = @floatFromInt(y - self.baselines[i]),
        };
        rl.DrawTextEx(self.fonts[i], text, position, self.draw_sizes[i], self.spacings[i], color);
    }
};
