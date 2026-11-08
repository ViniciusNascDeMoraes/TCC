// Teclado: transforma o que o sistema informa a cada quadro nos eventos do
// `KeyListener` do Java (`keyPressed`/`keyReleased`), na ordem certa.
// Puro, sem chamadas ao sistema; o raylib so preenche um `Frame_Input`.
package keys

// Teclas que o jogo usa. O Enter do teclado numerico tambem e `.Enter`, como o
// `KeyEvent.VK_ENTER` do Java.
Key :: enum u8 {
	W,
	A,
	S,
	D,
	Enter,
	Escape,
}

Key_Set :: bit_set[Key]

Action :: enum u8 {
	Press,   // tecla apertada (`keyPressed`)
	Repeat,  // repeticao automatica com a tecla segurada (`keyPressed` de novo)
	Release, // tecla solta (`keyReleased`)
}

Event :: struct {
	key:    Key,
	action: Action,
}

// Esc e Enter so contam quando apertados de novo: segurar a tecla nao repete
// a acao (no Java, as flags `escPressionado`/`enterPressionado`).
repeats_when_held :: proc(key: Key) -> bool {
	return key != .Escape && key != .Enter
}

// O que o sistema informou desde o quadro anterior.
Frame_Input :: struct {
	pressed:  []Key,   // apertos, na ordem em que aconteceram
	repeated: Key_Set, // teclas com repeticao automatica neste quadro
	down:     Key_Set, // teclas apertadas agora
}

// Estado entre quadros: as teclas que o jogo considera apertadas.
Tracker :: struct {
	held: Key_Set,
}

MAX_EVENTS :: 64

// Eventos de um quadro, na ordem em que devem chegar ao jogo.
Events :: struct {
	items: [MAX_EVENTS]Event,
	count: int,
}

@(private)
push :: proc(events: ^Events, key: Key, action: Action) {
	if events.count < MAX_EVENTS {
		events.items[events.count] = Event{key, action}
		events.count += 1
	}
}

// Gera os eventos do quadro: primeiro os apertos, depois as repeticoes (so das
// teclas que repetem) e por ultimo as solturas. Uma tecla apertada e solta no
// mesmo quadro gera os dois eventos; uma tecla perdida pelo sistema (aperto que
// nao chegou) entra no jogo na primeira repeticao.
update :: proc(tracker: ^Tracker, input: Frame_Input) -> Events {
	events: Events
	pressed: Key_Set

	for key in input.pressed {
		if key in tracker.held {
			// Soltou e apertou de novo desde o quadro anterior.
			push(&events, key, .Release)
		}
		push(&events, key, .Press)
		tracker.held += {key}
		pressed += {key}
	}

	for key in Key {
		if key not_in input.repeated || key in pressed {
			continue
		}
		if key in tracker.held {
			if repeats_when_held(key) {
				push(&events, key, .Repeat)
			}
		} else if key in input.down {
			push(&events, key, .Press)
			tracker.held += {key}
		}
	}

	for key in Key {
		if key in tracker.held && key not_in input.down {
			push(&events, key, .Release)
			tracker.held -= {key}
		}
	}
	return events
}

// Os eventos como slice.
event_slice :: proc(events: ^Events) -> []Event {
	return events.items[:events.count]
}
