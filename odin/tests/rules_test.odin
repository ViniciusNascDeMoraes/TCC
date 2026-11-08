// Testes da logica pura (sem janela nem audio): `odin test tests`.
package tests

import "core:image"
import "core:image/png"
import "core:testing"
import "../rules"

@(test)
cores_do_nivel_viram_os_mesmos_tiles_do_java :: proc(t: ^testing.T) {
	testing.expect_value(t, rules.classify_pixel(1, 0xFF007F0E), rules.tile_cell(.Floor, rules.FLOOR))
	// A mesma cor e um Check livre no nivel 2.
	testing.expect_value(t, rules.classify_pixel(2, 0xFF007F0E), rules.tile_cell(.Check, rules.CHECK))
	testing.expect_value(t, rules.classify_pixel(2, 0xFFFF0000), rules.tile_cell(.Hosp, rules.MEDICO))
	testing.expect_value(t, rules.classify_pixel(3, 0xFFFF96A0), rules.enemy_cell(.Enemy03))
	testing.expect_value(t, rules.classify_pixel(2, 0xFF0026FF), rules.PLAYER_CELL)
	// Casa so existe no nivel 3.
	testing.expect_value(t, rules.classify_pixel(1, 0xFFD6FFCC), rules.Cell{})
	testing.expect_value(t, rules.classify_pixel(3, 0xFFD6FFCC), rules.tile_cell(.Casa, rules.CASA))
}

@(test)
solidos_de_place_free :: proc(t: ^testing.T) {
	testing.expect(t, rules.is_solid(.Floor))
	testing.expect(t, rules.is_solid(.Calcada_Parede))
	testing.expect(t, !rules.is_solid(.Calcada))
	testing.expect(t, !rules.is_solid(.Wall))
	testing.expect(t, !rules.is_solid(.Check))
}

@(test)
place_free_testa_os_quatro_cantos :: proc(t: ^testing.T) {
	free_tile := rules.Tile{.Asfalto, rules.ASFALTO}
	solid := rules.Tile{.Floor, rules.FLOOR}
	// Mapa 3x3 com o centro solido.
	tiles := [9]rules.Tile{free_tile, free_tile, free_tile, free_tile, solid, free_tile, free_tile, free_tile, free_tile}
	testing.expect(t, rules.place_free(tiles[:], 3, 0, 0))
	// (1,0) so toca a linha 0, livre; (1,1) alcanca o centro pelo canto 4.
	testing.expect(t, rules.place_free(tiles[:], 3, 1, 0))
	testing.expect(t, !rules.place_free(tiles[:], 3, 1, 1))
	testing.expect(t, !rules.place_free(tiles[:], 3, 16, 16))
	testing.expect(t, rules.place_free(tiles[:], 3, 32, 0))
	// Divisao inteira do Java trunca em direcao a zero: -15 / 16 == 0.
	testing.expect(t, rules.place_free(tiles[:], 3, -15, 0))
	// Fora do array conta como bloqueado.
	testing.expect(t, !rules.place_free(tiles[:], 3, 0, 40))
}

@(test)
intersects_segue_java_awt_rectangle :: proc(t: ^testing.T) {
	player := rules.Rect{0, 0, 16, 16}
	testing.expect(t, rules.intersects(rules.Rect{6, 3, 8, 12}, player))
	// Encostar a borda nao conta.
	testing.expect(t, !rules.intersects(rules.Rect{16, 0, 8, 12}, player))
	testing.expect(t, rules.intersects(rules.Rect{15, 0, 8, 12}, player))
	testing.expect(t, !rules.intersects(rules.Rect{0, 0, 0, 12}, player))
}

@(test)
to_int_trunca_como_o_cast_do_java :: proc(t: ^testing.T) {
	testing.expect_value(t, rules.to_int(1.5), 1)
	testing.expect_value(t, rules.to_int(-1.5), -1)
}

