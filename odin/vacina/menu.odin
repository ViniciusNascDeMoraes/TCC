package main

// `Main.Menu`: tela inicial, creditos e animacao de "Carregando".

TXTMENU1  :: Tr{"Novo jogo", "New game"}
TXTMENU2  :: Tr{"Créditos", "Credits"}
TXTIDIOMA :: Tr{"Idioma: Português", "Language: English"}
TXTMENU3  :: Tr{"Sair", "Quit"}
TXTCRED1  :: Tr{"Voltar", "Back"}
LOADING_TITLE1 :: Tr{"Carregando", "Loading"}
LOADING_TITLE2 :: Tr{"Carregando.", "Loading."}
LOADING_TITLE3 :: Tr{"Carregando..", "Loading.."}
LOADING_TITLE4 :: Tr{"Carregando...", "Loading..."}

MENU_OPTION_MAX :: 3
MENU_LIMITE_VOLTA :: 3

Menu :: struct {
	// 0 = "novo jogo", 1 = "creditos", 2 = "idioma", 3 = "sair".
	option_atual:   i32,
	w, s, enter:    bool,
	state_inicio:   bool,
	state_creditos: bool,
	state_jogo:     bool,
	state_loading:  bool,
	time, volta:    i32,
}

menu_new :: proc() -> Menu {
	return Menu{state_inicio = true}
}

menu_tick :: proc(m: ^Menu, g: ^Game) {
	if m.state_inicio {
		if m.w {
			sound_play(&g.sounds, .Menu)
			m.w = false
			m.option_atual -= 1
			if m.option_atual < 0 {
				m.option_atual = MENU_OPTION_MAX
			}
		}

		if m.s {
			sound_play(&g.sounds, .Menu)
			m.s = false
			m.option_atual += 1
			if m.option_atual > MENU_OPTION_MAX {
				m.option_atual = 0
			}
		}

		if m.enter {
			sound_play(&g.sounds, .Select)
			m.enter = false

			if m.option_atual == 3 {
				g.quit = true
			} else if m.option_atual == 2 {
				// Troca o idioma; o menu continua aberto, ja no outro idioma.
				set_lang(g, Lang.En if g.lang == .Pt else Lang.Pt)
			} else if m.option_atual == 1 {
				m.state_loading = false
				m.state_inicio = false
				m.state_jogo = false
				m.state_creditos = true
			} else if m.option_atual == 0 {
				m.state_loading = true
				m.state_inicio = false
				m.state_jogo = false
				m.state_creditos = false
			}
		}
	} else if m.state_creditos {
		if m.enter {
			sound_play(&g.sounds, .Select)
			m.enter = false

			m.state_loading = false
			m.state_inicio = true
			m.state_jogo = false
			m.state_creditos = false
		}
	}
}

menu_render :: proc(m: ^Menu, g: ^Game) {
	cx :: WIDTHFM / 2
	cy :: HEIGHTFM / 2

	if m.state_inicio {
		draw_screen(screen(g, .Menu))

		tam1 := text_width(&g.text, tr(g, TXTMENU1), .S40)
		text_draw(&g.text, tr(g, TXTMENU1), .S40, cx - tam1 / 2, cy - 50, BLACK)
		tam2 := text_width(&g.text, tr(g, TXTMENU2), .S40)
		text_draw(&g.text, tr(g, TXTMENU2), .S40, cx - tam2 / 2, cy, BLACK)
		tam4 := text_width(&g.text, tr(g, TXTIDIOMA), .S40)
		text_draw(&g.text, tr(g, TXTIDIOMA), .S40, cx - tam4 / 2, cy + 50, BLACK)
		tam3 := text_width(&g.text, tr(g, TXTMENU3), .S40)
		text_draw(&g.text, tr(g, TXTMENU3), .S40, cx - tam3 / 2, cy + 100, BLACK)

		switch m.option_atual {
		case 0: text_draw(&g.text, ">", .S40, cx - tam1 / 2 - 50, cy - 50, BLACK)
		case 1: text_draw(&g.text, ">", .S40, cx - tam2 / 2 - 50, cy, BLACK)
		case 2: text_draw(&g.text, ">", .S40, cx - tam4 / 2 - 50, cy + 50, BLACK)
		case 3: text_draw(&g.text, ">", .S40, cx - tam3 / 2 - 50, cy + 100, BLACK)
		}
	} else if m.state_creditos {
		draw_screen(screen(g, .Creditos))

		tam3 := text_width(&g.text, tr(g, TXTCRED1), .S40)
		text_draw(&g.text, tr(g, TXTCRED1), .S40, cx - tam3 / 2, cy + 150, BLACK)
		text_draw(&g.text, ">", .S40, cx - tam3 / 2 - 50, cy + 150, BLACK)
	} else if m.state_loading {
		m.time += 1
		fill_screen(BLUE)
		if m.volta < MENU_LIMITE_VOLTA {
			// Cada titulo fica 24 quadros; os quadros 25, 50, 75 e 100 ficam so azuis.
			title := ""
			if m.time < 25 {
				title = tr(g, LOADING_TITLE1)
			} else if m.time > 25 && m.time < 50 {
				title = tr(g, LOADING_TITLE2)
			} else if m.time > 50 && m.time < 75 {
				title = tr(g, LOADING_TITLE3)
			} else if m.time > 75 && m.time < 100 {
				title = tr(g, LOADING_TITLE4)
			} else if m.time > 100 {
				m.time = 0
				m.volta += 1
			}

			if title != "" {
				tam := text_width(&g.text, title, .S50)
				text_draw(&g.text, title, .S50, cx - tam / 2, HEIGHTFM - 50, BLACK)
			}
		} else {
			m.state_loading = false
			m.state_jogo = true
		}
	}
}
