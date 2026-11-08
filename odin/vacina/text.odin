package main

import "core:fmt"
import "core:os"
import "core:strings"
import rl "vendor:raylib"
import "../fontinfo"

// Texto no estilo do `g.setFont(new Font("Bookman Old Style", Font.BOLD, n))`
// + `g.drawString` do Java.
//
// A Bookman Old Style nao pode ser distribuida junto com o jogo, entao ela e
// lida da pasta de fontes do sistema ou do usuario. Sem ela, tenta o clone
// livre URW Bookman (Linux), depois as fontes que o Java usaria no lugar
// (fonte logica "Dialog": Arial/DejaVu Sans/Liberation Sans) e, por ultimo, a
// fonte bitmap embutida no raylib.
//
// As larguras (e o centro dos menus) seguem o Java: vem das metricas da fonte
// (`fontinfo`); o raylib so rasteriza os glifos, com antialiasing.

// Tamanhos de fonte usados pelo jogo Java.
Text_Size :: enum u8 {
	S20,
	S23,
	S30,
	S40,
	S50,
}

text_points :: proc(size: Text_Size) -> i32 {
	switch size {
	case .S20: return 20
	case .S23: return 23
	case .S30: return 30
	case .S40: return 40
	case .S50: return 50
	}
	return 0
}

// Uma fonte procurada pelos nomes de arquivo nas pastas de fontes do usuario
// (e do Windows/macOS) e em pastas fixas do sistema.
@(private = "file")
Candidate :: struct {
	files:       []string,
	system_dirs: []string,
}

@(private = "file")
CANDIDATES := [?]Candidate {
	// Bookman Old Style Bold (Windows / Office, ou copiada para as fontes do usuario).
	{files = {"BOOKOSB.TTF", "bookosb.ttf"}},
	// Clone livre da Bookman (pacotes fonts-urw-base35 / urw-base35-fonts / gsfonts).
	{
		files = {"URWBookman-Demi.otf"},
		system_dirs = {"/usr/share/fonts/opentype/urw-base35", "/usr/share/fonts/urw-base35", "/usr/share/fonts/gsfonts"},
	},
	// "Dialog" negrito, a fonte que o Java usa quando a Bookman nao existe.
	{files = {"arialbd.ttf", "Arial Bold.ttf"}},
	{
		files = {"DejaVuSans-Bold.ttf"},
		system_dirs = {"/usr/share/fonts/truetype/dejavu", "/usr/share/fonts/TTF", "/usr/share/fonts/dejavu-sans-fonts"},
	},
	{
		files = {"LiberationSans-Bold.ttf"},
		system_dirs = {"/usr/share/fonts/truetype/liberation", "/usr/share/fonts/liberation-sans"},
	},
}

// Letras que a fonte precisa desenhar para ser usada (os textos do jogo usam
// estes acentos); uma fonte sem elas, ou com glifos que o raylib nao
// rasteriza, e ignorada.
@(private = "file")
REQUIRED :: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789áâãàéêíóôõúç"

// Glifos de uma fonte num tamanho.
Glyph_Set :: struct {
	font:     rl.Font, // atlas do raylib com os glifos
	ascent:   i32, // do topo dos glifos do raylib ate a linha de base
	scale:    i32, // ampliacao inteira dos glifos (so na fonte bitmap)
	advances: fontinfo.Advances,
	index:    [256]i32, // posicao do glifo em `font.glyphs` (-1 = sem glifo)
}

Text :: struct {
	sets:  [Text_Size]Glyph_Set,
	owned: bool, // as fontes foram carregadas (a fonte bitmap e do raylib)
}

// Pastas de fontes do usuario (e do Windows/macOS), conforme o ambiente.
@(private = "file")
user_font_dirs :: proc(allocator := context.temp_allocator) -> [dynamic]string {
	dirs := make([dynamic]string, allocator)
	when ODIN_OS == .Windows {
		windir, found := os.lookup_env("WINDIR", allocator)
		append(&dirs, strings.concatenate({windir if found else "C:/Windows", "/Fonts"}, allocator))
		if local, ok := os.lookup_env("LOCALAPPDATA", allocator); ok {
			append(&dirs, strings.concatenate({local, "/Microsoft/Windows/Fonts"}, allocator))
		}
	} else {
		home, has_home := os.lookup_env("HOME", allocator)
		when ODIN_OS == .Darwin {
			if has_home {
				append(&dirs, strings.concatenate({home, "/Library/Fonts"}, allocator))
			}
			append(&dirs, "/Library/Fonts", "/System/Library/Fonts/Supplemental")
		} else {
			if data, ok := os.lookup_env("XDG_DATA_HOME", allocator); ok {
				append(&dirs, strings.concatenate({data, "/fonts"}, allocator))
			} else if has_home {
				append(&dirs, strings.concatenate({home, "/.local/share/fonts"}, allocator))
			}
			if has_home {
				append(&dirs, strings.concatenate({home, "/.fonts"}, allocator))
			}
		}
	}
	return dirs
}

