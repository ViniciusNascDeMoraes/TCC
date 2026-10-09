//! Janela no Windows pela API Win32 (user32/gdi32), declarada aqui mesmo em
//! Zig: sem C e sem bibliotecas alem das DLLs do sistema.
//!
//! O quadro (960x640, pixels de 32 bits BGRA) vai para a janela com
//! `StretchDIBits`, sem conversao.

const std = @import("std");
const platform = @import("../platform.zig");
const Canvas = @import("../canvas.zig").Canvas;

const log = std.log.scoped(.win32);

const BOOL = c_int;
const UINT = c_uint;
const DWORD = u32;
const WPARAM = usize;
const LPARAM = isize;
const LRESULT = isize;
const LPCWSTR = [*:0]const u16;
const HWND = *opaque {};
const HINSTANCE = *opaque {};
const HDC = *opaque {};
const HICON = *opaque {};
const HCURSOR = *opaque {};
const HBRUSH = *opaque {};
const HMENU = *opaque {};

const WNDPROC = *const fn (HWND, UINT, WPARAM, LPARAM) callconv(.winapi) LRESULT;

const WNDCLASSEXW = extern struct {
    cbSize: UINT = @sizeOf(WNDCLASSEXW),
    style: UINT,
    lpfnWndProc: WNDPROC,
    cbClsExtra: c_int = 0,
    cbWndExtra: c_int = 0,
    hInstance: ?HINSTANCE,
    hIcon: ?HICON = null,
    hCursor: ?HCURSOR,
    hbrBackground: ?HBRUSH = null,
    lpszMenuName: ?LPCWSTR = null,
    lpszClassName: LPCWSTR,
    hIconSm: ?HICON = null,
};

const POINT = extern struct { x: i32, y: i32 };

const MSG = extern struct {
    hwnd: ?HWND,
    message: UINT,
    wParam: WPARAM,
    lParam: LPARAM,
    time: DWORD,
    pt: POINT,
    lPrivate: DWORD,
};

const RECT = extern struct { left: i32, top: i32, right: i32, bottom: i32 };

const BITMAPINFOHEADER = extern struct {
    biSize: DWORD = @sizeOf(BITMAPINFOHEADER),
    biWidth: i32,
    biHeight: i32,
    biPlanes: u16 = 1,
    biBitCount: u16 = 32,
    biCompression: DWORD = 0, // BI_RGB
    biSizeImage: DWORD = 0,
    biXPelsPerMeter: i32 = 0,
    biYPelsPerMeter: i32 = 0,
    biClrUsed: DWORD = 0,
    biClrImportant: DWORD = 0,
};

const BITMAPINFO = extern struct {
    bmiHeader: BITMAPINFOHEADER,
    bmiColors: [1]u32 = .{0},
};

extern "user32" fn SetProcessDPIAware() callconv(.winapi) BOOL;
extern "user32" fn RegisterClassExW(class: *const WNDCLASSEXW) callconv(.winapi) u16;
extern "user32" fn UnregisterClassW(class_name: LPCWSTR, instance: ?HINSTANCE) callconv(.winapi) BOOL;
extern "user32" fn CreateWindowExW(ex_style: DWORD, class_name: LPCWSTR, window_name: LPCWSTR, style: DWORD, x: c_int, y: c_int, width: c_int, height: c_int, parent: ?HWND, menu: ?HMENU, instance: ?HINSTANCE, param: ?*anyopaque) callconv(.winapi) ?HWND;
extern "user32" fn DestroyWindow(hwnd: HWND) callconv(.winapi) BOOL;
extern "user32" fn ShowWindow(hwnd: HWND, cmd: c_int) callconv(.winapi) BOOL;
extern "user32" fn AdjustWindowRect(rect: *RECT, style: DWORD, menu: BOOL) callconv(.winapi) BOOL;
extern "user32" fn GetSystemMetrics(index: c_int) callconv(.winapi) c_int;
extern "user32" fn LoadCursorW(instance: ?HINSTANCE, name: LPCWSTR) callconv(.winapi) ?HCURSOR;
extern "user32" fn GetDC(hwnd: ?HWND) callconv(.winapi) ?HDC;
extern "user32" fn PeekMessageW(msg: *MSG, hwnd: ?HWND, min: UINT, max: UINT, remove: UINT) callconv(.winapi) BOOL;
extern "user32" fn DispatchMessageW(msg: *const MSG) callconv(.winapi) LRESULT;
extern "user32" fn DefWindowProcW(hwnd: HWND, msg: UINT, wparam: WPARAM, lparam: LPARAM) callconv(.winapi) LRESULT;
extern "gdi32" fn StretchDIBits(hdc: HDC, x_dest: c_int, y_dest: c_int, dest_width: c_int, dest_height: c_int, x_src: c_int, y_src: c_int, src_width: c_int, src_height: c_int, bits: *const anyopaque, info: *const BITMAPINFO, usage: UINT, rop: DWORD) callconv(.winapi) c_int;
extern "kernel32" fn GetModuleHandleW(name: ?LPCWSTR) callconv(.winapi) ?HINSTANCE;
extern "winmm" fn timeBeginPeriod(period: UINT) callconv(.winapi) UINT;
extern "winmm" fn timeEndPeriod(period: UINT) callconv(.winapi) UINT;

const WM_CLOSE = 0x0010;
const WM_ERASEBKGND = 0x0014;
const WM_KILLFOCUS = 0x0008;
const WM_KEYDOWN = 0x0100;
const WM_KEYUP = 0x0101;
const WM_SYSKEYDOWN = 0x0104;
const WM_SYSKEYUP = 0x0105;
const WM_SYSCOMMAND = 0x0112;
const SC_KEYMENU = 0xF100;
/// WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX: tamanho fixo.
const window_style = 0x00CA0000;

