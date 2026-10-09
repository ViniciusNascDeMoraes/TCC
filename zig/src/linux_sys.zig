//! Chamadas de sistema do Linux usadas pelos backends de janela (X11) e de
//! audio (PulseAudio): sockets Unix bloqueantes, sem libc.

const std = @import("std");
const linux = std.os.linux;
const iovec_const = std.posix.iovec_const;

pub const Error = error{ ConnectFailed, ConnectionClosed, SystemError };

/// Converte o retorno de uma syscall em erro. Quem chama repete a syscall
/// quando ela e interrompida por sinal (`interrupted`).
fn check(rc: usize) Error!usize {
    return switch (linux.errno(rc)) {
        .SUCCESS => rc,
        .PIPE, .CONNRESET, .NOTCONN => error.ConnectionClosed,
        else => error.SystemError,
    };
}

fn interrupted(rc: usize) bool {
    return linux.errno(rc) == .INTR;
}

/// Conecta a um socket Unix pelo caminho (ou no espaco abstrato).
pub fn connectUnix(path: []const u8, abstract: bool) Error!i32 {
    var addr: linux.sockaddr.un = .{ .path = @splat(0) };
    const offset: usize = @intFromBool(abstract);
    if (path.len + offset >= addr.path.len) return error.ConnectFailed;
    @memcpy(addr.path[offset..][0..path.len], path);
    // No espaco abstrato o tamanho conta so os bytes usados, sem terminador.
    const len: linux.socklen_t = @intCast(@offsetOf(linux.sockaddr.un, "path") + offset + path.len + @intFromBool(!abstract));

    const fd_rc = linux.socket(linux.AF.UNIX, linux.SOCK.STREAM | linux.SOCK.CLOEXEC, 0);
    if (linux.errno(fd_rc) != .SUCCESS) return error.ConnectFailed;
    const fd: i32 = @intCast(fd_rc);
    while (true) {
        const rc = linux.connect(fd, &addr, len);
        if (interrupted(rc)) continue;
        if (linux.errno(rc) != .SUCCESS) {
            close(fd);
            return error.ConnectFailed;
        }
        return fd;
    }
}

pub fn close(fd: i32) void {
    _ = linux.close(fd);
}

/// Envia todos os bytes de `parts`, com `control` (dados auxiliares) junto
/// do primeiro pedaco. Usa MSG_NOSIGNAL: sem SIGPIPE se o servidor fechar.
pub fn sendAll(fd: i32, parts: []const []const u8, control: ?[]const u8) Error!void {
    var iov: [4]iovec_const = undefined;
    std.debug.assert(parts.len <= iov.len);
    var count: usize = 0;
    for (parts) |p| {
        if (p.len == 0) continue;
        iov[count] = .{ .base = p.ptr, .len = p.len };
        count += 1;
    }
    var first: usize = 0;
    var ctrl = control;
    while (first < count) {
        const msg: linux.msghdr_const = .{
            .name = null,
            .namelen = 0,
            .iov = iov[first..count].ptr,
            .iovlen = count - first,
            .control = if (ctrl) |c| c.ptr else null,
            .controllen = if (ctrl) |c| c.len else 0,
            .flags = 0,
        };
        const rc = linux.sendmsg(fd, &msg, linux.MSG.NOSIGNAL);
        if (interrupted(rc)) continue;
        var sent = try check(rc);
        ctrl = null;
        // Avanca pelos pedacos ja enviados (o envio pode ser parcial).
        while (first < count and sent >= iov[first].len) {
            sent -= iov[first].len;
            first += 1;
        }
        if (first < count) {
            iov[first].base += sent;
            iov[first].len -= sent;
        }
    }
}

/// Le o que estiver disponivel (bloqueia se nada chegou); 0 = conexao fechada.
pub fn readSome(fd: i32, buf: []u8) Error!usize {
    while (true) {
        const rc = linux.read(fd, buf.ptr, buf.len);
        if (interrupted(rc)) continue;
        return check(rc) catch |err| switch (err) {
            error.ConnectionClosed => 0,
            else => err,
        };
    }
}

/// Ha dados para ler (ou a conexao fechou) dentro de `timeout_ms`?
pub fn pollIn(fd: i32, timeout_ms: i32) Error!bool {
    var fds = [_]linux.pollfd{.{ .fd = fd, .events = linux.POLL.IN, .revents = 0 }};
    while (true) {
        const rc = linux.poll(&fds, 1, timeout_ms);
        if (interrupted(rc)) continue;
        return try check(rc) > 0;
    }
}

/// Dorme `ms` milissegundos.
pub fn sleepMs(ms: u32) void {
    var ts: linux.timespec = .{ .sec = @intCast(ms / 1000), .nsec = @intCast(ms % 1000 * std.time.ns_per_ms) };
    while (interrupted(linux.nanosleep(&ts, &ts))) {}
}

/// Nome desta maquina (usado para achar o cookie do X11).
pub fn hostname(buf: *[65]u8) []const u8 {
    var uts: linux.utsname = undefined;
    if (linux.errno(linux.uname(&uts)) != .SUCCESS) return "";
    const name = std.mem.sliceTo(&uts.nodename, 0);
    const len = @min(name.len, buf.len);
    @memcpy(buf[0..len], name[0..len]);
    return buf[0..len];
}
