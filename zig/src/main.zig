//! Vacina — versao em Zig do jogo Java (`java/src/Main/Game.java`).
//!
//! Janela 960x640 ("Vacina"), 60 atualizacoes por segundo: a cada quadro le
//! o teclado, executa `tick` e depois `render`, como o loop do Java.

const std = @import("std");
const rl = @import("raylib");
const Game = @import("game.zig").Game;

pub fn main(init: std.process.Init) !void {
    rl.SetTraceLogLevel(rl.LOG_WARNING);
    rl.InitWindow(Game.widthfm, Game.heightfm, "Vacina");
    defer rl.CloseWindow();
    // Esc pausa o jogo; nao deve fechar a janela.
    rl.SetExitKey(rl.KEY_NULL);
    rl.SetTargetFPS(60);

    rl.InitAudioDevice();
    defer rl.CloseAudioDevice();

    var game: Game = undefined;
    try game.init(init.gpa);
    defer game.deinit();

    var frames: u32 = 0;
    var timer = rl.GetTime();
    while (!rl.WindowShouldClose()) {
        game.handleInput();
        try game.tick();
        if (game.quit) break;
        game.render();
        frames += 1;

        if (rl.GetTime() - timer >= 1) {
            std.debug.print("FPS: {d}\n", .{frames});
            frames = 0;
            timer += 1;
        }
    }
}
