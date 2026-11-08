package main

import "core:fmt"
import rl "vendor:raylib"
import "../keys"
import "../rules"

// `Main.Game`: estado global do jogo, `tick`, `render` e tratamento de teclas.
//
// As condicoes seguem o Java ao pe da letra (inclusive a precedencia de
// `a || b && c` e a ordem dos `else if`), para o jogo se comportar igual.

// Resolucao interna do mundo; a janela e `SCALE` vezes maior.
WIDTH :: 240
HEIGHT :: 160
SCALE :: 4
WIDTHFM :: WIDTH * SCALE
HEIGHTFM :: HEIGHT * SCALE

// Idioma escolhido no menu inicial (o `Game.idioma` do Java).
Lang :: enum u8 {
	Pt,
	En,
}

// Um texto em portugues e em ingles (na ordem de `Lang`), como os pares
// `{ ..., ... }` do Java; `tr` escolhe o do idioma atual.
Tr :: [2]string

TXTMENU1_PAUSA     :: Tr{"Retornar ao jogo", "Resume game"}
TXTMENU2_PAUSA     :: Tr{"Sair do jogo", "Quit game"}
TXTGO1             :: Tr{"Reiniciar a fase", "Restart level"}
TXTGO2             :: Tr{"Sair do jogo", "Quit game"}
TXT_MISSAO_TEXTO   :: Tr{"Chegue no hospital", "Get to the hospital"}
TXT_MISSAO_TEXTO1  :: Tr{"para se vacinar!", "to get vaccinated!"}
TXT_MISSAO_TEXTO3  :: Tr{"Dica: Desvie das bactérias.", "Tip: Dodge the bacteria."}
TXT_MISSAO_TEXTO4  :: Tr{"Vá para a área amarela", "Go to the yellow area"}
TXT_MISSAO_TEXTO5  :: Tr{"para se vacinar", "to get vaccinated"}
TXT_MISSAO_TEXTO6  :: Tr{"Utilize seu escudo para ", "Use your shield to "}
TXT_MISSAO_TEXTO7  :: Tr{"eliminar todos os vírus e bactérias", "eliminate all viruses and bacteria"}
TXT_MISSAO_TEXTO8  :: Tr{"Inimigos eliminados: ", "Enemies eliminated: "}
TXT_MISSAO_TEXTO9  :: Tr{"Todos os inimigos foram eliminados,", "All enemies have been eliminated,"}
TXT_MISSAO_TEXTO10 :: Tr{"volte para casa!", "go back home!"}

// Telas de tela inteira (960x640) com texto desenhado na imagem: existem em
// portugues e em ingles (`res/*_en.png`).
Screen :: enum u8 {
	Menu,
	Creditos,
	Imagem_Fim,
	Tela_Vacina,
	Vacinando,
	Vacinando1,
	Vacinando2,
	Vacinando3,
}

// Menus de pausa e de game over: 0 = primeira opcao, 1 = segunda.
OPTION_MAX :: 1

// `Enemy.escudo`, `Enemy02.escudo` e `Enemy03.escudo` religados.
ALL_SHIELDS :: [rules.Enemy_Kind]bool{.Enemy = true, .Enemy02 = true, .Enemy03 = true}

Game :: struct {
	spritesheet:    rl.Texture2D,
	morreu:         rl.Texture2D,
	// As telas de um idioma so sao carregadas quando ele e usado (o jogo
	// comeca em portugues).
	screens:        [Lang][Screen]rl.Texture2D,
	screens_loaded: [Lang]bool,
	// O `BufferedImage image` 240x160 onde o mundo e desenhado.
	image:          rl.RenderTexture2D,
	text:           Text,
	sounds:         Sounds,

	// Fica como o jogador escolheu ate o jogo fechar (`voltar_ao_menu` nao muda).
	lang:           Lang,
	level:          i32,
	contador:       i32,
	// Inimigos criados no mapa do nivel atual; no nivel 3 e preciso eliminar todos.
	total_inimigos: i32,
	pause:          bool,
	dialogo:        bool,
	vacinado:       bool,
	fim:            bool,
	game_over:      bool,
	escudo:         [rules.Enemy_Kind]bool,
	option_atual:   i32,
	w, s, enter:    bool,
	time, volta:    i32,
	// `System.exit(0)` pedido pelo menu.
	quit:           bool,

	camera:         rules.Camera,
	menu:           Menu,
	player:         Player,
	// `Game.entities` sem o jogador (que no Java e sempre o indice 0).
	enemies:        [dynamic]Enemy,
	world:          World,

	key_tracker:    keys.Tracker,
	focused:        bool,
}

