package tests

import "core:testing"
import "../keys"

@(private = "file")
expect_events :: proc(t: ^testing.T, got: keys.Events, expected: []keys.Event, loc := #caller_location) {
	got := got
	events := keys.event_slice(&got)
	if !testing.expectf(t, len(events) == len(expected), "%d eventos, esperados %d: %v", len(events), len(expected), events, loc = loc) {
		return
	}
	for e, i in events {
		testing.expectf(t, e == expected[i], "evento %d: %v, esperado %v", i, e, expected[i], loc = loc)
	}
}

@(test)
aperto_repeticao_e_soltura_na_ordem :: proc(t: ^testing.T) {
	tracker: keys.Tracker
	expect_events(t, keys.update(&tracker, {pressed = {.D, .W}, down = {.D, .W}}), {{.D, .Press}, {.W, .Press}})
	// D segurado: so a repeticao; W solto.
	expect_events(t, keys.update(&tracker, {repeated = {.D}, down = {.D}}), {{.D, .Repeat}, {.W, .Release}})
	expect_events(t, keys.update(&tracker, {down = {.D}}), {})
	expect_events(t, keys.update(&tracker, {}), {{.D, .Release}})
}

@(test)
esc_e_enter_nao_repetem :: proc(t: ^testing.T) {
	tracker: keys.Tracker
	expect_events(t, keys.update(&tracker, {pressed = {.Enter}, down = {.Enter}}), {{.Enter, .Press}})
	expect_events(t, keys.update(&tracker, {repeated = {.Enter, .Escape}, down = {.Enter}}), {})
	testing.expect(t, keys.repeats_when_held(.S))
	testing.expect(t, !keys.repeats_when_held(.Escape))
}

@(test)
toque_rapido_gera_aperto_e_soltura :: proc(t: ^testing.T) {
	tracker: keys.Tracker
	// Apertou e soltou entre dois quadros (como o `xdotool key`).
	expect_events(t, keys.update(&tracker, {pressed = {.Enter}}), {{.Enter, .Press}, {.Enter, .Release}})
	testing.expect_value(t, tracker.held, keys.Key_Set{})
}

@(test)
soltar_e_apertar_de_novo_no_mesmo_quadro :: proc(t: ^testing.T) {
	tracker: keys.Tracker
	expect_events(t, keys.update(&tracker, {pressed = {.A}, down = {.A}}), {{.A, .Press}})
	expect_events(t, keys.update(&tracker, {pressed = {.A}, down = {.A}}), {{.A, .Release}, {.A, .Press}})
}

@(test)
aperto_perdido_chega_na_repeticao :: proc(t: ^testing.T) {
	tracker: keys.Tracker
	expect_events(t, keys.update(&tracker, {repeated = {.Enter}, down = {.Enter}}), {{.Enter, .Press}})
	expect_events(t, keys.update(&tracker, {repeated = {.Enter}, down = {.Enter}}), {})
}

@(test)
perder_o_foco_solta_as_teclas :: proc(t: ^testing.T) {
	tracker: keys.Tracker
	expect_events(t, keys.update(&tracker, {pressed = {.A, .S}, down = {.A, .S}}), {{.A, .Press}, {.S, .Press}})
	// Sem foco o sistema informa todas as teclas como soltas.
	expect_events(t, keys.update(&tracker, {}), {{.A, .Release}, {.S, .Release}})
}
