//! Janela e teclado: o `JFrame` + `KeyListener` do Java.
//!
//! Cada sistema tem seu backend, escrito direto sobre a interface do sistema,
//! sem bibliotecas: X11 pelo socket no Linux e Win32 no Windows. Os dois
//! oferecem a mesma `Window`:
//!
//! - `open(gpa, io, env, title, width, height)` / `close()`
//! - `poll() []const KeyEvent`: eventos de teclado desde o ultimo quadro
//! - `close_requested`: o usuario fechou a janela
//! - `present(frame)`: mostra o `Canvas` do quadro

const std = @import("std");
const builtin = @import("builtin");

pub const Window = switch (builtin.os.tag) {
    .linux => @import("platform/x11.zig").Window,
    .windows => @import("platform/win32.zig").Window,
    else => @compileError("sistema nao suportado: so Linux (X11) e Windows"),
};

/// Teclas que o jogo usa. O Enter do teclado numerico tambem e `.enter`,
/// como o `KeyEvent.VK_ENTER` do Java.
pub const Key = enum { w, a, s, d, enter, escape };

pub const KeyEvent = struct {
    key: Key,
    action: Action,

    pub const Action = enum {
        /// Tecla apertada (`keyPressed`).
        press,
        /// Repeticao automatica do sistema com a tecla segurada (`keyPressed` de novo).
        repeat,
        /// Tecla solta (`keyReleased`).
        release,
    };
};

/// Fila dos eventos de teclado de um quadro, na ordem em que aconteceram.
pub const KeyQueue = struct {
    events: [128]KeyEvent = undefined,
    len: usize = 0,
    held: std.EnumSet(Key) = .initEmpty(),

    /// Com a fila cheia, um evento novo so entra tirando um mais antigo,
    /// primeiro uma repeticao. Uma soltura sempre entra (perde-la deixaria a
    /// tecla presa no jogo), tirando se preciso um aperto ou a soltura mais
    /// antiga; repeticoes novas e apertos sem espaco sao descartados.
    /// Devolve se o evento entrou.
    fn push(self: *KeyQueue, event: KeyEvent) bool {
        if (self.len == self.events.len) {
            if (event.action == .repeat) return false;
            var victim = self.oldest(.repeat);
            if (victim == null and event.action == .release) victim = self.oldest(.press) orelse 0;
            const i = victim orelse return false;
            std.mem.copyForwards(KeyEvent, self.events[i .. self.len - 1], self.events[i + 1 .. self.len]);
            self.len -= 1;
        }
        self.events[self.len] = event;
        self.len += 1;
        return true;
    }

    fn oldest(self: *const KeyQueue, action: KeyEvent.Action) ?usize {
        for (self.events[0..self.len], 0..) |e, i| {
            if (e.action == action) return i;
        }
        return null;
    }

    /// Tecla apertada; se ja estava apertada e uma repeticao. Um aperto que
    /// nao coube na fila nao marca a tecla como segurada: a proxima repeticao
    /// do sistema chega ao jogo como aperto.
    pub fn down(self: *KeyQueue, key: Key) void {
        const action: KeyEvent.Action = if (self.held.contains(key)) .repeat else .press;
        if (self.push(.{ .key = key, .action = action })) self.held.insert(key);
    }

    pub fn up(self: *KeyQueue, key: Key) void {
        self.held.remove(key);
        _ = self.push(.{ .key = key, .action = .release });
    }

    /// A janela perdeu o foco: solta tudo o que estava apertado.
    pub fn releaseAll(self: *KeyQueue) void {
        var it = self.held.iterator();
        while (it.next()) |key| self.up(key);
    }

    /// Eventos acumulados; a fila fica vazia para o proximo quadro.
    pub fn take(self: *KeyQueue) []const KeyEvent {
        defer self.len = 0;
        return self.events[0..self.len];
    }
};

const testing = std.testing;

test "aperto, repeticao e soltura na ordem" {
    var q: KeyQueue = .{};
    q.down(.d);
    q.down(.d);
    q.down(.w);
    q.up(.d);
    q.up(.enter);
    try testing.expectEqualSlices(KeyEvent, &.{
        .{ .key = .d, .action = .press },
        .{ .key = .d, .action = .repeat },
        .{ .key = .w, .action = .press },
        .{ .key = .d, .action = .release },
        .{ .key = .enter, .action = .release },
    }, q.take());
    try testing.expectEqual(@as(usize, 0), q.take().len);
    q.down(.d);
    try testing.expectEqual(KeyEvent.Action.press, q.take()[0].action);
}

test "perder o foco solta as teclas apertadas" {
    var q: KeyQueue = .{};
    q.down(.a);
    q.down(.s);
    _ = q.take();
    q.releaseAll();
    try testing.expectEqualSlices(KeyEvent, &.{
        .{ .key = .a, .action = .release },
        .{ .key = .s, .action = .release },
    }, q.take());
    q.down(.a);
    try testing.expectEqual(KeyEvent.Action.press, q.take()[0].action);
}

test "fila cheia descarta repeticoes primeiro" {
    var q: KeyQueue = .{};
    q.down(.d);
    for (0..200) |_| q.down(.d);
    q.up(.d);
    const events = q.take();
    try testing.expectEqual(@as(usize, 128), events.len);
    try testing.expectEqual(KeyEvent.Action.press, events[0].action);
    try testing.expectEqual(KeyEvent.Action.release, events[events.len - 1].action);
}

test "fila cheia nunca perde solturas" {
    var q: KeyQueue = .{};
    for (0..64) |_| {
        q.down(.w);
        q.up(.w);
    }
    // Sem espaco nem repeticoes: o aperto de D e descartado, a soltura entra
    // no lugar do aperto mais antigo.
    q.down(.d);
    q.up(.d);
    const events = q.take();
    try testing.expectEqual(@as(usize, 128), events.len);
    try testing.expectEqual(KeyEvent{ .key = .w, .action = .release }, events[0]);
    try testing.expectEqual(KeyEvent{ .key = .d, .action = .release }, events[127]);
}

test "aperto que nao coube vira aperto na proxima repeticao" {
    var q: KeyQueue = .{};
    for (0..64) |_| {
        q.down(.w);
        q.up(.w);
    }
    // Fila cheia de apertos e solturas: o Enter nao entra...
    q.down(.enter);
    try testing.expect(!q.held.contains(.enter));
    _ = q.take();
    // ...e a repeticao seguinte do sistema chega como aperto.
    q.down(.enter);
    try testing.expectEqualSlices(KeyEvent, &.{.{ .key = .enter, .action = .press }}, q.take());
}