// Carrega imagens, fontes e sons e monta o nivel 1 (a janela ja deve existir).
game_init :: proc(g: ^Game) {
	g^ = {}
	g.level = 1
	g.escudo = ALL_SHIELDS
	g.spritesheet = load_texture(SPRITESHEET_PNG)
	g.morreu = load_texture(GAME_OVER_PNG)
	load_screens(g, .Pt)
	g.image = rl.LoadRenderTexture(WIDTH, HEIGHT)
	g.text = text_load()
	sounds_load(&g.sounds)
	g.menu = menu_new()
	g.player = player_new(g.level)
	g.world = world_load(g)
}

game_destroy :: proc(g: ^Game) {
	world_destroy(&g.world)
	delete(g.enemies)
	sounds_unload(&g.sounds)
	text_unload(&g.text)
	rl.UnloadRenderTexture(g.image)
	for lang in Lang {
		if g.screens_loaded[lang] {
			for texture in g.screens[lang] {
				rl.UnloadTexture(texture)
			}
		}
	}
	rl.UnloadTexture(g.morreu)
	rl.UnloadTexture(g.spritesheet)
}

@(private = "file")
load_screens :: proc(g: ^Game, lang: Lang) {
	if g.screens_loaded[lang] {
		return
	}
	for screen in Screen {
		g.screens[lang][screen] = load_texture(screen_png(lang, screen))
	}
	g.screens_loaded[lang] = true
}

// O texto no idioma atual.
tr :: proc(g: ^Game, pair: Tr) -> string {
	return pair[int(g.lang)]
}

// Uma das telas com texto, no idioma atual.
screen :: proc(g: ^Game, which: Screen) -> rl.Texture2D {
	return g.screens[g.lang][which]
}

// Troca o idioma, carregando as telas dele na primeira vez.
set_lang :: proc(g: ^Game, lang: Lang) {
	load_screens(g, lang)
	g.lang = lang
}

// Depois da tela final: zera o progresso do jogo e volta ao menu inicial.
@(private = "file")
voltar_ao_menu :: proc(g: ^Game) {
	g.level = 1
	g.contador = 0
	g.pause = false
	g.dialogo = false
	g.vacinado = false
	g.game_over = false
	g.fim = false
	g.time = 0
	g.volta = 0
	g.option_atual = 0
	g.w = false
	g.s = false
	g.enter = false
	g.escudo = ALL_SHIELDS
	g.menu = menu_new()
	restart_game(g)
}

game_tick :: proc(g: ^Game) {
	if g.menu.state_inicio || g.menu.state_creditos && !g.pause && !g.game_over {
		menu_tick(&g.menu, g)
	} else if g.menu.state_jogo && !g.pause && !g.game_over && !g.dialogo && !g.fim {
		player_tick(&g.player, g)
		// Um inimigo eliminado sai da lista sem fazer o seguinte perder o tick.
		i := 0
		for i < len(g.enemies) {
			if enemy_tick(&g.enemies[i], g) {
				ordered_remove(&g.enemies, i)
			} else {
				i += 1
			}
		}

		if player_y(&g.player) < 80 && g.level == 1 {
			g.level = 2
			restart_game(g)
		}

		if g.vacinado {
			g.level = 3
			restart_game(g)
			g.vacinado = false
		}

		// Todos os inimigos eliminados e o jogador chegou em casa: fim de jogo.
		if g.level == 3 && g.contador >= g.total_inimigos && player_y(&g.player) < 175 &&
		   player_x(&g.player) > 559 && player_x(&g.player) < 593 {
			g.fim = true
		}
	} else if g.fim {
		// Tela final: tudo parado ate Enter/Esc.
		if g.enter {
			sound_play(&g.sounds, .Select)
			g.enter = false
			voltar_ao_menu(g)
		}
	} else if g.pause && !g.game_over {
		navegar_opcoes(g)

		if g.enter {
			sound_play(&g.sounds, .Select)
			g.enter = false

			if g.option_atual == 1 {
				g.quit = true
			} else if g.option_atual == 0 {
				g.pause = false
				g.option_atual = 0
			}
		}
	} else if g.game_over {
		navegar_opcoes(g)

		if g.enter {
			sound_play(&g.sounds, .Select)
			g.enter = false

			if g.option_atual == 0 {
				g.game_over = false
				restart_game(g)
			} else if g.option_atual == 1 {
				g.quit = true
			}
		}
	}
}

