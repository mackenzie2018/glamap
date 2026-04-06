std = @import("std");

const Builder = struct {
    b: *std.Build,
    opt: std.builtin.OptimizeMode,
    target: std.Build.ResolvedTarget,
    wasm_target: std.Build.ResolvedTarget,
    // check_step: *std.Build.Step,
    // wasm_step: *std.Build.Step,
    // pp_step: *std.Build.Step,
    // lto: ?bool,


    fn generateMapData(self: *Builder) std.Build.LazyPath {
        const exe = self.b.addExecutable(.{
            .name = "preprocess",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/preprocess_data.zig");
                .target = self.target,
                .optimize = .ReleaseFast,
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
            .root_module = b.createModule(.{
                .root_source_file = self.b.path("src/index.zig"),
                .target = self.wasm_target,
                .optimize = self.opt,
            }),
        });
        wasm.entry = disabled;
        wasm.rdynamic = true;
        wasm.root_module.addAnonymouseImport("map_data", .{
            .root_source_file = map_data,
        });

        self.b.installArtifact(wasm);
    }

}


pub fn build(b: *std.Build) void {
    var builder = Builder.init(b);
    const map_data = builder.generateMapData();
    builder.buildApp(map_data);
}
