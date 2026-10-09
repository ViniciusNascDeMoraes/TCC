//! `Camera.Camera`: deslocamento da visao sobre o mapa.

const std = @import("std");

pub const Camera = struct {
    x: i32 = 0,
    y: i32 = 0,

    /// `Camera.clamp`: limita primeiro pelo minimo e depois pelo maximo.
    pub fn clamp(atual: i32, min: i32, max: i32) i32 {
        var value = atual;
        if (value < min) value = min;
        if (value > max) value = max;
        return value;
    }
};

test "clamp" {
    try std.testing.expectEqual(@as(i32, 0), Camera.clamp(-5, 0, 10));
    try std.testing.expectEqual(@as(i32, 10), Camera.clamp(15, 0, 10));
    try std.testing.expectEqual(@as(i32, 7), Camera.clamp(7, 0, 10));
    // Maximo menor que o minimo: vence o maximo, como no Java.
    try std.testing.expectEqual(@as(i32, -3), Camera.clamp(5, 0, -3));
}
