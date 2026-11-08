package main

// Imagens, mapas e sons embutidos no executavel com `#load`, para ele rodar de
// qualquer pasta. `res/` tem copias so dos arquivos que o jogo usa.

SPRITESHEET_PNG :: #load("../res/Spritesheet.png")
GAME_OVER_PNG   :: #load("../res/GameOver.png")

LEVEL1_PNG :: #load("../res/level1.png")
LEVEL2_PNG :: #load("../res/level2.png")
LEVEL3_PNG :: #load("../res/level3.png")

MENU_WAV    :: #load("../res/Menu.wav")
SELECT_WAV  :: #load("../res/Select.wav")
MENINO_WAV  :: #load("../res/Menino.wav")
MONSTRO_WAV :: #load("../res/Monstro.wav")

// Telas com texto desenhado na imagem: a versao em portugues (`Nome.png`) e a
// em ingles (`Nome_en.png`).
TELA_MENU_PNG        :: #load("../res/TelaMenu.png")
TELA_MENU_EN_PNG     :: #load("../res/TelaMenu_en.png")
TELA_CREDITOS_PNG    :: #load("../res/TelaCreditos.png")
TELA_CREDITOS_EN_PNG :: #load("../res/TelaCreditos_en.png")
TELA_FIM_PNG         :: #load("../res/TelaFim.png")
TELA_FIM_EN_PNG      :: #load("../res/TelaFim_en.png")
TELA_VACINA_PNG      :: #load("../res/TelaVacina.png")
TELA_VACINA_EN_PNG   :: #load("../res/TelaVacina_en.png")
VACINANDO_PNG        :: #load("../res/Vacinando.png")
VACINANDO_EN_PNG     :: #load("../res/Vacinando_en.png")
VACINANDO1_PNG       :: #load("../res/Vacinando1.png")
VACINANDO1_EN_PNG    :: #load("../res/Vacinando1_en.png")
VACINANDO2_PNG       :: #load("../res/Vacinando2.png")
VACINANDO2_EN_PNG    :: #load("../res/Vacinando2_en.png")
VACINANDO3_PNG       :: #load("../res/Vacinando3.png")
VACINANDO3_EN_PNG    :: #load("../res/Vacinando3_en.png")

level_png :: proc(level: i32) -> []u8 {
	switch level {
	case 2: return LEVEL2_PNG
	case 3: return LEVEL3_PNG
	}
	return LEVEL1_PNG
}

screen_png :: proc(lang: Lang, screen: Screen) -> []u8 {
	if lang == .En {
		switch screen {
		case .Menu:        return TELA_MENU_EN_PNG
		case .Creditos:    return TELA_CREDITOS_EN_PNG
		case .Imagem_Fim:  return TELA_FIM_EN_PNG
		case .Tela_Vacina: return TELA_VACINA_EN_PNG
		case .Vacinando:   return VACINANDO_EN_PNG
		case .Vacinando1:  return VACINANDO1_EN_PNG
		case .Vacinando2:  return VACINANDO2_EN_PNG
		case .Vacinando3:  return VACINANDO3_EN_PNG
		}
	}
	switch screen {
	case .Menu:        return TELA_MENU_PNG
	case .Creditos:    return TELA_CREDITOS_PNG
	case .Imagem_Fim:  return TELA_FIM_PNG
	case .Tela_Vacina: return TELA_VACINA_PNG
	case .Vacinando:   return VACINANDO_PNG
	case .Vacinando1:  return VACINANDO1_PNG
	case .Vacinando2:  return VACINANDO2_PNG
	case .Vacinando3:  return VACINANDO3_PNG
	}
	return nil
}

sound_wav :: proc(id: Sound_Id) -> []u8 {
	switch id {
	case .Menu:    return MENU_WAV
	case .Select:  return SELECT_WAV
	case .Menino:  return MENINO_WAV
	case .Monstro: return MONSTRO_WAV
	}
	return nil
}
