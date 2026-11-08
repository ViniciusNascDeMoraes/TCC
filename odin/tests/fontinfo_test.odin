package tests

import "core:log"
import "core:os"
import "core:testing"
import "../fontinfo"

@(test)
caracteres_sem_glifo_viram_interrogacao :: proc(t: ^testing.T) {
	testing.expect_value(t, fontinfo.slot('A'), 'A')
	testing.expect_value(t, fontinfo.slot('é'), 'é')
	testing.expect_value(t, fontinfo.slot('€'), '?')
	testing.expect_value(t, fontinfo.slot('\n'), '?')

	adv: fontinfo.Advances
	adv['A'] = 10
	adv['?'] = 7
	adv['é'] = 3
	testing.expect_value(t, fontinfo.text_width(&adv, "AéA"), 23)
	testing.expect_value(t, fontinfo.text_width(&adv, "A€"), 17)
}

@(test)
fonte_invalida :: proc(t: ^testing.T) {
	_, err := fontinfo.parse({})
	testing.expect_value(t, err, fontinfo.Error.Malformed)
	ttc := [12]u8{'t', 't', 'c', 'f', 0, 1, 0, 0, 0, 0, 0, 1}
	_, err = fontinfo.parse(ttc[:])
	testing.expect_value(t, err, fontinfo.Error.Unsupported)
}

@(private = "file")
Font_Case :: struct {
	path:   string,
	widths: [4]i32,
	// `pixel_height` e `raylib_ascent` para 20, 23, 30, 40 e 50 pixels.
	heights: [5]i32,
	ascents: [5]i32,
}

// Mesmas larguras que o port em Zig calcula (zig/src/glyphs.zig).
@(test)
larguras_das_fontes_do_sistema_seguem_o_hmtx :: proc(t: ^testing.T) {
	cases := [?]Font_Case {
		{
			path = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
			widths = {224, 189, 388, 260},
			heights = {23, 27, 35, 47, 58},
			ascents = {18, 21, 27, 37, 46},
		},
		{
			path = "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
			widths = {193, 161, 324, 218},
			heights = {22, 26, 34, 45, 56},
			ascents = {17, 21, 27, 36, 45},
		},
	}
	sizes := [5]i32{20, 23, 30, 40, 50}
	found := false
	for c in cases {
		data, err := os.read_entire_file(c.path, context.allocator)
		if err != nil {
			continue
		}
		defer delete(data)
		found = true

		font, perr := fontinfo.parse(data)
		if !testing.expect_value(t, perr, fontinfo.Error.None) {
			continue
		}
		s40 := fontinfo.advances(&font, 40)
		s50 := fontinfo.advances(&font, 50)
		s20 := fontinfo.advances(&font, 20)
		testing.expect_value(t, fontinfo.text_width(&s40, "Novo jogo"), c.widths[0])
		testing.expect_value(t, fontinfo.text_width(&s40, "Créditos"), c.widths[1])
		testing.expect_value(t, fontinfo.text_width(&s50, "Carregando..."), c.widths[2])
		testing.expect_value(t, fontinfo.text_width(&s20, "Vá para a área amarela"), c.widths[3])

		for size, i in sizes {
			height := fontinfo.pixel_height(&font, size)
			testing.expect_value(t, height, c.heights[i])
			testing.expect_value(t, fontinfo.raylib_ascent(&font, height), c.ascents[i])
		}
		testing.expect(t, fontinfo.glyph_index(&font, 'ã') != 0)
		testing.expect_value(t, fontinfo.glyph_index(&font, 0x10FFFF), 0)
	}
	if !found {
		log.info("nenhuma fonte de teste instalada (DejaVu Sans / Liberation Sans): teste pulado")
	}
}
