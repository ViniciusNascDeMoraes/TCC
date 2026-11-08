package main

import "../rules"

// `Entities.Player`, `Entities.Enemy`, `Entities.Enemy02` e `Entities.Enemy03`.

Dir :: enum u8 {
	Right,
	Left,
}

Player :: struct {
	x, y:                  f64,
	right, left, up, down: bool,
	speed:                 f64,
	dir:                   Dir,
	life:                  i32,
	// `Player.escudo`: quadros desde que o escudo apareceu.
	escudo:                i32,
	frames:                i32,
	index:                 i32,
	moved:                 bool,
	// Coluna do primeiro quadro de `rightPlayer`/`leftPlayer` no Spritesheet.
	sprite_x:              i32,
}

PLAYER_MAX_FRAMES :: 5
PLAYER_MAX_INDEX :: 3

// O visual depende do nivel em que o jogador e criado.
player_new :: proc(level: i32) -> Player {
	return Player{speed = 1, life = 1, sprite_x = 160 if level == 3 else 32}
}

player_x :: proc(p: ^Player) -> i32 {
	return rules.to_int(p.x)
}

player_y :: proc(p: ^Player) -> i32 {
	return rules.to_int(p.y)
}

player_tick :: proc(p: ^Player, g: ^Game) {
	p.moved = false
	if p.right && world_place_free(&g.world, rules.to_int(p.x + p.speed), player_y(p)) {
		p.moved = true
		p.dir = .Right
		p.x += p.speed
	} else if p.left && world_place_free(&g.world, rules.to_int(p.x - p.speed), player_y(p)) {
		p.moved = true
		p.dir = .Left
		p.x -= p.speed
	}

	if p.up && world_place_free(&g.world, player_x(p), rules.to_int(p.y - p.speed)) {
		p.moved = true
		p.y -= p.speed
	} else if p.down && world_place_free(&g.world, player_x(p), rules.to_int(p.y + p.speed)) {
		p.moved = true
		p.y += p.speed
	}

	if p.moved {
		p.frames += 1
		if p.frames == PLAYER_MAX_FRAMES {
			p.frames = 0
			p.index += 1
			if p.index > PLAYER_MAX_INDEX {
				p.index = 0
			}
		}
	}

	g.camera.x = rules.camera_clamp(player_x(p) - WIDTH / 2, 0, g.world.width * rules.TILE_SIZE - WIDTH)
	g.camera.y = rules.camera_clamp(player_y(p) - HEIGHT / 2, 0, g.world.height * rules.TILE_SIZE - HEIGHT)
}

// No nivel 3 o jogador aparece com escudo (coluna 224) logo depois de eliminar
// um inimigo; o escudo de cada tipo de inimigo e religado apos alguns quadros.
// Como no Java, isso avanca no render.
player_render :: proc(p: ^Player, g: ^Game) {
	if g.level == 3 {
		shield_down := false
		for kind in rules.Enemy_Kind {
			if !g.escudo[kind] {
				shield_down = true
				p.sprite_x = 224
				if p.escudo > 15 {
					g.escudo[kind] = true
					p.escudo = 0
				}
				p.escudo += 1
				break
			}
		}
		if !shield_down {
			p.sprite_x = 160
		}
	}

	row: i32 = 16 if p.dir == .Right else 0
	sprite := rules.Sprite_Pos{p.sprite_x + p.index * 16, row}
	draw_sprite(g, sprite, player_x(p) - g.camera.x, player_y(p) - g.camera.y)
}

Enemy :: struct {
	kind:   rules.Enemy_Kind,
	x, y:   f64,
	speed:  f64,
	dir:    Dir,
	frames: i32,
	index:  i32,
	moved:  bool,
}

ENEMY_MASK :: rules.Rect{6, 3, 8, 12}
ENEMY_MAX_FRAMES :: 20
ENEMY_MAX_INDEX :: 1

enemy_new :: proc(kind: rules.Enemy_Kind, x, y: i32) -> Enemy {
	return Enemy{kind = kind, x = f64(x), y = f64(y), speed = 1.5}
}

enemy_x :: proc(e: ^Enemy) -> i32 {
	return rules.to_int(e.x)
}

enemy_y :: proc(e: ^Enemy) -> i32 {
	return rules.to_int(e.y)
}

// Nivel em que encostar no inimigo mata o jogador (0 = nenhum).
@(private = "file")
deadly_level :: proc(kind: rules.Enemy_Kind) -> i32 {
	switch kind {
	case .Enemy:   return 1
	case .Enemy02: return 2
	case .Enemy03: return 0
	}
	return 0
}

// Som tocado quando o inimigo e eliminado no nivel 3.
@(private = "file")
death_sound :: proc(kind: rules.Enemy_Kind) -> Sound_Id {
	return Sound_Id.Menu if kind == .Enemy else Sound_Id.Monstro
}

@(private = "file")
enemy_moviment :: proc(e: ^Enemy, g: ^Game) {
	if world_place_free(&g.world, rules.to_int(e.x + e.speed), enemy_y(e)) {
		e.x += e.speed
		e.moved = true
	} else {
		// Vira e anda sem checar a colisao de novo, como no Java.
		e.moved = true
		e.speed *= -1
		e.x += e.speed
	}

	e.dir = Dir.Left if e.speed < 0 else Dir.Right
}

// Retorna `true` quando o inimigo foi eliminado e deve sair da lista
// (`Game.entities.remove(this)` no Java).
enemy_tick :: proc(e: ^Enemy, g: ^Game) -> (removed: bool) {
	e.moved = false

	if !enemy_colliding_with_player(e, &g.player) {
		enemy_moviment(e, g)
	} else if deadly_level(e.kind) == g.level {
		g.player.life -= 1
		if g.player.life == 0 {
			g.game_over = true
			sound_play(&g.sounds, .Menino)
		}
	} else if g.level == 3 {
		sound_play(&g.sounds, death_sound(e.kind))
		g.escudo[e.kind] = false
		removed = true
		g.contador += 1
	}

	if e.moved {
		e.frames += 1
		if e.frames == ENEMY_MAX_FRAMES {
			e.frames = 0
			e.index += 1
			if e.index > ENEMY_MAX_INDEX {
				e.index = 0
			}
		}
	}
	return
}

enemy_colliding_with_player :: proc(e: ^Enemy, p: ^Player) -> bool {
	enemy_atual := rules.Rect{enemy_x(e) + ENEMY_MASK.x, enemy_y(e) + ENEMY_MASK.y, ENEMY_MASK.w, ENEMY_MASK.h}
	player := rules.Rect{player_x(p), player_y(p), 16, 16}
	return rules.intersects(enemy_atual, player)
}

enemy_render :: proc(e: ^Enemy, g: ^Game) {
	// Coluna do primeiro quadro e linhas de `rightEnemy`/`leftEnemy`.
	x, right_y, left_y: i32
	switch e.kind {
	case .Enemy:   x, right_y, left_y = 96, 0, 16
	case .Enemy02: x, right_y, left_y = 96, 32, 48
	case .Enemy03: x, right_y, left_y = 128, 32, 48
	}
	row := right_y if e.dir == .Right else left_y
	draw_sprite(g, rules.Sprite_Pos{x + e.index * 16, row}, enemy_x(e) - g.camera.x, enemy_y(e) - g.camera.y)
}
