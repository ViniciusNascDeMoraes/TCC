//! Janela no Linux falando o protocolo X11 direto pelo socket Unix, sem
//! libX11/libxcb. Funciona em servidores X e no XWayland.
//!
//! O quadro (960x640, pixels de 32 bits) vai para um pixmap em faixas de
//! PutImage, que depois e copiado para a janela de uma vez (CopyArea). Um
//! GetInputFocus no fim de cada quadro espera o servidor processar tudo,
//! como o XSync, para nao acumular quadros atrasados.

const std = @import("std");
const linux_sys = @import("../linux_sys.zig");
const platform = @import("../platform.zig");
const proto = @import("x11_proto.zig");
const Canvas = @import("../canvas.zig").Canvas;

const log = std.log.scoped(.x11);

pub const Error = error{
    NoDisplay,
    ConnectFailed,
    SetupFailed,
    UnsupportedVisual,
    RequestFailed,
    ConnectionClosed,
    SystemError,
    BadSetup,
    OutOfMemory,
};

const in_capacity = 256 * 1024;

pub const Window = struct {
    gpa: std.mem.Allocator,
    fd: i32,
    setup: proto.Setup,
    width: u16,
    height: u16,
    window: u32,
    pixmap: u32,
    gc: u32,
    wm_protocols: u32 = 0,
    wm_delete_window: u32 = 0,
    keymap: [256]?platform.Key = @splat(null),
    keymap_stale: bool = false,
    /// XKB entrega a repeticao automatica sem os KeyRelease falsos.
    detectable_repeat: bool = false,
    /// Codigo dos eventos do XKB, quando a extensao esta em uso.
    xkb_event: ?u8 = null,
    queue: platform.KeyQueue = .{},
    close_requested: bool = false,
    /// Requests ainda nao enviados.
    out: std.ArrayList(u8) = .empty,
    in: []u8,
    in_start: usize = 0,
    in_end: usize = 0,
    /// Numero de sequencia do ultimo request (16 bits, como o servidor envia).
    seq: u16 = 0,

    pub fn open(
        self: *Window,
        gpa: std.mem.Allocator,
        io: std.Io,
        env: *const std.process.Environ.Map,
        title: []const u8,
        width: u16,
        height: u16,
    ) Error!void {
        const display_name = env.get("DISPLAY") orelse {
            log.err("DISPLAY nao definido: o jogo precisa de um servidor X11 ou do XWayland", .{});
            return error.NoDisplay;
        };
        const display = proto.parseDisplay(display_name) orelse {
            log.err("DISPLAY invalido: \"{s}\"", .{display_name});
            return error.NoDisplay;
        };
        if (display.host.len != 0 and !std.mem.eql(u8, display.host, "unix")) {
            log.err("so displays locais sao suportados (DISPLAY=\"{s}\")", .{display_name});
            return error.NoDisplay;
        }

        var path_buf: [64]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "/tmp/.X11-unix/X{s}", .{display.number}) catch return error.NoDisplay;
        const fd = linux_sys.connectUnix(path, false) catch linux_sys.connectUnix(path, true) catch {
            log.err("nao foi possivel conectar ao servidor X em {s}", .{path});
            return error.ConnectFailed;
        };
        errdefer linux_sys.close(fd);

        const in = try gpa.alloc(u8, in_capacity);
        errdefer gpa.free(in);

        self.* = .{
            .gpa = gpa,
            .fd = fd,
            .setup = undefined,
            .width = width,
            .height = height,
            .window = undefined,
            .pixmap = undefined,
            .gc = undefined,
            .in = in,
        };
        errdefer self.out.deinit(gpa);

        try self.connect(io, env, display.number);
        try self.createWindow(title);
    }

    pub fn close(self: *Window) void {
        linux_sys.close(self.fd);
        self.out.deinit(self.gpa);
        self.gpa.free(self.in);
    }

    /// Eventos de teclado desde a ultima chamada.
    pub fn poll(self: *Window) []const platform.KeyEvent {
        self.pump() catch |err| self.lost(err);
        if (self.keymap_stale) {
            self.keymap_stale = false;
            self.loadKeymap() catch |err| self.lost(err);
        }
        return self.queue.take();
    }

    pub fn present(self: *Window, frame: Canvas) void {
        self.draw(frame) catch |err| self.lost(err);
    }

    fn lost(self: *Window, err: anyerror) void {
        if (!self.close_requested) log.err("conexao com o servidor X perdida: {s}", .{@errorName(err)});
        self.close_requested = true;
    }

    // ------------------------------------------------------------ conexao

    fn connect(self: *Window, io: std.Io, env: *const std.process.Environ.Map, number: []const u8) Error!void {
        const cookie = findCookie(self.gpa, io, env, number);
        var req_buf: [48]u8 = undefined;
        try linux_sys.sendAll(self.fd, &.{proto.setupRequest(&req_buf, cookie)}, null);

        try self.fillAtLeast(8);
        const extra = @as(usize, std.mem.readInt(u16, self.in[6..8], .little)) * 4;
        try self.fillAtLeast(8 + extra);
        const reply = self.in[0 .. 8 + extra];
        self.in_start = 8 + extra;
        if (reply[0] != 1) {
            const reason_len: usize = if (reply[0] == 0) reply[1] else extra;
            log.err("o servidor X recusou a conexao: {s}", .{reply[8..][0..@min(reason_len, extra)]});
            return error.SetupFailed;
        }
        self.setup = try proto.parseSetup(reply);
        if (!self.setup.supported()) {
            log.err("visual nao suportado: o jogo precisa de uma tela TrueColor de 24 bits (32 bits por pixel)", .{});
            return error.UnsupportedVisual;
        }
    }

    fn findCookie(gpa: std.mem.Allocator, io: std.Io, env: *const std.process.Environ.Map, number: []const u8) ?[16]u8 {
        var path_buf: [4096]u8 = undefined;
        const path = env.get("XAUTHORITY") orelse blk: {
            const home = env.get("HOME") orelse return null;
            break :blk std.fmt.bufPrint(&path_buf, "{s}/.Xauthority", .{home}) catch return null;
        };
        const data = std.Io.Dir.cwd().readFileAlloc(io, path, gpa, .limited(1 << 20)) catch return null;
        defer gpa.free(data);
        var host_buf: [65]u8 = undefined;
        return proto.findCookie(data, linux_sys.hostname(&host_buf), number);
    }

    fn createWindow(self: *Window, title: []const u8) Error!void {
        const s = self.setup;
        self.window = s.resourceId(0);
        self.pixmap = s.resourceId(1);
        self.gc = s.resourceId(2);
        const x: u16 = if (s.root_width > self.width) (s.root_width - self.width) / 2 else 0;
        const y: u16 = if (s.root_height > self.height) (s.root_height - self.height) / 2 else 0;

        var b = try self.request(proto.opcode.create_window, 0);
        try b.u32_(self.window);
        try b.u32_(s.root);
        try b.u16_(x);
        try b.u16_(y);
        try b.u16_(self.width);
        try b.u16_(self.height);
        try b.u16_(0); // borda
        try b.u16_(1); // InputOutput
        try b.u32_(0); // visual do pai
        try b.u32_(0x800); // so a mascara de eventos
        const m = proto.event_mask;
        try b.u32_(m.key_press | m.key_release | m.exposure | m.structure_notify | m.focus_change);
        b.end();

        const names = [_][]const u8{ "WM_PROTOCOLS", "WM_DELETE_WINDOW", "_NET_WM_NAME", "UTF8_STRING" };
        var seqs: [names.len]u16 = undefined;
        for (names, &seqs) |name, *seq| {
            var r = try self.request(proto.opcode.intern_atom, 0);
            try r.u16_(@intCast(name.len));
            try r.u16_(0);
            try r.bytes(name);
            r.end();
            seq.* = self.seq;
        }
        var atoms: [names.len]u32 = undefined;
        for (seqs, &atoms) |seq, *a| a.* = std.mem.readInt(u32, (try self.waitReply(seq))[8..12], .little);
        self.wm_protocols = atoms[0];
        self.wm_delete_window = atoms[1];

        const a = proto.atom;
        try self.changeProperty(a.wm_name, a.string, 8, title);
        try self.changeProperty(atoms[2], atoms[3], 8, title);
        try self.changeProperty(a.wm_class, a.string, 8, "vacina\x00Vacina\x00");
        try self.changeProperty(self.wm_protocols, a.atom_type, 32, std.mem.asBytes(&self.wm_delete_window));
        // Tamanho fixo (minimo = maximo) e posicao centralizada.
        var hints: [18]u32 = @splat(0);
        hints[0] = 1 | 4 | 16 | 32; // USPosition, PPosition, PMinSize, PMaxSize
        hints[1] = x;
        hints[2] = y;
        hints[3] = self.width;
        hints[4] = self.height;
        hints[5] = self.width;
        hints[6] = self.height;
        hints[7] = self.width;
        hints[8] = self.height;
        try self.changeProperty(a.wm_normal_hints, a.wm_size_hints, 32, std.mem.sliceAsBytes(&hints));

        var p = try self.request(proto.opcode.create_pixmap, 24);
        try p.u32_(self.pixmap);
        try p.u32_(self.window);
        try p.u16_(self.width);
        try p.u16_(self.height);
        p.end();

        var g = try self.request(proto.opcode.create_gc, 0);
        try g.u32_(self.gc);
        try g.u32_(self.pixmap);
        try g.u32_(0x10000); // graphics-exposures
        try g.u32_(0);
        g.end();

        try self.enableDetectableRepeat();
        try self.loadKeymap();

        var map = try self.request(proto.opcode.map_window, 0);
        try map.u32_(self.window);
        map.end();
        try self.flush();
    }

    fn changeProperty(self: *Window, property: u32, kind: u32, format: u8, data: []const u8) Error!void {
        var b = try self.request(proto.opcode.change_property, 0); // Replace
        try b.u32_(self.window);
        try b.u32_(property);
        try b.u32_(kind);
        try b.u8_(format);
        for (0..3) |_| try b.u8_(0);
        try b.u32_(@intCast(data.len / (format / 8)));
        try b.bytes(data);
        b.end();
    }

    /// Liga o DetectableAutoRepeat do XKB; sem ele, a repeticao chega como
    /// pares KeyRelease + KeyPress com o mesmo horario.
    fn enableDetectableRepeat(self: *Window) Error!void {
        const name = "XKEYBOARD";
        var q = try self.request(proto.opcode.query_extension, 0);
        try q.u16_(name.len);
        try q.u16_(0);
        try q.bytes(name);
        q.end();
        const ext = try self.waitReply(self.seq);
        if (ext[8] == 0) return;
        const xkb = ext[9];
        const xkb_event = ext[10];

        var use = try self.request(xkb, 0); // XkbUseExtension 1.0
        try use.u16_(1);
        try use.u16_(0);
        use.end();
        if ((try self.waitReply(self.seq))[1] == 0) return;

        // Com o XKB em uso o servidor nao manda mais o MappingNotify do
        // protocolo basico: a troca de layout chega como evento do XKB.
        var select = try self.request(xkb, 1); // XkbSelectEvents
        try select.u16_(0x0100); // teclado principal
        try select.u16_(0x3); // NewKeyboardNotify | MapNotify
        try select.u16_(0); // clear
        try select.u16_(0x1); // todos os detalhes do NewKeyboardNotify
        try select.u16_(0xFF); // todas as partes do mapa no MapNotify
        try select.u16_(0xFF);
        select.end();
        self.xkb_event = xkb_event;

        var flags = try self.request(xkb, 21); // XkbPerClientFlags
        try flags.u16_(0x0100); // teclado principal
        try flags.u16_(0);
        try flags.u32_(1); // change: DetectableAutoRepeat
        try flags.u32_(1); // value
        try flags.u32_(0);
        try flags.u32_(0);
        try flags.u32_(0);
        flags.end();
        const reply = try self.waitReply(self.seq);
        self.detectable_repeat = std.mem.readInt(u32, reply[12..16], .little) & 1 != 0;
    }

    fn loadKeymap(self: *Window) Error!void {
        const first = self.setup.min_keycode;
        const count: u8 = self.setup.max_keycode - first + 1;
        var b = try self.request(proto.opcode.get_keyboard_mapping, 0);
        try b.u8_(first);
        try b.u8_(count);
        try b.u16_(0);
        b.end();
        const reply = try self.waitReply(self.seq);
        const per: usize = reply[1];
        self.keymap = @splat(null);
        for (0..count) |i| {
            // Colunas 0 e 1: sem e com Shift.
            for (0..@min(per, 2)) |col| {
                const offset = 32 + (i * per + col) * 4;
                if (offset + 4 > reply.len) break;
                const keysym = std.mem.readInt(u32, reply[offset..][0..4], .little);
                if (proto.keyFromKeysym(keysym)) |key| {
                    self.keymap[first + i] = key;
                    break;
                }
            }
        }
    }

    // ------------------------------------------------------------ envio

    fn request(self: *Window, op: u8, data: u8) Error!proto.Builder {
        var b: proto.Builder = .{ .buf = &self.out, .gpa = self.gpa };
        try b.begin(op, data);
        self.seq +%= 1;
        return b;
    }

    fn flush(self: *Window) Error!void {
        if (self.out.items.len == 0) return;
        try linux_sys.sendAll(self.fd, &.{self.out.items}, null);
        self.out.clearRetainingCapacity();
    }

    fn draw(self: *Window, frame: Canvas) Error!void {
        std.debug.assert(frame.width == self.width and frame.height == self.height);
        try self.flush();
        const bytes = std.mem.sliceAsBytes(frame.pixels);
        const row_bytes = @as(usize, self.width) * 4;
        const rows_per = proto.rowsPerPutImage(self.setup.max_request_len, self.width);
        var y: u32 = 0;
        while (y < self.height) {
            const rows: u16 = @intCast(@min(rows_per, self.height - y));
            const header = proto.putImageHeader(self.pixmap, self.gc, self.width, rows, @intCast(y));
            try linux_sys.sendAll(self.fd, &.{ &header, bytes[y * row_bytes ..][0 .. rows * row_bytes] }, null);
            self.seq +%= 1;
            y += rows;
        }

        var copy = try self.request(proto.opcode.copy_area, 0);
        try copy.u32_(self.pixmap);
        try copy.u32_(self.window);
        try copy.u32_(self.gc);
        for ([_]u16{ 0, 0, 0, 0, self.width, self.height }) |v| try copy.u16_(v);
        copy.end();

        var sync = try self.request(proto.opcode.get_input_focus, 0);
        sync.end();
        _ = try self.waitReply(self.seq);
    }

    // ------------------------------------------------------------ leitura

    /// Le mais bytes do socket (bloqueando).
    fn fill(self: *Window) Error!void {
        if (self.in_start > 0) {
            std.mem.copyForwards(u8, self.in[0 .. self.in_end - self.in_start], self.in[self.in_start..self.in_end]);
            self.in_end -= self.in_start;
            self.in_start = 0;
        }
        if (self.in_end == self.in.len) return error.SystemError; // pacote maior que o buffer
        const n = try linux_sys.readSome(self.fd, self.in[self.in_end..]);
        if (n == 0) return error.ConnectionClosed;
        self.in_end += n;
    }

    fn fillAtLeast(self: *Window, n: usize) Error!void {
        while (self.in_end - self.in_start < n) try self.fill();
    }

    /// Proximo pacote completo ja recebido (sem consumir).
    fn peek(self: *Window) ?[]const u8 {
        const data = self.in[self.in_start..self.in_end];
        const len = proto.packetLength(data) orelse return null;
        if (len > data.len) return null;
        return data[0..len];
    }

    /// Envia o que falta e espera a resposta do request `seq`, tratando os
    /// eventos que chegarem antes. A resposta vale ate a proxima leitura.
    fn waitReply(self: *Window, seq: u16) Error![]const u8 {
        try self.flush();
        while (true) {
            while (self.peek()) |packet| {
                self.in_start += packet.len;
                const packet_seq = std.mem.readInt(u16, packet[2..4], .little);
                switch (packet[0] & 0x7F) {
                    proto.event.reply => if (packet_seq == seq) return packet,
                    proto.event.err => {
                        logError(packet);
                        if (packet_seq == seq) return error.RequestFailed;
                    },
                    else => try self.handleEvent(packet),
                }
            }
            try self.fill();
        }
    }

    /// Le e trata os eventos que ja chegaram, sem bloquear. Comeca pelo que
    /// ficou no buffer: eventos lidos junto com a resposta de um request.
    fn pump(self: *Window) Error!void {
        try self.flush();
        try self.drain();
        while (try linux_sys.pollIn(self.fd, 0)) {
            try self.fill();
            try self.drain();
        }
    }

    /// Trata todos os pacotes completos que estao no buffer.
    fn drain(self: *Window) Error!void {
        while (self.peek()) |packet| {
            self.in_start += packet.len;
            switch (packet[0] & 0x7F) {
                proto.event.reply => {},
                proto.event.err => logError(packet),
                else => try self.handleEvent(packet),
            }
        }
    }

    fn logError(packet: []const u8) void {
        log.warn("erro X {d} no request {d}.{d} (valor 0x{x})", .{
            packet[1],
            packet[10],
            std.mem.readInt(u16, packet[8..10], .little),
            std.mem.readInt(u32, packet[4..8], .little),
        });
    }

    fn handleEvent(self: *Window, packet: []const u8) Error!void {
        if (self.xkb_event) |code| {
            // NewKeyboardNotify (0) ou MapNotify (1): o layout mudou.
            if (packet[0] & 0x7F == code) {
                if (packet[1] <= 1) self.keymap_stale = true;
                return;
            }
        }
        switch (packet[0] & 0x7F) {
            proto.event.key_press => if (self.keymap[packet[1]]) |key| self.queue.down(key),
            proto.event.key_release => if (self.keymap[packet[1]]) |key| {
                if (!self.detectable_repeat and try self.isFakeRelease(packet)) return;
                self.queue.up(key);
            },
            proto.event.focus_out => {
                // Modos Grab/Ungrab (atalhos do gerenciador de janelas) nao contam.
                const mode = packet[8];
                if (mode == 0 or mode == 3) self.queue.releaseAll();
            },
            proto.event.client_message => {
                const kind = std.mem.readInt(u32, packet[8..12], .little);
                const data0 = std.mem.readInt(u32, packet[12..16], .little);
                if (kind == self.wm_protocols and data0 == self.wm_delete_window) self.close_requested = true;
            },
            proto.event.mapping_notify => if (packet[4] == 1) {
                self.keymap_stale = true;
            },
            else => {},
        }
    }

    /// Sem XKB, a repeticao automatica chega como KeyRelease seguido de
    /// KeyPress da mesma tecla com o mesmo horario: esse KeyRelease e ignorado.
    fn isFakeRelease(self: *Window, release: []const u8) Error!bool {
        // `fill` pode mover o buffer: guarda a tecla e o horario antes.
        const keycode = release[1];
        const time = release[4..8].*;
        if (self.peek() == null and try linux_sys.pollIn(self.fd, 0)) try self.fill();
        const next = self.peek() orelse return false;
        return next[0] & 0x7F == proto.event.key_press and next[1] == keycode and std.mem.eql(u8, next[4..8], &time);
    }
};
