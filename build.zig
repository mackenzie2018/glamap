const std = @import("std");

pub fn build(b: *std.Build) void {
    const opt = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});
    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding, // or .wasi if you want WASI support
    });

    const wasm = b.addExecutable(.{
        .name = "index",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/index.zig"),
            .target = wasm_target,
            .optimize = opt,
        }),
    });

    wasm.entry = .disabled;
    wasm.rdynamic = true;
    wasm.stack_size = 16384;

    b.installArtifact(wasm);

    const preprocess = b.addExecutable(.{
        .name = "preprocess",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/preprocess_data.zig"),
            .target = target,
            .optimize = opt,
        }),
    });
    preprocess.linkSystemLibrary("expat");
    preprocess.linkLibC();

    b.installArtifact(preprocess);
}
