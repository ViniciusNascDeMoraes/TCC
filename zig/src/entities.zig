//! `Entities.Player`, `Entities.Enemy`, `Entities.Enemy02` e `Entities.Enemy03`.

const std = @import("std");
const rules = @import("rules.zig");
const Camera = @import("camera.zig").Camera;
const Game = @import("game.zig").Game;
const SoundId = @import("sound.zig").SoundId;

pub const Dir = enum { right, left };

pub const Player = struct {
    x: f64 = 0,
    y: f64 = 0,
    right: bool = false,
    left: bool = false,
    up: bool = false,
    down: bool = false,
    speed: f64 = 1,
    dir: Dir = .right,
    life: i32 = 1,
    /// `Player.escudo`: quadros desde que o escudo apareceu.
    escudo: i32 = 0,
    frames: i32 = 0,
    index: i32 = 0,
    moved: bool = false,
    /// Coluna do primeiro quadro de `rightPlayer`/`leftPlayer` no Spritesheet.
    sprite_x: i32,

    const max_frames = 5;
    const max_index = 3;

    /// O visual depende do nivel em que o jogador e criado.
    pub fn init(level: i32) Player {
        return .{ .sprite_x = if (level == 3) 160 else 32 };
    }

    pub fn getX(self: Player) i32 {
        return rules.toInt(self.x);
    }

    pub fn getY(self: Player) i32 {
        return rules.toInt(self.y);
    }

    pub fn setX(self: *Player, x: i32) void {
        self.x = @floatFromInt(x);
    }

    pub fn setY(self: *Player, y: i32) void {
        self.y = @floatFromInt(y);
    }

    pub fn tick(self: *Player, g: *Game) void {
        self.moved = false;
        if (self.right and g.world.placeFree(rules.toInt(self.x + self.speed), self.getY())) {
            self.moved = true;
            self.dir = .right;
            self.x += self.speed;
        } else if (self.left and g.world.placeFree(rules.toInt(self.x - self.speed), self.getY())) {
            self.moved = true;
            self.dir = .left;
            self.x -= self.speed;
        }

        if (self.up and g.world.placeFree(self.getX(), rules.toInt(self.y - self.speed))) {
            self.moved = true;
            self.y -= self.speed;
        } else if (self.down and g.world.placeFree(self.getX(), rules.toInt(self.y + self.speed))) {
            self.moved = true;
            self.y += self.speed;
        }

        if (self.moved) {
            self.frames += 1;
            if (self.frames == max_frames) {
                self.frames = 0;
                self.index += 1;
                if (self.index > max_index) self.index = 0;
            }
        }

        g.camera.x = Camera.clamp(self.getX() - (Game.width / 2), 0, g.world.width * rules.tile_size - Game.width);
        g.camera.y = Camera.clamp(self.getY() - (Game.height / 2), 0, g.world.height * rules.tile_size - Game.height);
    }

    /// No nivel 3 o jogador aparece com escudo (coluna 224) logo depois de
    /// eliminar um inimigo; o escudo de cada tipo de inimigo e religado apos
    /// alguns quadros. Como no Java, isso avanca no render.
    pub fn render(self: *Player, g: *Game) void {
        if (g.level == 3) {
            if (std.mem.indexOfScalar(bool, &g.escudo, false)) |kind| {
                self.sprite_x = 224;
                if (self.escudo > 15) {
                    g.escudo[kind] = true;
                    self.escudo = 0;
                }
                self.escudo += 1;
            } else {
                self.sprite_x = 160;
            }
        }

        const row: i32 = switch (self.dir) {
            .right => 16,
            .left => 0,
        };
        g.spritesheet.draw(g.image, .{ .x = self.sprite_x + self.index * 16, .y = row }, self.getX() - g.camera.x, self.getY() - g.camera.y);
    }
};

pub const Enemy = struct {
    kind: rules.EnemyKind,
    x: f64,
    y: f64,
    speed: f64 = 1.5,
    dir: Dir = .right,
    frames: i32 = 0,
    index: i32 = 0,
    moved: bool = false,

    const mask: rules.Rect = .{ .x = 6, .y = 3, .w = 8, .h = 12 };
    const max_frames = 20;
    const max_index = 1;

    pub fn init(kind: rules.EnemyKind, x: i32, y: i32) Enemy {
        return .{ .kind = kind, .x = @floatFromInt(x), .y = @floatFromInt(y) };
    }

    pub fn getX(self: Enemy) i32 {
        return rules.toInt(self.x);
    }

    pub fn getY(self: Enemy) i32 {
        return rules.toInt(self.y);
    }

    /// Nivel em que encostar no inimigo mata o jogador.
    fn deadlyLevel(self: Enemy) ?i32 {
        return switch (self.kind) {
            .enemy => 1,
            .enemy02 => 2,
            .enemy03 => null,
        };
    }

    /// Som tocado quando o inimigo e eliminado no nivel 3.
    fn deathSound(self: Enemy) SoundId {
        return switch (self.kind) {
            .enemy => .menu,
            .enemy02, .enemy03 => .monstro,
        };
    }

    fn moviment(self: *Enemy, g: *Game) void {
        if (g.world.placeFree(rules.toInt(self.x + self.speed), self.getY())) {
            self.x += self.speed;
            self.moved = true;
        } else {
            // Vira e anda sem checar a colisao de novo, como no Java.
            self.moved = true;
            self.speed *= -1;
            self.x += self.speed;
        }

        self.dir = if (self.speed < 0) .left else .right;
    }

    /// Retorna `true` quando o inimigo foi eliminado e deve sair da lista
    /// (`Game.entities.remove(this)` no Java).
    pub fn tick(self: *Enemy, g: *Game) bool {
        self.moved = false;
        var removed = false;

        const colliding = self.isCollidingWithPlayer(g.player);
        if (!colliding) {
            self.moviment(g);
        } else if (self.deadlyLevel() == g.level) {
            g.player.life -= 1;
            if (g.player.life == 0) {
                g.game_over = true;
                g.sounds.play(.menino);
            }
        } else if (g.level == 3) {
            g.sounds.play(self.deathSound());
            g.escudo[@intFromEnum(self.kind)] = false;
            removed = true;
            g.contador += 1;
        }

        if (self.moved) {
            self.frames += 1;
            if (self.frames == max_frames) {
                self.frames = 0;
                self.index += 1;
                if (self.index > max_index) self.index = 0;
            }
        }
        return removed;
    }

    pub fn isCollidingWithPlayer(self: Enemy, player: Player) bool {
        const enemy_atual: rules.Rect = .{ .x = self.getX() + mask.x, .y = self.getY() + mask.y, .w = mask.w, .h = mask.h };
        const player_rect: rules.Rect = .{ .x = player.getX(), .y = player.getY(), .w = 16, .h = 16 };
        return rules.intersects(enemy_atual, player_rect);
    }

    pub fn render(self: Enemy, g: *const Game) void {
        // Coluna do primeiro quadro e linhas de `rightEnemy`/`leftEnemy`.
        const x: i32, const right_y: i32, const left_y: i32 = switch (self.kind) {
            .enemy => .{ 96, 0, 16 },
            .enemy02 => .{ 96, 32, 48 },
            .enemy03 => .{ 128, 32, 48 },
        };
        const row = switch (self.dir) {
            .right => right_y,
            .left => left_y,
        };
        g.spritesheet.draw(g.image, .{ .x = x + self.index * 16, .y = row }, self.getX() - g.camera.x, self.getY() - g.camera.y);
    }
};
