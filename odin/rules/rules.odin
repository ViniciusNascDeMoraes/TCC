// Regras puras do jogo: tiles, leitura das cores dos niveis, colisao e camera.
// Equivale a `World.World` + `Graphics.Tile` (e subclasses) + `Camera.Camera`
// do Java, sem nenhuma chamada ao sistema, para poder ser testado sem janela.
package rules

TILE_SIZE :: 16

// Posicao (canto superior esquerdo) de um sprite 16x16 no Spritesheet.png.
Sprite_Pos :: struct {
	x, y: i32,
}

// Sprites estaticos de `Graphics.Tile`.
WALL           :: Sprite_Pos{0, 0}
FLOOR          :: Sprite_Pos{16, 0}
CALCADA        :: Sprite_Pos{0, 32}
CALCADA_PAREDE :: Sprite_Pos{0, 32}
ASFALTO        :: Sprite_Pos{0, 16}
ASFALTO_PAREDE :: Sprite_Pos{0, 16}
CRUZ           :: Sprite_Pos{0, 48}
HOSP           :: Sprite_Pos{16, 32}
LISTRA         :: Sprite_Pos{16, 16}
LISTRA_PAREDE  :: Sprite_Pos{16, 16}
PORTA          :: Sprite_Pos{0, 64}
PORTA2         :: Sprite_Pos{16, 64}
PORTA3         :: Sprite_Pos{32, 64}
JANELA         :: Sprite_Pos{16, 48}
MEDICO         :: Sprite_Pos{128, 0}
CHAO           :: Sprite_Pos{32, 32}
CHECK          :: Sprite_Pos{144, 0}
CASA           :: Sprite_Pos{0, 80}
C1             :: Sprite_Pos{0, 64}
C2             :: Sprite_Pos{16, 64}
C3             :: Sprite_Pos{32, 64}
CC1            :: Sprite_Pos{0, 96}
CC2            :: Sprite_Pos{16, 96}
CC3            :: Sprite_Pos{32, 96}

// Uma variante por subclasse de `Graphics.Tile`.
Tile_Kind :: enum u8 {
	Asfalto,
	Asfalto_Parede,
	C1,
	C2,
	C3,
	Calcada,
	Calcada_Parede,
	Casa,
	CC1,
	CC2,
	CC3,
	Chao,
	Check,
	Cruz,
	Floor,
	Hosp,
	Janela,
	Listra,
	Listra_Parede,
	Porta,
	Porta2,
	Porta3,
	Wall,
}

// Tipos bloqueados em `World.place_free`. `Wall` nao bloqueia.
SOLID :: bit_set[Tile_Kind]{.Floor, .Hosp, .Calcada_Parede, .Listra_Parede, .Asfalto_Parede, .Casa, .C1, .C2, .C3}

is_solid :: proc(kind: Tile_Kind) -> bool {
	return kind in SOLID
}

// O tipo e o sprite sao separados porque o nivel 2 usa a classe `Hosp` com o
// sprite `Medico`.
Tile :: struct {
	kind:   Tile_Kind,
	sprite: Sprite_Pos,
}

// `Enemy`, `Enemy02` e `Enemy03` do Java.
Enemy_Kind :: enum u8 {
	Enemy,
	Enemy02,
	Enemy03,
}

// O que um pixel do PNG do nivel representa.
Cell_Kind :: enum u8 {
	None,   // cor sem significado neste nivel (mantem o tile padrao)
	Tile,   // substitui o tile padrao do nivel
	Player, // posicao inicial do jogador (mantem o tile padrao)
	Enemy,  // inimigo (mantem o tile padrao)
}

Cell :: struct {
	kind:  Cell_Kind,
	tile:  Tile,       // quando `kind == .Tile`
	enemy: Enemy_Kind, // quando `kind == .Enemy`
}

PLAYER_CELL :: Cell{kind = .Player}

tile_cell :: proc(kind: Tile_Kind, sprite: Sprite_Pos) -> Cell {
	return Cell{kind = .Tile, tile = Tile{kind, sprite}}
}

enemy_cell :: proc(kind: Enemy_Kind) -> Cell {
	return Cell{kind = .Enemy, enemy = kind}
}

