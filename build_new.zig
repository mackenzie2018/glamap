const std = @import("std");

const Builder = struct {
    b: *std.Build,
    opt: std.builtin.OptimizeMode,
    target: std.Build.ResolvedTarget,
    osm_path: std.Build.LazyPath,
    wasm_target: std.Build.ResolvedTarget,

    fn init(b: *std.Build) Builder {
        const osm_path = b.option([]const u8, "osm_data", "file containing osm data for Glasgow") orelse {
            std.log.err("Cannot build without osm data, please use -Dosm_data=<...>");
            std.process.exit(1);
        };

        return .{
            .b = b,
            .opt = b.standardOptimizeOption(.{}),
            .target = b.standardTargetOptions(.{}),
            .wasm_target = b.resolveTargetQuery(.{
                .cpu_arch = .wasm32,
                .os_tag = .freestanding,
            }),
            .osm_path = b.path(osm_path),
        };
    }

    fn generateMapData(self: *Builder) std.Build.LazyPath {
        const exe = self.b.addExecutable(.{
            .name = "preprocess",
            .root_module = self.b.createModule(.{
                .root_source_file = self.b.path("src/preprocess_data.zig"),
                .target = self.target,
                .optimize = self.opt,
            }),
        });
        exe.linkSystemLibrary("expat");
        exe.linkLibC();

        const run = self.b.addRunArtifact(exe);
        run.addFileArg(self.osm_path);
        return run.addOutputFileArg("map_data.zig");
    }

    fn buildApp(self: *Builder, map_data: std.Build.LazyPath) void {
        const wasm = self.b.addExecutable(.{
            .name = "index",
            .root_module = self.b.createModule(.{
                .root_source_file = self.b.path("src/index.zig"),
                .target = self.wasm_target,
                .optimize = self.opt,
            }),
        });

        wasm.entry = .disabled;
        wasm.rdynamic = true;
        wasm.root_module.addAnonymousImport("map_data", .{
            .root_source_file = map_data,
        });
        // wasm.stack_size = 16384;

        self.b.installArtifact(wasm);
    }
};

pub fn build(b: *std.Build) void {
    var builder = Builder.init(b);
    const map_data = builder.generateMapData();
    builder.buildApp(map_data);
}
