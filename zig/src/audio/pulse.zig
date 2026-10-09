//! Saida de audio no Linux pelo protocolo nativo do PulseAudio, direto no
//! socket Unix (sem libpulse). Funciona com o PulseAudio e com o PipeWire
//! (pipewire-pulse). Sem servidor de audio, o jogo fica mudo.
//!
//! Tudo roda na thread de audio: conecta, autentica, cria um stream de
//! reproducao e, a cada pedido (REQUEST) do servidor, mistura e envia os
//! bytes pedidos. O servidor marca o ritmo; a thread so espera pacotes.

const std = @import("std");
const linux = std.os.linux;
const linux_sys = @import("../linux_sys.zig");
const proto = @import("pulse_proto.zig");
const wav = @import("../wav.zig");
const Mixer = @import("../mixer.zig").Mixer;

const log = std.log.scoped(.audio);

const Error = error{ Stopped, NoServer, BadPacket, ServerError, OutOfMemory } || linux_sys.Error;

/// 40 ms de buffer no servidor: a latencia dos efeitos sonoros.
const target_latency = wav.sample_rate * wav.bytes_per_frame * 40 / 1000;

/// O que a thread de audio precisa, preparado na thread principal (que tem
/// acesso as variaveis de ambiente e aos arquivos).
pub const Config = struct {
    paths: [4][108]u8 = undefined,
    path_lens: [4]usize = undefined,
    count: usize = 0,
    cookie: [proto.cookie_len]u8 = @splat(0),

    fn add(self: *Config, comptime fmt: []const u8, args: anytype) void {
        if (self.count == self.paths.len) return;
        const written = std.fmt.bufPrint(&self.paths[self.count], fmt, args) catch return;
        self.path_lens[self.count] = written.len;
        self.count += 1;
    }

    fn path(self: *const Config, i: usize) []const u8 {
        return self.paths[i][0..self.path_lens[i]];
    }
};

pub fn prepare(gpa: std.mem.Allocator, io: std.Io, env: *const std.process.Environ.Map) Config {
    var config: Config = .{};

    // $PULSE_SERVER: lista separada por espacos, como "unix:/caminho" ou
    // "{id-da-maquina}unix:/caminho"; enderecos TCP sao ignorados.
    if (env.get("PULSE_SERVER")) |servers| {
        var it = std.mem.tokenizeAny(u8, servers, " \t");
        while (it.next()) |entry| {
            var server = entry;
            if (server.len > 0 and server[0] == '{') {
                const close = std.mem.indexOfScalar(u8, server, '}') orelse continue;
                server = server[close + 1 ..];
            }
            if (std.mem.startsWith(u8, server, "unix:")) server = server[5..];
            if (server.len > 0 and server[0] == '/') config.add("{s}", .{server});
        }
    }
    if (env.get("PULSE_RUNTIME_PATH")) |dir| config.add("{s}/native", .{dir});
    if (env.get("XDG_RUNTIME_DIR")) |dir| config.add("{s}/pulse/native", .{dir});
    config.add("/run/user/{d}/pulse/native", .{linux.getuid()});

    // Cookie de autenticacao; o PipeWire o ignora e o PulseAudio tambem
    // aceita as credenciais do processo (mesmo usuario).
    var buf: [4096]u8 = undefined;
    const candidates = [_]?[]const u8{
        env.get("PULSE_COOKIE"),
        if (env.get("XDG_CONFIG_HOME")) |dir| std.fmt.bufPrint(buf[0..1024], "{s}/pulse/cookie", .{dir}) catch null else null,
        if (env.get("HOME")) |home| std.fmt.bufPrint(buf[1024..2048], "{s}/.config/pulse/cookie", .{home}) catch null else null,
        if (env.get("HOME")) |home| std.fmt.bufPrint(buf[2048..3072], "{s}/.pulse-cookie", .{home}) catch null else null,
    };
    for (candidates) |candidate| {
        const p = candidate orelse continue;
        const data = std.Io.Dir.cwd().readFileAlloc(io, p, gpa, .limited(4096)) catch continue;
        defer gpa.free(data);
        if (data.len < proto.cookie_len) continue;
        @memcpy(&config.cookie, data[0..proto.cookie_len]);
        break;
    }
    return config;
}

/// Corpo da thread de audio: termina quando `running` vira falso ou a
/// conexao cai.
pub fn run(config: *const Config, mixer: *Mixer, running: *const std.atomic.Value(bool)) void {
    var conn: Connection = .{ .running = running };
    conn.play(config, mixer) catch |err| switch (err) {
        error.Stopped => {},
        error.NoServer => log.warn("sem servidor PulseAudio/PipeWire: o jogo fica sem som", .{}),
        else => log.warn("audio interrompido: {s}", .{@errorName(err)}),
    };
    if (conn.fd >= 0) linux_sys.close(conn.fd);
}

