//! Saida de audio no Windows pelo waveOut (winmm.dll), declarado aqui mesmo
//! em Zig. Quatro buffers de 10 ms circulam entre a thread de audio e o
//! driver: cada um que volta (WHDR_DONE) e preenchido de novo pelo mixer.

const std = @import("std");
const wav = @import("../wav.zig");
const Mixer = @import("../mixer.zig").Mixer;

const log = std.log.scoped(.audio);

const BOOL = c_int;
const UINT = c_uint;
const DWORD = u32;
const MMRESULT = UINT;
const HANDLE = *anyopaque;
const HWAVEOUT = *opaque {};

const WAVEFORMATEX = extern struct {
    wFormatTag: u16,
    nChannels: u16,
    nSamplesPerSec: u32,
    nAvgBytesPerSec: u32,
    nBlockAlign: u16,
    wBitsPerSample: u16,
    cbSize: u16,
};

const WAVEHDR = extern struct {
    lpData: [*]u8,
    dwBufferLength: DWORD,
    dwBytesRecorded: DWORD = 0,
    dwUser: usize = 0,
    dwFlags: DWORD = 0,
    dwLoops: DWORD = 0,
    lpNext: ?*WAVEHDR = null,
    reserved: usize = 0,
};

extern "winmm" fn waveOutOpen(handle: *?HWAVEOUT, device: UINT, format: *const WAVEFORMATEX, callback: usize, instance: usize, flags: DWORD) callconv(.winapi) MMRESULT;
extern "winmm" fn waveOutPrepareHeader(handle: HWAVEOUT, header: *WAVEHDR, size: UINT) callconv(.winapi) MMRESULT;
extern "winmm" fn waveOutUnprepareHeader(handle: HWAVEOUT, header: *WAVEHDR, size: UINT) callconv(.winapi) MMRESULT;
extern "winmm" fn waveOutWrite(handle: HWAVEOUT, header: *WAVEHDR, size: UINT) callconv(.winapi) MMRESULT;
extern "winmm" fn waveOutReset(handle: HWAVEOUT) callconv(.winapi) MMRESULT;
extern "winmm" fn waveOutClose(handle: HWAVEOUT) callconv(.winapi) MMRESULT;
extern "kernel32" fn CreateEventW(attributes: ?*anyopaque, manual_reset: BOOL, initial_state: BOOL, name: ?[*:0]const u16) callconv(.winapi) ?HANDLE;
extern "kernel32" fn WaitForSingleObject(handle: HANDLE, milliseconds: DWORD) callconv(.winapi) DWORD;
extern "kernel32" fn CloseHandle(handle: HANDLE) callconv(.winapi) BOOL;

const WAVE_MAPPER = 0xFFFFFFFF;
const CALLBACK_EVENT = 0x00050000;
const WHDR_DONE = 0x1;

const buffer_count = 4;
/// 10 ms por buffer: um som pedido sai em no maximo ~40 ms, como no Linux.
const buffer_frames = wav.sample_rate / 100;

/// O waveOut nao precisa de nada preparado na thread principal.
pub const Config = struct {};

pub fn prepare(gpa: std.mem.Allocator, io: std.Io, env: *const std.process.Environ.Map) Config {
    _ = gpa;
    _ = io;
    _ = env;
    return .{};
}

/// Corpo da thread de audio: termina quando `running` vira falso.
pub fn run(config: *const Config, mixer: *Mixer, running: *const std.atomic.Value(bool)) void {
    _ = config;
    const event = CreateEventW(null, 0, 0, null) orelse return;
    defer _ = CloseHandle(event);

    const format: WAVEFORMATEX = .{
        .wFormatTag = 1, // PCM
        .nChannels = wav.channels,
        .nSamplesPerSec = wav.sample_rate,
        .nAvgBytesPerSec = wav.sample_rate * wav.bytes_per_frame,
        .nBlockAlign = wav.bytes_per_frame,
        .wBitsPerSample = 16,
        .cbSize = 0,
    };
    var device: ?HWAVEOUT = null;
    if (waveOutOpen(&device, WAVE_MAPPER, &format, @intFromPtr(event), 0, CALLBACK_EVENT) != 0) {
        log.warn("sem dispositivo de audio: o jogo fica sem som", .{});
        return;
    }
    const out = device.?;
    defer _ = waveOutClose(out);

    var samples: [buffer_count][buffer_frames * wav.channels]i16 = undefined;
    var headers: [buffer_count]WAVEHDR = undefined;
    for (&headers, &samples) |*h, *s| {
        h.* = .{ .lpData = std.mem.sliceAsBytes(s).ptr, .dwBufferLength = @sizeOf(@TypeOf(s.*)) };
        _ = waveOutPrepareHeader(out, h, @sizeOf(WAVEHDR));
        mixer.render(s);
        _ = waveOutWrite(out, h, @sizeOf(WAVEHDR));
    }

    while (running.load(.acquire)) {
        _ = WaitForSingleObject(event, 100);
        // Varios buffers podem ter voltado entre um sinal e outro.
        for (&headers, &samples) |*h, *s| {
            if (h.dwFlags & WHDR_DONE == 0) continue;
            mixer.render(s);
            _ = waveOutWrite(out, h, @sizeOf(WAVEHDR));
        }
    }

    _ = waveOutReset(out);
    for (&headers) |*h| _ = waveOutUnprepareHeader(out, h, @sizeOf(WAVEHDR));
}
