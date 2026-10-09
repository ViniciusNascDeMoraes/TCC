//! `World.World`: o mapa do nivel atual, montado a partir do PNG do nivel.

const rl = @import("raylib");
const assets = @import("assets");
const rules = @import("rules.zig");
const Game = @import("game.zig").Game;
const Enemy = @import("entities.zig").Enemy;

pub const World = struct {
    width: i32,
    height: i32,
    tiles: []rules.Tile,

    /// `new World("/levelN.png")`: cada pixel vira um tile, a posicao inicial
    /// do jogador ou um inimigo, conforme `rules.classifyPixel`.
    pub fn load(g: *Game, png: []const u8) !World {
        const image = rl.LoadImageFromMemory(".png", png.ptr, @intCast(png.len));
        defer rl.UnloadImage(image);
        const colors = rl.LoadImageColors(image);
        defer rl.UnloadImageColors(colors);

        const width: usize = @intCast(image.width);
        const height: usize = @intCast(image.height);
        const tiles = try g.gpa.alloc(rules.Tile, width * height);
        errdefer g.gpa.free(tiles);

        // Mesma ordem do Java (x por fora, y por dentro): define a ordem dos inimigos.
        for (0..width) |xx| {
            for (0..height) |yy| {
                const index = xx + yy * width;
                const color = colors[index];
                const x: i32 = @intCast(xx * rules.tile_size);
                const y: i32 = @intCast(yy * rules.tile_size);

                tiles[index] = rules.defaultTile(g.level);
                switch (rules.classifyPixel(g.level, rules.argb(color.r, color.g, color.b, color.a))) {
                    .tile => |tile| tiles[index] = tile,
                    .player => {
                        g.player.setX(x);
                        g.player.setY(y);
                    },
                    .enemy => |kind| try g.enemies.append(g.gpa, .init(kind, x, y)),
                    .none => {},
                }
            }
        }

        return .{ .width = @intCast(width), .height = @intCast(height), .tiles = tiles };
    }

    pub fn deinit(self: World, g: *Game) void {
        g.gpa.free(self.tiles);
    }

    /// `World.place_free`.
    pub fn placeFree(self: World, xnext: i32, ynext: i32) bool {
        return rules.placeFree(self.tiles, self.width, xnext, ynext);
    }

    /// Desenha so os tiles visiveis pela camera.
    pub fn render(self: World, g: *const Game) void {
        const xstart = @divTrunc(g.camera.x, rules.tile_size);
        const ystart = @divTrunc(g.camera.y, rules.tile_size);

        const xfinal = xstart + @divTrunc(Game.width, rules.tile_size);
        const yfinal = ystart + @divTrunc(Game.height, rules.tile_size);

        var xx = xstart;
        while (xx <= xfinal) : (xx += 1) {
            var yy = ystart;
            while (yy <= yfinal) : (yy += 1) {
                if (xx < 0 or yy < 0 or xx >= self.width or yy >= self.height) continue;
                const tile = self.tiles[@intCast(xx + yy * self.width)];
                g.spritesheet.draw(tile.sprite, xx * rules.tile_size - g.camera.x, yy * rules.tile_size - g.camera.y);
            }
        }
    }
};

fn levelPng(level: i32) []const u8 {
    return switch (level) {
        1 => assets.level1,
        2 => assets.level2,
        3 => assets.level3,
        else => unreachable,
    };
}

/// `World.restartGame`: recria o jogador e os inimigos e recarrega o mapa do
/// nivel atual. Como no Java, nao mexe na camera, no contador nem nos escudos.
pub fn restartGame(g: *Game) !void {
    g.enemies.clearRetainingCapacity();
    g.player = .init(g.level);
    const world = try World.load(g, levelPng(g.level));
    g.world.deinit(g);
    g.world = world;
}
