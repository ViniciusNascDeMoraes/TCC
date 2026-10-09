//! Regras puras do mapa: tiles, leitura das cores dos niveis e colisao.
//! Equivale a `World.World` + `Graphics.Tile` (e subclasses) do Java, sem
//! nenhuma chamada ao raylib, para poder ser testado sem janela.

const std = @import("std");

pub const tile_size = 16;

/// Posicao (canto superior esquerdo) de um sprite 16x16 no Spritesheet.png.
pub const SpritePos = struct {
    x: i32,
    y: i32,
};

/// Sprites estaticos de `Graphics.Tile`.
pub const sprites = struct {
    pub const wall: SpritePos = .{ .x = 0, .y = 0 };
    pub const floor: SpritePos = .{ .x = 16, .y = 0 };
    pub const calcada: SpritePos = .{ .x = 0, .y = 32 };
    pub const calcada_parede: SpritePos = .{ .x = 0, .y = 32 };
    pub const asfalto: SpritePos = .{ .x = 0, .y = 16 };
    pub const asfalto_parede: SpritePos = .{ .x = 0, .y = 16 };
    pub const cruz: SpritePos = .{ .x = 0, .y = 48 };
    pub const hosp: SpritePos = .{ .x = 16, .y = 32 };
    pub const listra: SpritePos = .{ .x = 16, .y = 16 };
    pub const listra_parede: SpritePos = .{ .x = 16, .y = 16 };
    pub const porta: SpritePos = .{ .x = 0, .y = 64 };
    pub const porta2: SpritePos = .{ .x = 16, .y = 64 };
    pub const porta3: SpritePos = .{ .x = 32, .y = 64 };
    pub const janela: SpritePos = .{ .x = 16, .y = 48 };
    pub const medico: SpritePos = .{ .x = 128, .y = 0 };
    pub const chao: SpritePos = .{ .x = 32, .y = 32 };
    pub const check: SpritePos = .{ .x = 144, .y = 0 };
    pub const casa: SpritePos = .{ .x = 0, .y = 80 };
    pub const c1: SpritePos = .{ .x = 0, .y = 64 };
    pub const c2: SpritePos = .{ .x = 16, .y = 64 };
    pub const c3: SpritePos = .{ .x = 32, .y = 64 };
    pub const cc1: SpritePos = .{ .x = 0, .y = 96 };
    pub const cc2: SpritePos = .{ .x = 16, .y = 96 };
    pub const cc3: SpritePos = .{ .x = 32, .y = 96 };
};

/// Uma variante por subclasse de `Graphics.Tile`.
pub const TileKind = enum {
    asfalto,
    asfalto_parede,
    c1,
    c2,
    c3,
    calcada,
    calcada_parede,
    casa,
    cc1,
    cc2,
    cc3,
    chao,
    check,
    cruz,
    floor,
    hosp,
    janela,
    listra,
    listra_parede,
    porta,
    porta2,
    porta3,
    wall,

    /// Tipos bloqueados em `World.place_free`. `Wall` nao bloqueia.
    pub fn isSolid(kind: TileKind) bool {
        return switch (kind) {
            .floor, .hosp, .calcada_parede, .listra_parede, .asfalto_parede, .casa, .c1, .c2, .c3 => true,
            else => false,
        };
    }
};

/// O tipo e o sprite sao separados porque o nivel 2 usa a classe `Hosp`
/// com o sprite `Medico`.
pub const Tile = struct {
    kind: TileKind,
    sprite: SpritePos,
};

/// `Enemy`, `Enemy02` e `Enemy03` do Java.
pub const EnemyKind = enum(u2) {
    enemy,
    enemy02,
    enemy03,
};

/// O que um pixel do PNG do nivel representa.
pub const Cell = union(enum) {
    /// Substitui o tile padrao do nivel.
    tile: Tile,
    /// Posicao inicial do jogador (mantem o tile padrao).
    player,
    /// Inimigo (mantem o tile padrao).
    enemy: EnemyKind,
    /// Cor sem significado neste nivel (mantem o tile padrao).
    none,
};

fn t(kind: TileKind, sprite: SpritePos) Cell {
    return .{ .tile = .{ .kind = kind, .sprite = sprite } };
}

/// Tile atribuido a toda celula antes de olhar a cor do pixel.
pub fn defaultTile(level: i32) Tile {
    return switch (level) {
        1, 3 => .{ .kind = .asfalto, .sprite = sprites.asfalto },
        2 => .{ .kind = .chao, .sprite = sprites.chao },
        else => unreachable,
    };
}

