package main

import rl "vendor:raylib"
import "../rules"

// `World.World`: o mapa do nivel atual, montado a partir do PNG do nivel.
World :: struct {
	width, height: i32,
	tiles:         []rules.Tile,
}

// `new World("/levelN.png")`: posiciona o jogador e cria os inimigos do mapa
// do nivel atual (`g.level`), conforme `rules.build_level`.
world_load :: proc(g: ^Game) -> World {
	png := level_png(g.level)
	image := rl.LoadImageFromMemory(".png", raw_data(png), i32(len(png)))
	defer rl.UnloadImage(image)
	colors := rl.LoadImageColors(image)
	defer rl.UnloadImageColors(colors)

	count := int(image.width) * int(image.height)
	pixels := make([]u32, count, context.temp_allocator)
	for i in 0 ..< count {
		c := colors[i]
		pixels[i] = u32(c.a) << 24 | u32(c.r) << 16 | u32(c.g) << 8 | u32(c.b)
	}

	level := rules.build_level(g.level, image.width, image.height, pixels)
	defer delete(level.spawns)

	if level.has_player {
		g.player.x = f64(level.player_x)
		g.player.y = f64(level.player_y)
	}
	for spawn in level.spawns {
		append(&g.enemies, enemy_new(spawn.kind, spawn.x, spawn.y))
	}
	// A lista so tem os inimigos deste mapa (`restart_game` a esvazia antes).
	g.total_inimigos = i32(len(g.enemies))
	return World{width = level.width, height = level.height, tiles = level.tiles}
}

world_destroy :: proc(w: ^World) {
	delete(w.tiles)
	w^ = {}
}

// `World.place_free`.
world_place_free :: proc(w: ^World, xnext, ynext: i32) -> bool {
	return rules.place_free(w.tiles, w.width, xnext, ynext)
}

// Desenha so os tiles visiveis pela camera.
world_render :: proc(w: ^World, g: ^Game) {
	xstart := g.camera.x / rules.TILE_SIZE
	ystart := g.camera.y / rules.TILE_SIZE

	xfinal := xstart + WIDTH / rules.TILE_SIZE
	yfinal := ystart + HEIGHT / rules.TILE_SIZE

	for xx in xstart ..= xfinal {
		for yy in ystart ..= yfinal {
			if xx < 0 || yy < 0 || xx >= w.width || yy >= w.height {
				continue
			}
			tile := w.tiles[xx + yy * w.width]
			draw_sprite(g, tile.sprite, xx * rules.TILE_SIZE - g.camera.x, yy * rules.TILE_SIZE - g.camera.y)
		}
	}
}

// `World.restartGame`: recria o jogador e os inimigos e recarrega o mapa do
// nivel atual. Como no Java, nao mexe na camera, no contador nem nos escudos.
restart_game :: proc(g: ^Game) {
	clear(&g.enemies)
	g.player = player_new(g.level)
	world := world_load(g)
	world_destroy(&g.world)
	g.world = world
}