@(test)
camera_clamp :: proc(t: ^testing.T) {
	testing.expect_value(t, rules.camera_clamp(-5, 0, 10), 0)
	testing.expect_value(t, rules.camera_clamp(15, 0, 10), 10)
	testing.expect_value(t, rules.camera_clamp(7, 0, 10), 7)
	// Maximo menor que o minimo: vence o maximo, como no Java.
	testing.expect_value(t, rules.camera_clamp(5, 0, -3), -3)
}

// Decodifica um PNG de nivel em pixels ARGB.
@(private = "file")
decode_level :: proc(t: ^testing.T, data: []u8) -> (width, height: i32, pixels: []u32, ok: bool) {
	img, err := png.load_from_bytes(data, image.Options{.alpha_add_if_missing})
	if !testing.expectf(t, err == nil, "PNG invalido: %v", err) {
		return
	}
	defer png.destroy(img)
	if !testing.expect(t, img.channels == 4 && img.depth == 8) {
		return
	}
	pixels = make([]u32, img.width * img.height)
	for i in 0 ..< len(pixels) {
		p := img.pixels[i * 4:][:4]
		pixels[i] = u32(p[3]) << 24 | u32(p[0]) << 16 | u32(p[1]) << 8 | u32(p[2])
	}
	return i32(img.width), i32(img.height), pixels, true
}

@(private = "file")
Level_Expectation :: struct {
	level:              i32,
	data:               []u8,
	width, height:      i32,
	player_x, player_y: i32,
	enemies:            [rules.Enemy_Kind]int,
	first, last:        rules.Spawn,
}

@(test)
mapas_dos_niveis :: proc(t: ^testing.T) {
	// Valores tirados dos PNGs, na ordem em que o Java le os pixels.
	cases := [?]Level_Expectation {
		{
			level = 1, data = #load("../res/level1.png"), width = 15, height = 45,
			player_x = 176, player_y = 688, enemies = {.Enemy = 12, .Enemy02 = 0, .Enemy03 = 0},
			first = {.Enemy, 48, 144}, last = {.Enemy, 176, 624},
		},
		{
			level = 2, data = #load("../res/level2.png"), width = 15, height = 10,
			player_x = 112, player_y = 128, enemies = {.Enemy = 0, .Enemy02 = 5, .Enemy03 = 0},
			first = {.Enemy02, 32, 48}, last = {.Enemy02, 208, 80},
		},
		{
			level = 3, data = #load("../res/level3.png"), width = 43, height = 60,
			player_x = 112, player_y = 96, enemies = {.Enemy = 7, .Enemy02 = 7, .Enemy03 = 8},
			first = {.Enemy02, 48, 240}, last = {.Enemy03, 624, 224},
		},
	}
	for c in cases {
		width, height, pixels, ok := decode_level(t, c.data)
		if !ok {
			continue
		}
		defer delete(pixels)
		m := rules.build_level(c.level, width, height, pixels)
		defer rules.destroy_level(&m)

		testing.expect_value(t, m.width, c.width)
		testing.expect_value(t, m.height, c.height)
		testing.expect(t, m.has_player)
		testing.expect_value(t, m.player_x, c.player_x)
		testing.expect_value(t, m.player_y, c.player_y)

		counts: [rules.Enemy_Kind]int
		for spawn in m.spawns {
			counts[spawn.kind] += 1
		}
		testing.expect_value(t, counts, c.enemies)
		if testing.expect(t, len(m.spawns) > 0) {
			testing.expect_value(t, m.spawns[0], c.first)
			testing.expect_value(t, m.spawns[len(m.spawns) - 1], c.last)
		}

		// A celula do jogador fica com o tile padrao do nivel.
		start := (c.player_x / rules.TILE_SIZE) + (c.player_y / rules.TILE_SIZE) * width
		testing.expect_value(t, m.tiles[start], rules.default_tile(c.level))
	}
}
