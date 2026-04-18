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
            // .metadata_path = b.path(metadata_path),
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
        const points_data = run.addOutputFileArg("map_data.bin");
        const metadata = run.addOutputFileArg("metadata.json");

        const install_bin = self.b.addInstallFile(points_data, "bin/map_data.bin");
        self.b.getInstallStep().dependOn(&install_bin.step);

        const install_metadata = self.b.addInstallFile(metadata, "bin/metadata.json");
        self.b.getInstallStep().dependOn(&install_metadata.step);

        install_bin.step.dependOn(&run.step);
        install_metadata.step.dependOn(&run.step);
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
