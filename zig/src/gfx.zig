//! Utilitarios de desenho comuns (cores do `java.awt.Color` e carga de PNG).

const rl = @import("raylib");

// As macros de cor do raylib (WHITE, BLACK...) nao sao traduzidas para Zig.
pub const white: rl.Color = .{ .r = 255, .g = 255, .b = 255, .a = 255 };
pub const black: rl.Color = .{ .r = 0, .g = 0, .b = 0, .a = 255 };
/// `Game.BLUE`.
pub const blue: rl.Color = .{ .r = 9, .g = 156, .b = 147, .a = 255 };

/// Carrega um PNG embutido como textura.
pub fn loadTexture(png: []const u8) rl.Texture2D {
    const image = rl.LoadImageFromMemory(".png", png.ptr, @intCast(png.len));
    defer rl.UnloadImage(image);
    return rl.LoadTextureFromImage(image);
}

/// Imagem de tela inteira (960x640) desenhada na origem, como
/// `g.drawImage(img, 0, 0, Game.widthfm, Game.heightfm, null)`.
pub fn drawScreen(texture: rl.Texture2D) void {
    rl.DrawTexture(texture, 0, 0, white);
}

/// `g.setColor(c); g.fillRect(0, 0, Game.widthfm, Game.heightfm)`.
pub fn fillScreen(color: rl.Color) void {
    rl.DrawRectangle(0, 0, rl.GetScreenWidth(), rl.GetScreenHeight(), color);
}
