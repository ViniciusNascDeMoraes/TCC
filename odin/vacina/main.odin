// Vacina: versao em Odin do jogo Java (`java/src/Main/Game.java`).
//
// Janela 960x640 ("Vacina"), 60 atualizacoes por segundo: a cada quadro le o
// teclado, executa `game_tick` e depois `game_render`, como o loop do Java.
// Janela, teclado, audio, PNG e rasterizacao das fontes vem do raylib que
// acompanha o Odin (`vendor:raylib`).
package main

import "core:fmt"
import rl "vendor:raylib"

main :: proc() {
	rl.SetTraceLogLevel(.WARNING)
	rl.InitWindow(WIDTHFM, HEIGHTFM, "Vacina")
	defer rl.CloseWindow()
	// Esc pausa o jogo; so fechar a janela (ou o menu) sai.
	rl.SetExitKey(.KEY_NULL)
	rl.SetTargetFPS(60)

	game := new(Game)
	defer free(game)
	game_init(game)
	defer game_destroy(game)

	frames := 0
	timer := rl.GetTime()
	for !rl.WindowShouldClose() {
		read_input(game)
		game_tick(game)
		if game.quit {
			break
		}
		game_render(game)
		frames += 1

		if rl.GetTime() - timer >= 1 {
			fmt.println("FPS:", frames)
			frames = 0
			timer += 1
		}
		free_all(context.temp_allocator)
	}
}