/// Tabela de cores ARGB de `World(String)` para cada nivel.
pub fn classifyPixel(level: i32, pixel: u32) Cell {
    return switch (level) {
        1 => switch (pixel) {
            0xFF007F0E => t(.floor, sprites.floor),
            0xFFFF6A00 => t(.wall, sprites.wall),
            0xFF0026FF => .player,
            0xFF404040 => t(.calcada, sprites.calcada),
            0xFF5ECEFF => t(.calcada_parede, sprites.calcada_parede),
            0xFFFF0000 => .{ .enemy = .enemy },
            0xFF000000 => t(.asfalto, sprites.asfalto),
            0xFF66FFED => t(.asfalto_parede, sprites.asfalto_parede),
            0xFFFF006E => t(.cruz, sprites.cruz),
            0xFF4800FF => t(.hosp, sprites.hosp),
            0xFF7F3300 => t(.janela, sprites.janela),
            0xFFFF00DC => t(.porta, sprites.porta),
            0xFFFFD800 => t(.listra, sprites.listra),
            0xFF38FF8A => t(.listra_parede, sprites.listra_parede),
            0xFF5B7F00 => t(.porta2, sprites.porta2),
            0xFF007F7F => t(.porta3, sprites.porta3),
            else => .none,
        },
        2 => switch (pixel) {
            0xFFFF0000 => t(.hosp, sprites.medico),
            0xFF000000 => t(.chao, sprites.chao),
            0xFF0026FF => .player,
            0xFFFFFFFF => t(.hosp, sprites.hosp),
            0xFFFF00DC => t(.porta, sprites.porta),
            0xFF5B7F00 => t(.porta2, sprites.porta2),
            0xFF007F7F => t(.porta3, sprites.porta3),
            0xFF007F0E => t(.check, sprites.check),
            0xFF7F0037 => .{ .enemy = .enemy02 },
            0xFFF4FF68 => t(.c1, sprites.c1),
            0xFFFFD760 => t(.c2, sprites.c2),
            0xFFFF9E44 => t(.c3, sprites.c3),
            else => .none,
        },
        3 => switch (pixel) {
            0xFF007F0E => t(.floor, sprites.floor),
            0xFFFF6A00 => t(.wall, sprites.wall),
            0xFF0026FF => .player,
            0xFF404040 => t(.calcada, sprites.calcada),
            0xFF5ECEFF => t(.calcada_parede, sprites.calcada_parede),
            0xFFFF0000 => .{ .enemy = .enemy },
            0xFFFF5956 => .{ .enemy = .enemy02 },
            0xFFFF96A0 => .{ .enemy = .enemy03 },
            0xFF000000 => t(.asfalto, sprites.asfalto),
            0xFF66FFED => t(.asfalto_parede, sprites.asfalto_parede),
            0xFFFF006E => t(.cruz, sprites.cruz),
            0xFF4800FF => t(.hosp, sprites.hosp),
            0xFF7F3300 => t(.janela, sprites.janela),
            0xFFFF00DC => t(.porta, sprites.porta),
            0xFFFFD800 => t(.listra, sprites.listra),
            0xFF38FF8A => t(.listra_parede, sprites.listra_parede),
            0xFF5B7F00 => t(.porta2, sprites.porta2),
            0xFF007F7F => t(.porta3, sprites.porta3),
            0xFFD6FFCC => t(.casa, sprites.casa),
            0xFF503F7F => t(.cc1, sprites.cc1),
            0xFF527F3F => t(.cc2, sprites.cc2),
            0xFFA5FF7F => t(.cc3, sprites.cc3),
            else => .none,
        },
        else => unreachable,
    };
}

/// Monta o valor ARGB que o `BufferedImage.getRGB` do Java devolveria.
pub fn argb(r: u8, g: u8, b: u8, a: u8) u32 {
    return @as(u32, a) << 24 | @as(u32, r) << 16 | @as(u32, g) << 8 | b;
}

/// `World.place_free`: testa os quatro cantos de um quadrado 16x16.
/// O indice e calculado como no Java (`x + y * width`); um indice fora do
/// array, que no Java lancaria excecao, conta como bloqueado.
pub fn placeFree(tiles: []const Tile, width: i32, xnext: i32, ynext: i32) bool {
    const x1 = @divTrunc(xnext, tile_size);
    const y1 = @divTrunc(ynext, tile_size);

    const x2 = @divTrunc(xnext + tile_size - 1, tile_size);
    const y2 = @divTrunc(ynext, tile_size);

    const x3 = @divTrunc(xnext, tile_size);
    const y3 = @divTrunc(ynext + tile_size - 1, tile_size);

    const x4 = @divTrunc(xnext + tile_size - 1, tile_size);
    const y4 = @divTrunc(ynext + tile_size - 1, tile_size);

    const corners = [_][2]i32{ .{ x1, y1 }, .{ x2, y2 }, .{ x3, y3 }, .{ x4, y4 } };
    for (corners) |c| {
        const index = c[0] + c[1] * width;
        if (index < 0 or index >= tiles.len) return false;
        if (tiles[@intCast(index)].kind.isSolid()) return false;
    }
    return true;
}