text_load :: proc() -> Text {
	dirs := user_font_dirs()
	for candidate in CANDIDATES {
		for file in candidate.files {
			for dir in dirs {
				if text, ok := try_font(dir, file); ok {
					return text
				}
			}
			for dir in candidate.system_dirs {
				if text, ok := try_font(dir, file); ok {
					return text
				}
			}
		}
	}
	fmt.eprintln("nenhuma fonte encontrada: usando a fonte bitmap do raylib")
	return text_from_default_font()
}

text_unload :: proc(text: ^Text) {
	if text.owned {
		for &set in text.sets {
			rl.UnloadFont(set.font)
		}
	}
	text^ = {}
}

// A fonte `dir/file` em todos os tamanhos, ou `ok = false` se ela nao existe
// ou nao serve.
@(private = "file")
try_font :: proc(dir, file: string) -> (text: Text, ok: bool) {
	path := strings.concatenate({dir, "/", file}, context.temp_allocator)
	data, err := os.read_entire_file(path, context.allocator)
	if err != nil {
		return {}, false
	}
	// O raylib rasteriza tudo agora; depois o arquivo nao e mais usado.
	defer delete(data)

	info, info_err := fontinfo.parse(data)
	if info_err != .None {
		fmt.eprintfln("fonte %s ignorada: %v", path, info_err)
		return {}, false
	}
	for size in Text_Size {
		set, set_ok := load_glyph_set(data, &info, text_points(size))
		if !set_ok {
			fmt.eprintfln("fonte %s ignorada: faltam glifos", path)
			for done in Text_Size {
				if done == size {
					break
				}
				rl.UnloadFont(text.sets[done].font)
			}
			return {}, false
		}
		text.sets[size] = set
	}
	text.owned = true
	return text, true
}

// Rasteriza os caracteres de `fontinfo.cached` com o "em" de `points` pixels.
@(private = "file")
load_glyph_set :: proc(data: []u8, info: ^fontinfo.Font, points: i32) -> (set: Glyph_Set, ok: bool) {
	codepoints: [256]rune
	count := 0
	for cp in 0 ..< 256 {
		if fontinfo.cached(rune(cp)) {
			codepoints[count] = rune(cp)
			count += 1
		}
	}

	height := fontinfo.pixel_height(info, points)
	font := rl.LoadFontFromMemory(".ttf", raw_data(data), i32(len(data)), height, raw_data(codepoints[:]), i32(count))
	// Se falha, o raylib devolve a fonte padrao dele (que `UnloadFont` ignora).
	if font.glyphs == nil || font.glyphCount == 0 || font.texture.id == 0 || font.texture.id == rl.GetFontDefault().texture.id {
		rl.UnloadFont(font)
		return {}, false
	}

	set.font = font
	set.ascent = fontinfo.raylib_ascent(info, height)
	set.scale = 1
	set.advances = fontinfo.advances(info, points)
	map_glyphs(&set)

	for r in REQUIRED {
		i := set.index[int(r)]
		if fontinfo.glyph_index(info, r) == 0 || i < 0 || rl.GetImageAlphaBorder(font.glyphs[i].image, 0).width <= 0 {
			rl.UnloadFont(font)
			return {}, false
		}
	}
	return set, true
}

// Preenche `set.index` com a posicao de cada caractere no atlas do raylib.
@(private = "file")
map_glyphs :: proc(set: ^Glyph_Set) {
	for &i in set.index {
		i = -1
	}
	for i in 0 ..< int(set.font.glyphCount) {
		value := int(set.font.glyphs[i].value)
		if value >= 0 && value < 256 {
			set.index[value] = i32(i)
		}
	}
}

// Fonte bitmap embutida no raylib, ampliada para cada tamanho (escala inteira).
@(private = "file")
text_from_default_font :: proc() -> Text {
	text: Text
	font := rl.GetFontDefault()
	for size in Text_Size {
		set := &text.sets[size]
		set.font = font
		set.scale = max(1, (text_points(size) + 5) / 10)
		set.ascent = 8 * set.scale
		map_glyphs(set)
		for cp in 0 ..< 256 {
			i := set.index[cp]
			if i < 0 {
				continue
			}
			advance := font.glyphs[i].advanceX
			if advance == 0 {
				advance = i32(font.recs[i].width)
			}
			// O raylib separa os caracteres desta fonte com 1 pixel.
			set.advances[cp] = (advance + 1) * set.scale
		}
	}
	return text
}

// `g.getFontMetrics().stringWidth(text)`.
text_width :: proc(text: ^Text, s: string, size: Text_Size) -> i32 {
	return fontinfo.text_width(&text.sets[size].advances, s)
}

// `g.drawString(s, x, y)`: `y` e a linha de base, como no Java.
text_draw :: proc(text: ^Text, s: string, size: Text_Size, x, y: i32, color: rl.Color) {
	set := &text.sets[size]
	pen := x
	top := y - set.ascent
	for r in s {
		cp := int(fontinfo.slot(r))
		i := set.index[cp]
		if i >= 0 {
			glyph := set.font.glyphs[i]
			source := set.font.recs[i]
			dest := rl.Rectangle {
				f32(pen + glyph.offsetX * set.scale),
				f32(top + glyph.offsetY * set.scale),
				source.width * f32(set.scale),
				source.height * f32(set.scale),
			}
			rl.DrawTexturePro(set.font.texture, source, dest, rl.Vector2{}, 0, color)
		}
		pen += set.advances[cp]
	}
}