// W/S nos menus de pausa e de game over.
@(private = "file")
navegar_opcoes :: proc(g: ^Game) {
	if g.w {
		sound_play(&g.sounds, .Menu)
		g.w = false
		g.option_atual -= 1
		if g.option_atual < 0 {
			g.option_atual = OPTION_MAX
		}
	}

	if g.s {
		sound_play(&g.sounds, .Menu)
		g.s = false
		g.option_atual += 1
		if g.option_atual > OPTION_MAX {
			g.option_atual = 0
		}
	}
}

// Desenha o quadro na janela.
game_render :: proc(g: ^Game) {
	// Mundo e entidades na imagem 240x160.
	rl.BeginTextureMode(g.image)
	rl.ClearBackground(BLACK)
	if g.menu.state_jogo && !g.game_over {
		world_render(&g.world, g)
		player_render(&g.player, g)
		for &enemy in g.enemies {
			enemy_render(&enemy, g)
		}
	}
	rl.EndTextureMode()

	rl.BeginDrawing()
	rl.ClearBackground(BLACK)
	// A imagem ampliada (sem filtro) cobre o quadro inteiro. A altura negativa
	// desvira a textura, que o OpenGL guarda de cabeca para baixo.
	source := rl.Rectangle{0, 0, WIDTH, -HEIGHT}
	dest := rl.Rectangle{0, 0, WIDTHFM, HEIGHTFM}
	rl.DrawTexturePro(g.image.texture, source, dest, rl.Vector2{}, 0, rl.WHITE)

	render_screens(g)
	render_mission(g)
	rl.EndDrawing()
}

// Menus, game over, vacinacao e tela final, desenhados em 960x640.
@(private = "file")
render_screens :: proc(g: ^Game) {
	if g.menu.state_inicio || g.menu.state_creditos || g.menu.state_loading && !g.menu.state_jogo && !g.pause {
		menu_render(&g.menu, g)
	} else if g.fim {
		fill_screen(BLUE)
		draw_screen(screen(g, .Imagem_Fim))
	} else if g.pause && !g.game_over {
		render_options(g, tr(g, TXTMENU1_PAUSA), tr(g, TXTMENU2_PAUSA), WHITE)
	} else if g.game_over {
		draw_screen(g.morreu)
		render_options(g, tr(g, TXTGO1), tr(g, TXTGO2), BLACK)
	} else if player_y(&g.player) < 20 && player_x(&g.player) > 93 && player_x(&g.player) < 98 && g.level == 2 {
		g.dialogo = true
		fill_screen(BLUE)

		g.time += 1
		if g.volta < 3 {
			// Cada imagem fica 39 quadros; os quadros 40, 80, 120 e 160 ficam so azuis.
			if g.time < 40 {
				draw_screen(screen(g, .Vacinando))
			} else if g.time > 40 && g.time < 80 {
				draw_screen(screen(g, .Vacinando1))
			} else if g.time > 80 && g.time < 120 {
				draw_screen(screen(g, .Vacinando2))
			} else if g.time > 120 && g.time < 160 {
				draw_screen(screen(g, .Vacinando3))
			} else if g.time > 160 {
				g.time = 0
				g.volta += 1
			}
		} else if g.volta >= 3 && g.volta < 5 {
			draw_screen(screen(g, .Tela_Vacina))

			if g.time > 100 {
				g.volta += 1
				g.time = 0
			}
		} else if g.volta == 5 {
			g.dialogo = false
			g.vacinado = true
		}
	}
}

// As duas opcoes centralizadas dos menus de pausa e de game over.
@(private = "file")
render_options :: proc(g: ^Game, op1, op2: string, color: rl.Color) {
	cx :: WIDTHFM / 2
	cy :: HEIGHTFM / 2

	tam1 := text_width(&g.text, op1, .S30)
	text_draw(&g.text, op1, .S30, cx - tam1 / 2, cy - 50, color)
	tam2 := text_width(&g.text, op2, .S30)
	text_draw(&g.text, op2, .S30, cx - tam2 / 2, cy, color)

	if g.option_atual == 0 {
		text_draw(&g.text, ">", .S30, cx - tam1 / 2 - 40, cy - 50, color)
	} else if g.option_atual == 1 {
		text_draw(&g.text, ">", .S30, cx - tam2 / 2 - 40, cy, color)
	}
}

