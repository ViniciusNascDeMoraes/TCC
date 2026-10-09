const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raylib_dep = b.dependency("raylib", .{
        .target = target,
        .optimize = optimize,
    });

    // Imagens e sons ficam embutidos no executavel (ver res/assets.zig).
    const assets = b.createModule(.{
        .root_source_file = b.path("res/assets.zig"),
    });

    const exe = b.addExecutable(.{
        .name = "vacina",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "raylib", .module = raylib_dep.module("raylib") },
                .{ .name = "assets", .module = assets },
            },
        }),
    });
    // No Windows, builds otimizados abrem sem a janela de console; o Debug
    // mantem o console para o log de FPS.
    if (target.result.os.tag == .windows and optimize != .Debug) {
        exe.subsystem = .windows;
    }
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Compila e executa o jogo");
    run_step.dependOn(&run_cmd.step);

    // Testes da logica pura (sem janela nem audio); usam os assets reais.
    const test_step = b.step("test", "Executa os testes de logica do jogo");
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tests.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "assets", .module = assets },
            },
        }),
    });
    test_step.dependOn(&b.addRunArtifact(tests).step);
}
