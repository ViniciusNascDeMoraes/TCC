package main

import rl "vendor:raylib"
import "../keys"

// Teclas do raylib que correspondem a cada tecla do jogo (o Enter do teclado
// numerico tambem conta como Enter).
@(private = "file")
raylib_keys :: proc(key: keys.Key) -> [2]rl.KeyboardKey {
	switch key {
	case .W:      return {.W, .KEY_NULL}
	case .A:      return {.A, .KEY_NULL}
	case .S:      return {.S, .KEY_NULL}
	case .D:      return {.D, .KEY_NULL}
	case .Enter:  return {.ENTER, .KP_ENTER}
	case .Escape: return {.ESCAPE, .KEY_NULL}
	}
	return {}
}

@(private = "file")
game_key :: proc(code: rl.KeyboardKey) -> (key: keys.Key, ok: bool) {
	for k in keys.Key {
		codes := raylib_keys(k)
		for c in codes {
			if c != .KEY_NULL && c == code {
				return k, true
			}
		}
	}
	return {}, false
}

// Le o teclado desde o quadro anterior e repassa os eventos ao jogo, na ordem
// do `KeyListener` do Java.
read_input :: proc(g: ^Game) {
	pressed: [32]keys.Key
	count := 0
	queued: keys.Key_Set

	// Apertos na ordem em que aconteceram.
	for {
		code := rl.GetKeyPressed()
		if code == .KEY_NULL {
			break
		}
		if key, ok := game_key(code); ok && count < len(pressed) {
			pressed[count] = key
			count += 1
			queued += {key}
		}
	}

	input: keys.Frame_Input
	for key in keys.Key {
		codes := raylib_keys(key)
		for code in codes {
			if code == .KEY_NULL {
				continue
			}
			if rl.IsKeyDown(code) {
				input.down += {key}
			}
			if rl.IsKeyPressedRepeat(code) {
				input.repeated += {key}
			}
			// Aperto que nao coube na fila do raylib.
			if rl.IsKeyPressed(code) && key not_in queued && count < len(pressed) {
				pressed[count] = key
				count += 1
				queued += {key}
			}
		}
	}
	input.pressed = pressed[:count]

	focused := rl.IsWindowFocused()
	if g.focused && !focused {
		focus_lost(g)
	}
	g.focused = focused

	events := keys.update(&g.key_tracker, input)
	handle_input(g, keys.event_slice(&events))
}
