//! Utilitarios de desenho comuns (cores do `java.awt.Color` e carga de PNG).

const std = @import("std");
const canvas = @import("canvas.zig");
const png = @import("png.zig");

pub const Color = canvas.Color;
pub const Canvas = canvas.Canvas;
/// Imagem carregada de um PNG (o `BufferedImage` do Java).
pub const Image = canvas.Canvas;

pub const white: Color = .rgb(255, 255, 255);
pub const black: Color = .rgb(0, 0, 0);
/// `Game.BLUE`.
pub const blue: Color = .rgb(9, 156, 147);

/// Decodifica um PNG embutido.
pub fn loadImage(gpa: std.mem.Allocator, data: []const u8) !Image {
    return png.decode(gpa, data);
}

/// Imagem de tela inteira (960x640) desenhada na origem, como
/// `g.drawImage(img, 0, 0, Game.widthfm, Game.heightfm, null)`.
pub fn drawScreen(target: Canvas, image: Image) void {
    target.drawImage(image, 0, 0, image.width, image.height, 0, 0);
}

/// `g.setColor(c); g.fillRect(0, 0, Game.widthfm, Game.heightfm)`.
pub fn fillScreen(target: Canvas, color: Color) void {
    target.fillRect(0, 0, target.width, target.height, color);
}
