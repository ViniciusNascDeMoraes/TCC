//! Audio do jogo: o mixer e a thread que entrega o som ao sistema.
//!
//! Cada sistema tem seu backend, sem bibliotecas: o protocolo do PulseAudio
//! (e do PipeWire) no Linux e o waveOut no Windows. Se o sistema nao tiver
//! audio, a thread termina e os sons simplesmente nao tocam, como o
//! "play sound error" do Java.

const std = @import("std");
const builtin = @import("builtin");
const wav = @import("wav.zig");
const Mixer = @import("mixer.zig").Mixer;

const backend = switch (builtin.os.tag) {
    .linux => @import("audio/pulse.zig"),
    .windows => @import("audio/winmm.zig"),
    else => @compileError("sistema nao suportado: so Linux (PulseAudio) e Windows (waveOut)"),
};

const log = std.log.scoped(.audio);

pub const Audio = struct {
    mixer: Mixer,
    config: backend.Config,
    running: std.atomic.Value(bool) = .init(true),
    thread: ?std.Thread = null,

    /// Comeca a tocar; `self` precisa ficar no mesmo endereco ate `stop`.
    pub fn start(self: *Audio, gpa: std.mem.Allocator, io: std.Io, env: *const std.process.Environ.Map, sounds: []const wav.Pcm) void {
        self.* = .{ .mixer = .init(sounds), .config = backend.prepare(gpa, io, env) };
        self.thread = std.Thread.spawn(.{}, backend.run, .{ &self.config, &self.mixer, &self.running }) catch |err| blk: {
            log.warn("sem thread de audio: {s}", .{@errorName(err)});
            break :blk null;
        };
    }

    pub fn stop(self: *Audio) void {
        self.running.store(false, .release);
        if (self.thread) |thread| thread.join();
        self.thread = null;
    }
};