// Tile atribuido a toda celula antes de olhar a cor do pixel.
default_tile :: proc(level: i32) -> Tile {
	if level == 2 {
		return Tile{.Chao, CHAO}
	}
	return Tile{.Asfalto, ASFALTO}
}

// Tabela de cores ARGB de `World(String)` para cada nivel.
classify_pixel :: proc(level: i32, pixel: u32) -> Cell {
	switch level {
	case 1:
		switch pixel {
		case 0xFF007F0E: return tile_cell(.Floor, FLOOR)
		case 0xFFFF6A00: return tile_cell(.Wall, WALL)
		case 0xFF0026FF: return PLAYER_CELL
		case 0xFF404040: return tile_cell(.Calcada, CALCADA)
		case 0xFF5ECEFF: return tile_cell(.Calcada_Parede, CALCADA_PAREDE)
		case 0xFFFF0000: return enemy_cell(.Enemy)
		case 0xFF000000: return tile_cell(.Asfalto, ASFALTO)
		case 0xFF66FFED: return tile_cell(.Asfalto_Parede, ASFALTO_PAREDE)
		case 0xFFFF006E: return tile_cell(.Cruz, CRUZ)
		case 0xFF4800FF: return tile_cell(.Hosp, HOSP)
		case 0xFF7F3300: return tile_cell(.Janela, JANELA)
		case 0xFFFF00DC: return tile_cell(.Porta, PORTA)
		case 0xFFFFD800: return tile_cell(.Listra, LISTRA)
		case 0xFF38FF8A: return tile_cell(.Listra_Parede, LISTRA_PAREDE)
		case 0xFF5B7F00: return tile_cell(.Porta2, PORTA2)
		case 0xFF007F7F: return tile_cell(.Porta3, PORTA3)
		}
	case 2:
		switch pixel {
		case 0xFFFF0000: return tile_cell(.Hosp, MEDICO)
		case 0xFF000000: return tile_cell(.Chao, CHAO)
		case 0xFF0026FF: return PLAYER_CELL
		case 0xFFFFFFFF: return tile_cell(.Hosp, HOSP)
		case 0xFFFF00DC: return tile_cell(.Porta, PORTA)
		case 0xFF5B7F00: return tile_cell(.Porta2, PORTA2)
		case 0xFF007F7F: return tile_cell(.Porta3, PORTA3)
		case 0xFF007F0E: return tile_cell(.Check, CHECK)
		case 0xFF7F0037: return enemy_cell(.Enemy02)
		case 0xFFF4FF68: return tile_cell(.C1, C1)
		case 0xFFFFD760: return tile_cell(.C2, C2)
		case 0xFFFF9E44: return tile_cell(.C3, C3)
		}
	case 3:
		switch pixel {
		case 0xFF007F0E: return tile_cell(.Floor, FLOOR)
		case 0xFFFF6A00: return tile_cell(.Wall, WALL)
		case 0xFF0026FF: return PLAYER_CELL
		case 0xFF404040: return tile_cell(.Calcada, CALCADA)
		case 0xFF5ECEFF: return tile_cell(.Calcada_Parede, CALCADA_PAREDE)
		case 0xFFFF0000: return enemy_cell(.Enemy)
		case 0xFFFF5956: return enemy_cell(.Enemy02)
		case 0xFFFF96A0: return enemy_cell(.Enemy03)
		case 0xFF000000: return tile_cell(.Asfalto, ASFALTO)
		case 0xFF66FFED: return tile_cell(.Asfalto_Parede, ASFALTO_PAREDE)
		case 0xFFFF006E: return tile_cell(.Cruz, CRUZ)
		case 0xFF4800FF: return tile_cell(.Hosp, HOSP)
		case 0xFF7F3300: return tile_cell(.Janela, JANELA)
		case 0xFFFF00DC: return tile_cell(.Porta, PORTA)
		case 0xFFFFD800: return tile_cell(.Listra, LISTRA)
		case 0xFF38FF8A: return tile_cell(.Listra_Parede, LISTRA_PAREDE)
		case 0xFF5B7F00: return tile_cell(.Porta2, PORTA2)
		case 0xFF007F7F: return tile_cell(.Porta3, PORTA3)
		case 0xFFD6FFCC: return tile_cell(.Casa, CASA)
		case 0xFF503F7F: return tile_cell(.CC1, CC1)
		case 0xFF527F3F: return tile_cell(.CC2, CC2)
		case 0xFFA5FF7F: return tile_cell(.CC3, CC3)
		}
	}
	return Cell{}
}

