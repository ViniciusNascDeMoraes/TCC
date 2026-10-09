//! `Graphics.Spritesheet`: a textura com todos os sprites 16x16.

const rl = @import("raylib");
const assets = @import("assets");
const rules = @import("rules.zig");
const gfx = @import("gfx.zig");

pub const Spritesheet = struct {
    texture: rl.Texture2D,

    pub fn load() Spritesheet {
        return .{ .texture = gfx.loadTexture(assets.spritesheet) };
    }

    pub fn unload(self: Spritesheet) void {
        rl.UnloadTexture(self.texture);
    }

    /// Equivale a `g.drawImage(spritesheet.getSprite(sx, sy, 16, 16), x, y, null)`.
    pub fn draw(self: Spritesheet, sprite: rules.SpritePos, x: i32, y: i32) void {
        const source: rl.Rectangle = .{
            .x = @floatFromInt(sprite.x),
            .y = @floatFromInt(sprite.y),
            .width = rules.tile_size,
            .height = rules.tile_size,
        };
        rl.DrawTextureRec(self.texture, source, .{ .x = @floatFromInt(x), .y = @floatFromInt(y) }, gfx.white);
    }
};
