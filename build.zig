// 1:07:50
const std = @import("std");

pub fn build(b: *std.Build) void {
    const opt = b.standardOptimizeOption(.{});
    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding, // or .wasi if you want WASI support
    });

    const exe = b.addExecutable(.{
        .name = "index",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/index.zig"),
            .target = wasm_target,
            .optimize = opt,
        }),
    });

    exe.entry = .disabled;
    exe.rdynamic = true;
    exe.stack_size = 16384;

    b.installArtifact(exe);
}
