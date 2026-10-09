//! Vacina — versao em Zig do jogo Java (`java/src/Main/Game.java`).
//!
//! Janela 960x640 ("Vacina"), 60 atualizacoes por segundo: a cada quadro le
//! o teclado, executa `tick` e depois `render`, como o loop do Java.

const std = @import("std");
const builtin = @import("builtin");
const platform = @import("platform.zig");
const sound = @import("sound.zig");
const Audio = @import("audio.zig").Audio;
const Game = @import("game.zig").Game;

const frame_ns = std.time.ns_per_s / 60;

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var window: platform.Window = undefined;
    try window.open(init.gpa, io, init.environ_map, "Vacina", Game.widthfm, Game.heightfm);
    defer window.close();

    var audio: Audio = undefined;
    audio.start(init.gpa, io, init.environ_map, &sound.pcm);
    defer audio.stop();

    var game: Game = undefined;
    try game.init(init.gpa, io, init.environ_map, &audio.mixer);
    defer game.deinit();

    var pacer: Pacer = .init(io);
    var frames: u32 = 0;
    var timer = now(io);
    while (true) {
        const events = window.poll();
        if (window.close_requested) break;
        game.handleInput(events);
        try game.tick();
        if (game.quit) break;
        game.render();
        window.present(game.frame);
        frames += 1;

        if (now(io) - timer >= std.time.ns_per_s) {
            std.debug.print("FPS: {d}\n", .{frames});
            frames = 0;
            timer += std.time.ns_per_s;
        }
        pacer.wait();
    }
}

fn now(io: std.Io) i96 {
    return std.Io.Timestamp.now(io, .awake).nanoseconds;
}

/// Espera ate o inicio do proximo quadro, com prazos fixos de 1/60 s (sem
/// acumular atraso). Se o jogo ficou parado (ex.: janela sendo arrastada no
/// Windows), recomeca a contagem em vez de correr para alcancar.
const Pacer = struct {
    io: std.Io,
    next: i96,

    fn init(io: std.Io) Pacer {
        return .{ .io = io, .next = now(io) };
    }

    fn wait(self: *Pacer) void {
        self.next += frame_ns;
        const remaining = self.next - now(self.io);
        if (remaining <= 0) {
            if (remaining < -frame_ns) self.next = now(self.io);
            return;
        }
        // No Windows o sleep e menos preciso: dorme um pouco menos e completa
        // o tempo cedendo a CPU, como o raylib faz.
        const margin: i96 = if (builtin.os.tag == .windows) 2 * std.time.ns_per_ms else 0;
        if (remaining > margin) {
            self.io.sleep(.fromNanoseconds(remaining - margin), .awake) catch {};
        }
        while (now(self.io) < self.next) std.Thread.yield() catch {};
    }
};
