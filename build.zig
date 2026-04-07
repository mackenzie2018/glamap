const std = @import("std");

const Builder = struct {
    b: *std.Build,
    opt: std.builtin.OptimizeMode,
    target: std.Build.ResolvedTarget,
    osm_path: std.Build.LazyPath,
    wasm_target: std.Build.ResolvedTarget,

    fn init(b: *std.Build) Builder {
        const osm_path = b.option([]const u8, "osm_path", "file containing osm data for Glasgow") orelse {
            std.log.err("Cannot build without osm data, please use -Dosm_path=<...>", .{});
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

    fn generateMapData(self: *Builder) void {
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
        const map_json = run.captureStdOut();
        const install_json_step = self.b.addInstallFile(map_json, "bin/map_data.json");
        install_json_step.step.dependOn(&run.step);
        self.b.getInstallStep().dependOn(&install_json_step.step);
        // run.step.dependOn(&exe.step);
        // const map_json = run.captureStdOut();
        // const renamed = self.b.addWriteFiles();
        // const map_json_renamed = renamed.addCopyFile(map_json, "map_data.zig");
        // const map_data_lib = self.b.addLibrary(.{
        //     .name = "map_data",
        //     .linkage = .static,
        //     .root_module = self.b.createModule(.{
        //         .root_source_file = map_json_renamed,
        //         .target = self.wasm_target,
        //         .optimize = self.opt,
        //     }),
        // });
        // map_data_lib.step.dependOn(&run.step);
        // return .{ map_data_lib, run };
    }

    fn buildApp(self: *Builder) void {
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
        // wasm.step.dependOn(&run.step); // ensure preprocess runs first

        self.b.installArtifact(wasm);
    }
};

pub fn build(b: *std.Build) void {
    var builder = Builder.init(b);
    builder.generateMapData();
    builder.buildApp();
}