pub const Rect = struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,
};

/// `java.awt.Rectangle.intersects`.
pub fn intersects(a: Rect, b: Rect) bool {
    if (a.w <= 0 or a.h <= 0 or b.w <= 0 or b.h <= 0) return false;
    return b.x + b.w > a.x and b.y + b.h > a.y and a.x + a.w > b.x and a.y + a.h > b.y;
}

/// Conversao `(int)` do Java de double para int (trunca em direcao a zero).
pub fn toInt(value: f64) i32 {
    return @intFromFloat(value);
}

test "cores do nivel viram os mesmos tiles do Java" {
    try std.testing.expectEqual(Cell{ .tile = .{ .kind = .floor, .sprite = sprites.floor } }, classifyPixel(1, 0xFF007F0E));
    // A mesma cor e um Check livre no nivel 2.
    try std.testing.expectEqual(Cell{ .tile = .{ .kind = .check, .sprite = sprites.check } }, classifyPixel(2, 0xFF007F0E));
    try std.testing.expectEqual(Cell{ .tile = .{ .kind = .hosp, .sprite = sprites.medico } }, classifyPixel(2, 0xFFFF0000));
    try std.testing.expectEqual(Cell{ .enemy = .enemy03 }, classifyPixel(3, 0xFFFF96A0));
    try std.testing.expectEqual(Cell.player, classifyPixel(2, 0xFF0026FF));
    // Casa so existe no nivel 3.
    try std.testing.expectEqual(Cell.none, classifyPixel(1, 0xFFD6FFCC));
    try std.testing.expectEqual(@as(u32, 0xFF007F0E), argb(0x00, 0x7F, 0x0E, 0xFF));
}

test "solidos de place_free" {
    try std.testing.expect(TileKind.floor.isSolid());
    try std.testing.expect(TileKind.calcada_parede.isSolid());
    try std.testing.expect(!TileKind.calcada.isSolid());
    try std.testing.expect(!TileKind.wall.isSolid());
    try std.testing.expect(!TileKind.check.isSolid());
}

test "placeFree testa os quatro cantos" {
    const free: Tile = .{ .kind = .asfalto, .sprite = sprites.asfalto };
    const solid: Tile = .{ .kind = .floor, .sprite = sprites.floor };
    // Mapa 3x3 com o centro solido.
    const tiles = [_]Tile{ free, free, free, free, solid, free, free, free, free };
    try std.testing.expect(placeFree(&tiles, 3, 0, 0));
    // (1,0) so toca a linha 0, livre; (1,1) alcanca o centro pelo canto 4.
    try std.testing.expect(placeFree(&tiles, 3, 1, 0));
    try std.testing.expect(!placeFree(&tiles, 3, 1, 1));
    try std.testing.expect(!placeFree(&tiles, 3, 16, 16));
    try std.testing.expect(placeFree(&tiles, 3, 32, 0));
    // Divisao inteira do Java trunca em direcao a zero: -15 / 16 == 0.
    try std.testing.expect(placeFree(&tiles, 3, -15, 0));
    // Fora do array conta como bloqueado.
    try std.testing.expect(!placeFree(&tiles, 3, 0, 40));
}

test "intersects segue java.awt.Rectangle" {
    const player: Rect = .{ .x = 0, .y = 0, .w = 16, .h = 16 };
    try std.testing.expect(intersects(.{ .x = 6, .y = 3, .w = 8, .h = 12 }, player));
    // Encostar a borda nao conta.
    try std.testing.expect(!intersects(.{ .x = 16, .y = 0, .w = 8, .h = 12 }, player));
    try std.testing.expect(intersects(.{ .x = 15, .y = 0, .w = 8, .h = 12 }, player));
    try std.testing.expect(!intersects(.{ .x = 0, .y = 0, .w = 0, .h = 12 }, player));
}

test "toInt trunca como o cast do Java" {
    try std.testing.expectEqual(@as(i32, 1), toInt(1.5));
    try std.testing.expectEqual(@as(i32, -1), toInt(-1.5));
}