// Um inimigo criado pelo mapa, em pixels do mundo.
Spawn :: struct {
	kind: Enemy_Kind,
	x, y: i32,
}

// O nivel montado a partir das cores do PNG.
Level_Map :: struct {
	width, height:      i32,
	tiles:              []Tile,
	// Posicao inicial do jogador, se o mapa tiver uma (senao ele fica em 0, 0).
	has_player:         bool,
	player_x, player_y: i32,
	// Inimigos na ordem em que o Java os cria.
	spawns:             [dynamic]Spawn,
}

// `new World("/levelN.png")`: cada pixel (ARGB, linha a linha) vira um tile, a
// posicao inicial do jogador ou um inimigo, conforme `classify_pixel`.
build_level :: proc(level: i32, width, height: i32, pixels: []u32, allocator := context.allocator) -> Level_Map {
	assert(int(width) * int(height) == len(pixels))
	m := Level_Map {
		width  = width,
		height = height,
		tiles  = make([]Tile, len(pixels), allocator),
		spawns = make([dynamic]Spawn, allocator),
	}

	// Mesma ordem do Java (x por fora, y por dentro): define a ordem dos
	// inimigos, e a ultima cor de jogador e a que vale.
	for xx in 0 ..< width {
		for yy in 0 ..< height {
			index := xx + yy * width
			x := xx * TILE_SIZE
			y := yy * TILE_SIZE

			m.tiles[index] = default_tile(level)
			cell := classify_pixel(level, pixels[index])
			switch cell.kind {
			case .Tile:
				m.tiles[index] = cell.tile
			case .Player:
				m.has_player = true
				m.player_x = x
				m.player_y = y
			case .Enemy:
				append(&m.spawns, Spawn{cell.enemy, x, y})
			case .None:
			}
		}
	}
	return m
}

destroy_level :: proc(m: ^Level_Map) {
	delete(m.tiles)
	delete(m.spawns)
	m^ = {}
}

// `World.place_free`: testa os quatro cantos de um quadrado 16x16.
// O indice e calculado como no Java (`x + y * width`); um indice fora do
// array, que no Java lancaria excecao, conta como bloqueado.
place_free :: proc(tiles: []Tile, width: i32, xnext, ynext: i32) -> bool {
	// A divisao inteira trunca em direcao a zero, como no Java.
	x1 := xnext / TILE_SIZE
	y1 := ynext / TILE_SIZE

	x2 := (xnext + TILE_SIZE - 1) / TILE_SIZE
	y2 := ynext / TILE_SIZE

	x3 := xnext / TILE_SIZE
	y3 := (ynext + TILE_SIZE - 1) / TILE_SIZE

	x4 := (xnext + TILE_SIZE - 1) / TILE_SIZE
	y4 := (ynext + TILE_SIZE - 1) / TILE_SIZE

	corners := [4][2]i32{{x1, y1}, {x2, y2}, {x3, y3}, {x4, y4}}
	for c in corners {
		index := int(c[0]) + int(c[1]) * int(width)
		if index < 0 || index >= len(tiles) {
			return false
		}
		if is_solid(tiles[index].kind) {
			return false
		}
	}
	return true
}

Rect :: struct {
	x, y, w, h: i32,
}

// `java.awt.Rectangle.intersects`.
intersects :: proc(a, b: Rect) -> bool {
	if a.w <= 0 || a.h <= 0 || b.w <= 0 || b.h <= 0 {
		return false
	}
	return b.x + b.w > a.x && b.y + b.h > a.y && a.x + a.w > b.x && a.y + a.h > b.y
}

// Conversao `(int)` do Java de double para int (trunca em direcao a zero).
to_int :: proc(value: f64) -> i32 {
	return i32(value)
}

// `Camera.Camera`: deslocamento da visao sobre o mapa.
Camera :: struct {
	x, y: i32,
}

// `Camera.clamp`: limita primeiro pelo minimo e depois pelo maximo (com o
// maximo menor que o minimo, vence o maximo).
camera_clamp :: proc(atual, min_value, max_value: i32) -> i32 {
	value := atual
	if value < min_value {
		value = min_value
	}
	if value > max_value {
		value = max_value
	}
	return value
}