const Connection = struct {
    fd: i32 = -1,
    running: *const std.atomic.Value(bool),
    channel: u32 = 0,
    /// Bytes de audio que o servidor pediu e ainda nao foram enviados.
    requested: usize = 0,
    payload: [4096]u8 = undefined,

    fn play(self: *Connection, config: *const Config, mixer: *Mixer) Error!void {
        for (0..config.count) |i| {
            self.fd = linux_sys.connectUnix(config.path(i), false) catch continue;
            break;
        } else return error.NoServer;

        var buf: [4096]u8 = undefined;
        var fba: std.heap.FixedBufferAllocator = .init(&buf);
        var w: proto.Writer = .{ .gpa = fba.allocator() };

        try proto.auth(&w, 0, &config.cookie);
        try self.sendControl(w.buf.items, true);
        var reply = try self.waitReply(0);
        const version = try reply.u32_() & 0xFFFF;
        if (version < proto.min_server_version) {
            log.warn("servidor PulseAudio antigo demais (protocolo {d})", .{version});
            return error.ServerError;
        }

        try proto.setClientName(&w, 1, "Vacina");
        try self.sendControl(w.buf.items, false);
        _ = try self.waitReply(1);

        try proto.createPlaybackStream(&w, 2, "Vacina", target_latency);
        try self.sendControl(w.buf.items, false);
        reply = try self.waitReply(2);
        self.channel = try reply.u32_();
        _ = try reply.u32_(); // indice do sink input
        self.requested += try reply.u32_();

        var samples: [2048 * wav.channels]i16 = undefined;
        while (true) {
            while (self.requested >= wav.bytes_per_frame) {
                const frames: usize = @min(self.requested / wav.bytes_per_frame, samples.len / wav.channels);
                const out = samples[0 .. frames * wav.channels];
                mixer.render(out);
                const bytes = std.mem.sliceAsBytes(out);
                const header = proto.descriptor(@intCast(bytes.len), self.channel);
                try linux_sys.sendAll(self.fd, &.{ &header, bytes }, null);
                self.requested -= bytes.len;
            }
            if (try self.readPacket()) |packet| try self.handle(packet);
        }
    }

    /// Envia um comando; o AUTH leva as credenciais do processo junto.
    fn sendControl(self: *Connection, payload: []const u8, credentials: bool) Error!void {
        const header = proto.descriptor(@intCast(payload.len), proto.control_channel);
        if (!credentials) return linux_sys.sendAll(self.fd, &.{ &header, payload }, null);

        const Ucred = extern struct { pid: i32, uid: u32, gid: u32 };
        const Cmsg = extern struct { header: linux.cmsghdr, cred: Ucred, pad: u32 = 0 };
        const cmsg: Cmsg = .{
            .header = .{ .len = @sizeOf(linux.cmsghdr) + @sizeOf(Ucred), .level = linux.SOL.SOCKET, .type = linux.SCM.CREDENTIALS },
            .cred = .{ .pid = linux.getpid(), .uid = linux.getuid(), .gid = linux.getgid() },
        };
        try linux_sys.sendAll(self.fd, &.{ &header, payload }, std.mem.asBytes(&cmsg));
    }

    /// Le o proximo pacote; `null` se nada chegou em 100 ms (para conferir
    /// `running`). Dados alem de `payload` sao descartados.
    fn readPacket(self: *Connection) Error!?[]const u8 {
        if (!self.running.load(.acquire)) return error.Stopped;
        if (!try linux_sys.pollIn(self.fd, 100)) return null;
        var header: [20]u8 = undefined;
        try self.readExact(&header);
        const d = proto.parseDescriptor(&header);
        var remaining: usize = d.length;
        const keep: usize = @min(remaining, self.payload.len);
        try self.readExact(self.payload[0..keep]);
        remaining -= keep;
        while (remaining > 0) {
            var skip: [512]u8 = undefined;
            const n: usize = @min(remaining, skip.len);
            try self.readExact(skip[0..n]);
            remaining -= n;
        }
        if (d.channel != proto.control_channel) return null; // audio de captura: nao usado
        return self.payload[0..keep];
    }

    fn readExact(self: *Connection, buf: []u8) Error!void {
        var done: usize = 0;
        while (done < buf.len) {
            const n = try linux_sys.readSome(self.fd, buf[done..]);
            if (n == 0) return error.ConnectionClosed;
            done += n;
        }
    }

    /// Espera a resposta ao comando `tag`, tratando o que chegar antes.
    fn waitReply(self: *Connection, tag: u32) Error!proto.Reader {
        while (true) {
            const packet = try self.readPacket() orelse continue;
            const c = try proto.parseCommand(packet);
            if (c.tag == tag and c.cmd == proto.command.reply) return c.rest;
            if (c.tag == tag and c.cmd == proto.command.err) {
                var rest = c.rest;
                log.warn("o servidor de audio recusou o comando {d} (erro {d})", .{ tag, rest.u32_() catch 0 });
                return error.ServerError;
            }
            try self.handle(packet);
        }
    }

    fn handle(self: *Connection, packet: []const u8) Error!void {
        var c = try proto.parseCommand(packet);
        switch (c.cmd) {
            proto.command.request => {
                const channel = try c.rest.u32_();
                const bytes = try c.rest.u32_();
                if (channel == self.channel) self.requested += bytes;
            },
            proto.command.playback_stream_killed => return error.ConnectionClosed,
            else => {},
        }
    }
};
