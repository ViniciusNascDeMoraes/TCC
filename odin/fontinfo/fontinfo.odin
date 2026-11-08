// Metricas de fontes TrueType/OpenType (tabelas head, hhea, maxp, hmtx e cmap)
// e o layout de texto do `drawString`/`stringWidth` do Java: o "em" da fonte
// tem o tamanho pedido em pixels, o avanco de cada glifo e arredondado para
// pixels inteiros e nao ha kerning, como no Java sem metricas fracionarias.
//
// Os glifos em si sao desenhados pelo raylib; daqui saem as larguras e as
// conversoes de tamanho para ele. Puro, sem chamadas ao sistema.
package fontinfo

import "core:math"

Error :: enum u8 {
	None,
	Malformed,   // arquivo truncado ou com valores impossiveis
	Unsupported, // colecao (.ttc) ou fonte sem tabela Unicode
}

Font :: struct {
	units_per_em: i32,
	ascender:     i32, // hhea, em unidades da fonte
	descender:    i32, // hhea (negativo)
	num_glyphs:   u32,
	num_hmetrics: u32,
	hmtx:         []u8,
	cmap:         []u8, // subtabela Unicode escolhida (formato 4 ou 12)
	cmap_format:  u16,
}

@(private)
u16be :: proc(d: []u8, off: int) -> u16 {
	if off < 0 || off + 2 > len(d) {
		return 0
	}
	return u16(d[off]) << 8 | u16(d[off + 1])
}

@(private)
i16be :: proc(d: []u8, off: int) -> i16 {
	return cast(i16)u16be(d, off)
}

@(private)
u32be :: proc(d: []u8, off: int) -> u32 {
	if off < 0 || off + 4 > len(d) {
		return 0
	}
	return u32(d[off]) << 24 | u32(d[off + 1]) << 16 | u32(d[off + 2]) << 8 | u32(d[off + 3])
}

// Le as tabelas de `data`. A `Font` aponta para dentro de `data`, que precisa
// continuar existindo enquanto ela for usada.
parse :: proc(data: []u8) -> (font: Font, err: Error) {
	if len(data) < 12 {
		return {}, .Malformed
	}
	switch u32be(data, 0) {
	case 0x00010000, 0x74727565, 0x4F54544F: // TrueType, 'true' (Apple), 'OTTO' (CFF)
	case 0x74746366: // 'ttcf'
		return {}, .Unsupported
	case:
		return {}, .Malformed
	}

	num_tables := int(u16be(data, 4))
	if 12 + num_tables * 16 > len(data) {
		return {}, .Malformed
	}
	head, hhea, maxp, hmtx, cmap: []u8
	for i in 0 ..< num_tables {
		rec := 12 + i * 16
		offset := int(u32be(data, rec + 8))
		length := int(u32be(data, rec + 12))
		if offset + length > len(data) {
			return {}, .Malformed
		}
		table := data[offset:][:length]
		switch string(data[rec:][:4]) {
		case "head": head = table
		case "hhea": hhea = table
		case "maxp": maxp = table
		case "hmtx": hmtx = table
		case "cmap": cmap = table
		}
	}
	if len(head) < 54 || len(hhea) < 36 || len(maxp) < 6 || len(cmap) < 4 {
		return {}, .Malformed
	}

	font.units_per_em = i32(u16be(head, 18))
	font.ascender = i32(i16be(hhea, 4))
	font.descender = i32(i16be(hhea, 6))
	font.num_hmetrics = u32(u16be(hhea, 34))
	font.num_glyphs = u32(u16be(maxp, 4))
	font.hmtx = hmtx
	if font.units_per_em < 16 || font.units_per_em > 16384 || font.ascender <= font.descender {
		return {}, .Malformed
	}
	if font.num_hmetrics == 0 || len(hmtx) < int(font.num_hmetrics) * 4 {
		return {}, .Malformed
	}

	// Subtabela Unicode: de preferencia a de 32 bits (formato 12), senao a do
	// plano basico (formato 4).
	best, best_rank: int
	best_format: u16
	num_subtables := int(u16be(cmap, 2))
	if 4 + num_subtables * 8 > len(cmap) {
		return {}, .Malformed
	}
	for i in 0 ..< num_subtables {
		rec := 4 + i * 8
		platform := u16be(cmap, rec)
		encoding := u16be(cmap, rec + 2)
		offset := int(u32be(cmap, rec + 4))
		if offset + 4 > len(cmap) {
			continue
		}
		format := u16be(cmap, offset)
		unicode := platform == 0 || (platform == 3 && (encoding == 1 || encoding == 10))
		rank := 0
		if unicode && format == 12 {
			rank = 2
		} else if unicode && format == 4 {
			rank = 1
		}
		if rank > best_rank {
			best, best_rank, best_format = offset, rank, format
		}
	}
	if best_rank == 0 {
		return {}, .Unsupported
	}

	sub := cmap[best:]
	switch best_format {
	case 4:
		seg_x2 := int(u16be(sub, 6))
		if len(sub) < 16 || seg_x2 == 0 || seg_x2 % 2 != 0 || 16 + 4 * seg_x2 > len(sub) {
			return {}, .Malformed
		}
	case 12:
		groups := int(u32be(sub, 12))
		if len(sub) < 16 || 16 + 12 * groups > len(sub) {
			return {}, .Malformed
		}
	}
	font.cmap = sub
	font.cmap_format = best_format
	return font, .None
}

