package main

import rl "vendor:raylib"

// `Main.Sound`: efeitos sonoros.
Sound_Id :: enum u8 {
	Menu,    // res/Menu.wav
	Select,  // res/Select.wav
	Menino,  // res/Menino.wav
	Monstro, // res/Monstro.wav
}

// O Java abre um `Clip` novo a cada `Sound.play`, entao o mesmo som pode tocar
// sobreposto. Aqui cada som tem `VOICES` vozes (aliases do raylib) usadas em
// rodizio: tocar de novo uma voz ocupada a reinicia.
VOICES :: 4

Sounds :: struct {
	// Sem dispositivo de audio o jogo roda mudo, como o "play sound error" do Java.
	ready:  bool,
	voices: [Sound_Id][VOICES]rl.Sound,
	next:   [Sound_Id]int,
}

sounds_load :: proc(s: ^Sounds) {
	rl.InitAudioDevice()
	if !rl.IsAudioDeviceReady() {
		return
	}
	for id in Sound_Id {
		data := sound_wav(id)
		wave := rl.LoadWaveFromMemory(".wav", raw_data(data), i32(len(data)))
		source := rl.LoadSoundFromWave(wave)
		rl.UnloadWave(wave)
		s.voices[id][0] = source
		for v in 1 ..< VOICES {
			s.voices[id][v] = rl.LoadSoundAlias(source)
		}
	}
	s.ready = true
}

sounds_unload :: proc(s: ^Sounds) {
	if !s.ready {
		return
	}
	for id in Sound_Id {
		for v in 1 ..< VOICES {
			rl.UnloadSoundAlias(s.voices[id][v])
		}
		rl.UnloadSound(s.voices[id][0])
	}
	rl.CloseAudioDevice()
	s.ready = false
}

// `Sound.play`: toca o som desde o comeco, sem interromper os que ja tocam.
sound_play :: proc(s: ^Sounds, id: Sound_Id) {
	if !s.ready {
		return
	}
	rl.PlaySound(s.voices[id][s.next[id]])
	s.next[id] = (s.next[id] + 1) % VOICES
}