// Textos de missao no canto superior esquerdo (desenhados por cima de tudo).
@(private = "file")
render_mission :: proc(g: ^Game) {
	if g.level == 1 && !g.game_over && g.menu.state_jogo && player_y(&g.player) > 160 {
		text_draw(&g.text, tr(g, TXT_MISSAO_TEXTO), .S23, 15, 30, WHITE)
		text_draw(&g.text, tr(g, TXT_MISSAO_TEXTO1), .S23, 15, 60, WHITE)
		text_draw(&g.text, tr(g, TXT_MISSAO_TEXTO3), .S23, 15, 100, WHITE)
	} else if g.level == 2 && !g.game_over && g.menu.state_jogo && !g.vacinado && !g.dialogo {
		text_draw(&g.text, tr(g, TXT_MISSAO_TEXTO4), .S20, 15, 30, BLACK)
		text_draw(&g.text, tr(g, TXT_MISSAO_TEXTO5), .S20, 15, 60, BLACK)
	} else if g.level == 3 && !g.game_over && g.menu.state_jogo && player_y(&g.player) > 160 {
		if g.contador < g.total_inimigos {
			text_draw(&g.text, tr(g, TXT_MISSAO_TEXTO6), .S23, 15, 30, WHITE)
			text_draw(&g.text, tr(g, TXT_MISSAO_TEXTO7), .S23, 15, 60, WHITE)
			text_draw(&g.text, tr(g, TXT_MISSAO_TEXTO8), .S23, 15, 100, WHITE)
			buffer: [16]u8
			text_draw(&g.text, fmt.bprintf(buffer[:], "%d", g.contador), .S23, 275, 101, WHITE)
		}
		if g.contador >= g.total_inimigos && !g.fim {
			text_draw(&g.text, tr(g, TXT_MISSAO_TEXTO9), .S20, 15, 30, WHITE)
			text_draw(&g.text, tr(g, TXT_MISSAO_TEXTO10), .S20, 15, 60, WHITE)
		}
	}
}

// Repassa os eventos de teclado do quadro, na ordem em que aconteceram, para
// `key_pressed`/`key_released`, como o `KeyListener` do Java (incluindo a
// repeticao automatica de W/A/S/D segurado).
handle_input :: proc(g: ^Game, events: []keys.Event) {
	for event in events {
		switch event.action {
		case .Press:
			key_pressed(g, event.key)
		case .Repeat:
			if keys.repeats_when_held(event.key) {
				key_pressed(g, event.key)
			}
		case .Release:
			key_released(g, event.key)
		}
	}
}

// Sem foco o sistema nao avisa quando as teclas sao soltas: considera todas
// soltas (o `focusLost` do Java).
focus_lost :: proc(g: ^Game) {
	g.player.up = false
	g.player.down = false
	g.player.left = false
	g.player.right = false
}

key_pressed :: proc(g: ^Game, key: keys.Key) {
	if g.menu.state_inicio && !g.game_over {
		if key == .W {
			g.menu.w = true
		} else if key == .S {
			g.menu.s = true
		}
		if key == .Enter {
			g.menu.enter = true
		}
	} else if g.menu.state_creditos && !g.game_over {
		if key == .Enter || key == .Escape {
			g.menu.enter = true
		}
	} else if g.menu.state_jogo && !g.game_over && !g.fim {
		if key == .W {
			g.player.up = true
		} else if key == .S {
			g.player.down = true
		}

		if key == .D {
			g.player.right = true
		} else if key == .A {
			g.player.left = true
		}

		if key == .Escape {
			if g.pause {
				// Descarta W/S/Enter apertados no menu de pausa e ainda nao processados.
				g.pause = false
				g.option_atual = 0
				g.w = false
				g.s = false
				g.enter = false
			} else {
				g.pause = true
			}
		}

		if key == .W && g.pause {
			g.w = true
		} else if key == .S && g.pause {
			g.s = true
		}
		if key == .Enter && g.pause {
			g.enter = true
		}
	} else if g.menu.state_jogo && g.fim {
		if key == .Enter || key == .Escape {
			g.enter = true
		}
	} else if g.game_over {
		if key == .W {
			g.w = true
		} else if key == .S {
			g.s = true
		}
		if key == .Enter {
			g.enter = true
		}
	}
}

key_released :: proc(g: ^Game, key: keys.Key) {
	if g.menu.state_jogo {
		if key == .W {
			g.player.up = false
		} else if key == .S {
			g.player.down = false
		}

		if key == .D {
			g.player.right = false
		} else if key == .A {
			g.player.left = false
		}
	}
}
