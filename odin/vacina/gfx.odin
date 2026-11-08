package main

import rl "vendor:raylib"
import "../rules"

// Cores do `java.awt.Color` usadas pelo jogo.
WHITE :: rl.Color{255, 255, 255, 255}
BLACK :: rl.Color{0, 0, 0, 255}
// `Game.BLUE`.
BLUE :: rl.Color{9, 156, 147, 255}

// Decodifica um PNG embutido e o envia para a GPU.
load_texture :: proc(png: []u8) -> rl.Texture2D {
	image := rl.LoadImageFromMemory(".png", raw_data(png), i32(len(png)))
	defer rl.UnloadImage(image)
	return rl.LoadTextureFromImage(image)
}

// Imagem de tela inteira (960x640) desenhada na origem, como
// `g.drawImage(img, 0, 0, Game.widthfm, Game.heightfm, null)`.
draw_screen :: proc(texture: rl.Texture2D) {
	rl.DrawTexture(texture, 0, 0, rl.WHITE)
}

// `g.setColor(c); g.fillRect(0, 0, Game.widthfm, Game.heightfm)`.
fill_screen :: proc(color: rl.Color) {
	rl.DrawRectangle(0, 0, WIDTHFM, HEIGHTFM, color)
}

// `g.drawImage(spritesheet.getSprite(sx, sy, 16, 16), x, y, null)` na imagem
// 240x160 do mundo.
draw_sprite :: proc(g: ^Game, sprite: rules.Sprite_Pos, x, y: i32) {
	source := rl.Rectangle{f32(sprite.x), f32(sprite.y), rules.TILE_SIZE, rules.TILE_SIZE}
	rl.DrawTextureRec(g.spritesheet, source, rl.Vector2{f32(x), f32(y)}, rl.WHITE)
}