const class_name = std.unicode.utf8ToUtf16LeStringLiteral("Vacina");

/// A janela que recebe as mensagens (o jogo so tem uma).
var current: ?*Window = null;

/// Teclas virtuais do Windows; o Enter do teclado numerico tambem e VK_RETURN.
fn keyFromVk(vk: WPARAM) ?platform.Key {
    return switch (vk) {
        'W' => .w,
        'A' => .a,
        'S' => .s,
        'D' => .d,
        0x0D => .enter, // VK_RETURN
        0x1B => .escape, // VK_ESCAPE
        else => null,
    };
}

fn wndProc(hwnd: HWND, msg: UINT, wparam: WPARAM, lparam: LPARAM) callconv(.winapi) LRESULT {
    const self = current orelse return DefWindowProcW(hwnd, msg, wparam, lparam);
    switch (msg) {
        // A repeticao automatica chega como novos WM_KEYDOWN.
        WM_KEYDOWN, WM_SYSKEYDOWN => if (keyFromVk(wparam)) |key| self.queue.down(key),
        WM_KEYUP, WM_SYSKEYUP => if (keyFromVk(wparam)) |key| self.queue.up(key),
        WM_KILLFOCUS => self.queue.releaseAll(),
        WM_CLOSE => {
            self.close_requested = true;
            return 0;
        },
        WM_ERASEBKGND => return 1,
        // Alt ou F10 sozinhos abririam o menu da janela e pausariam o jogo.
        WM_SYSCOMMAND => if (wparam & 0xFFF0 == SC_KEYMENU) return 0,
        else => {},
    }
    // WM_SYSKEY* tambem seguem para o Windows, para o Alt+F4 funcionar.
    return DefWindowProcW(hwnd, msg, wparam, lparam);
}

pub const Window = struct {
    hwnd: HWND,
    hdc: HDC,
    instance: ?HINSTANCE,
    width: u16,
    height: u16,
    queue: platform.KeyQueue = .{},
    close_requested: bool = false,

    pub fn open(
        self: *Window,
        gpa: std.mem.Allocator,
        io: std.Io,
        env: *const std.process.Environ.Map,
        title: []const u8,
        width: u16,
        height: u16,
    ) !void {
        _ = gpa;
        _ = io;
        _ = env;
        // A area da janela fica com 960x640 pixels reais, mesmo com escala de tela.
        _ = SetProcessDPIAware();
        const instance = GetModuleHandleW(null);

        const class: WNDCLASSEXW = .{
            .style = 0x0020, // CS_OWNDC
            .lpfnWndProc = wndProc,
            .hInstance = instance,
            .hCursor = LoadCursorW(null, @ptrFromInt(32512)), // IDC_ARROW
            .lpszClassName = class_name,
        };
        if (RegisterClassExW(&class) == 0) {
            log.err("RegisterClassExW falhou", .{});
            return error.WindowFailed;
        }
        errdefer _ = UnregisterClassW(class_name, instance);

        var rect: RECT = .{ .left = 0, .top = 0, .right = width, .bottom = height };
        _ = AdjustWindowRect(&rect, window_style, 0);
        const outer_w = rect.right - rect.left;
        const outer_h = rect.bottom - rect.top;
        const x = @max(0, @divTrunc(GetSystemMetrics(0) - outer_w, 2)); // SM_CXSCREEN
        const y = @max(0, @divTrunc(GetSystemMetrics(1) - outer_h, 2)); // SM_CYSCREEN

        var title_w: [128:0]u16 = undefined;
        const len = std.unicode.utf8ToUtf16Le(&title_w, title) catch 0;
        title_w[len] = 0;

        self.* = .{ .hwnd = undefined, .hdc = undefined, .instance = instance, .width = width, .height = height };
        current = self;
        errdefer current = null;
        self.hwnd = CreateWindowExW(0, class_name, &title_w, window_style, x, y, outer_w, outer_h, null, null, instance, null) orelse {
            log.err("CreateWindowExW falhou", .{});
            return error.WindowFailed;
        };
        errdefer _ = DestroyWindow(self.hwnd);
        self.hdc = GetDC(self.hwnd) orelse return error.WindowFailed;
        _ = ShowWindow(self.hwnd, 5); // SW_SHOW
        // Sleep com precisao de 1 ms para o ritmo de 60 quadros.
        _ = timeBeginPeriod(1);
    }

    pub fn close(self: *Window) void {
        _ = timeEndPeriod(1);
        _ = DestroyWindow(self.hwnd);
        _ = UnregisterClassW(class_name, self.instance);
        current = null;
    }

    /// Eventos de teclado desde a ultima chamada.
    pub fn poll(self: *Window) []const platform.KeyEvent {
        var msg: MSG = undefined;
        while (PeekMessageW(&msg, null, 0, 0, 1) != 0) { // PM_REMOVE
            _ = DispatchMessageW(&msg);
        }
        return self.queue.take();
    }

    pub fn present(self: *Window, frame: Canvas) void {
        std.debug.assert(frame.width == self.width and frame.height == self.height);
        const info: BITMAPINFO = .{
            .bmiHeader = .{
                .biWidth = self.width,
                .biHeight = -@as(i32, self.height), // altura negativa: linhas de cima para baixo
            },
        };
        const w: c_int = self.width;
        const h: c_int = self.height;
        _ = StretchDIBits(self.hdc, 0, 0, w, h, 0, 0, w, h, frame.pixels.ptr, &info, 0, 0x00CC0020); // DIB_RGB_COLORS, SRCCOPY
    }
};