// Glifo de um caractere (0 = sem glifo, o ".notdef").
glyph_index :: proc(font: ^Font, r: rune) -> u32 {
	sub := font.cmap
	if r < 0 {
		return 0
	}
	c := u32(r)
	switch font.cmap_format {
	case 4:
		if c > 0xFFFF {
			return 0
		}
		seg_x2 := int(u16be(sub, 6))
		ends := 14
		starts := 16 + seg_x2
		deltas := starts + seg_x2
		ranges := deltas + seg_x2
		for i := 0; i < seg_x2; i += 2 {
			end := u32(u16be(sub, ends + i))
			if c > end {
				continue
			}
			start := u32(u16be(sub, starts + i))
			if c < start {
				return 0
			}
			delta := u32(u16be(sub, deltas + i))
			range_offset := int(u16be(sub, ranges + i))
			if range_offset == 0 {
				return (c + delta) & 0xFFFF
			}
			glyph := u32(u16be(sub, ranges + i + range_offset + 2 * int(c - start)))
			if glyph == 0 {
				return 0
			}
			return (glyph + delta) & 0xFFFF
		}
	case 12:
		groups := int(u32be(sub, 12))
		for i in 0 ..< groups {
			rec := 16 + i * 12
			start := u32be(sub, rec)
			end := u32be(sub, rec + 4)
			if c >= start && c <= end {
				return u32be(sub, rec + 8) + (c - start)
			}
		}
	}
	return 0
}

// Avanco horizontal de um glifo, em unidades da fonte.
advance :: proc(font: ^Font, glyph: u32) -> i32 {
	i := min(glyph, font.num_hmetrics - 1)
	return i32(u16be(font.hmtx, int(i) * 4))
}

// Caracteres com glifo pronto: ASCII imprimivel e Latin-1 (U+0020 a U+007E e
// U+00A0 a U+00FF), o que cobre os acentos do portugues.
cached :: proc(r: rune) -> bool {
	return (r >= 0x20 && r <= 0x7E) || (r >= 0xA0 && r <= 0xFF)
}

// Caractere desenhado no lugar de `r`: os que nao tem glifo pronto viram "?".
slot :: proc(r: rune) -> rune {
	return r if cached(r) else '?'
}

// Avanco em pixels de cada caractere de `cached`, indexado pelo codigo.
Advances :: [256]i32

// Avancos com o "em" de `points` pixels, arredondados para pixels inteiros.
advances :: proc(font: ^Font, points: i32) -> Advances {
	adv: Advances
	scale := f64(points) / f64(font.units_per_em)
	for cp in 0 ..< 256 {
		r := rune(cp)
		if !cached(r) {
			continue
		}
		units := advance(font, glyph_index(font, r))
		adv[cp] = i32(math.round(f64(units) * scale))
	}
	return adv
}

// `g.getFontMetrics().stringWidth(text)`.
text_width :: proc(adv: ^Advances, text: string) -> i32 {
	total: i32
	for r in text {
		total += adv[int(slot(r))]
	}
	return total
}

// Tamanho a pedir ao raylib (`LoadFontEx`) para o "em" ter `points` pixels:
// o raylib usa o `stbtt_ScaleForPixelHeight`, que mede da linha mais alta a
// mais baixa da fonte (ascender - descender), e nao o "em" como o Java.
pixel_height :: proc(font: ^Font, points: i32) -> i32 {
	return i32(math.round(f64(points) * f64(font.ascender - font.descender) / f64(font.units_per_em)))
}

// Distancia do topo dos glifos do raylib ate a linha de base, calculada como
// o raylib faz (`(int)(ascent * scaleFactor)` em float).
raylib_ascent :: proc(font: ^Font, height: i32) -> i32 {
	scale := f32(height) / f32(font.ascender - font.descender)
	return i32(f32(font.ascender) * scale)
}
