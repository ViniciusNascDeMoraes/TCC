//! `Graphics.Spritesheet`: a imagem com todos os sprites 16x16.

const std = @import("std");
const assets = @import("assets");
const rules = @import("rules.zig");
const gfx = @import("gfx.zig");

pub const Spritesheet = struct {
    image: gfx.Image,

    pub fn load(gpa: std.mem.Allocator) !Spritesheet {
        return .{ .image = try gfx.loadImage(gpa, assets.spritesheet) };
    }

    pub fn unload(self: Spritesheet, gpa: std.mem.Allocator) void {
        self.image.deinit(gpa);
    }

    /// Equivale a `g.drawImage(spritesheet.getSprite(sx, sy, 16, 16), x, y, null)`.
    pub fn draw(self: Spritesheet, target: gfx.Canvas, sprite: rules.SpritePos, x: i32, y: i32) void {
        target.drawImage(self.image, @intCast(sprite.x), @intCast(sprite.y), rules.tile_size, rules.tile_size, x, y);
    }
};
