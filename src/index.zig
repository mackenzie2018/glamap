const std = @import("std");
const map_data = @import("map_data.zig");
pub extern fn compileLinkProgram(vs: [*]const u8, vs_len: usize, fs: [*]const u8, fs_len: usize) i32;
pub extern fn bind2DFloat32Data(data: [*]const f32, data_len: usize) i32;
pub extern fn glBindVertexArray(vao: i32) void;
pub extern fn glClearColor(r: f32, g: f32, b: f32, a: f32) void;
pub extern fn glClear(mask: i32) void;
pub extern fn glUseProgram(program: i32) void;
pub extern fn glDrawArrays(mode: i32, first: i32, last: i32) void;
pub extern fn glPointSize(size: f32) void;
pub extern fn glGetUniformLoc(program: i32, name: [*]const u8, name_len: usize) i32;
pub extern fn glUniform1f(loc: i32, value: f32) void;

const Gl = struct {
    const COLOR_BUFFER_BIT: comptime_int = 16384;
    const TRIANGLE_STRIP: comptime_int = 5;
    const LINE_STRIP: comptime_int = 3;
    const POINTS: u32 = 0;
};

const MAP_DATA = struct {
    const min_lat: f32 = 55.663848876953125;
    const max_lat: f32 = 56.32396697998047;
    const min_lon: f32 = -4.7245378494262695;
    const max_lon: f32 = -3.783839225769043;
};

const vs_source = @embedFile("vertex.glsl");
const fs_source = @embedFile("fragment.glsl");
const lat_centre_key = "lat_centre";
const lon_centre_key = "lon_centre";

pub extern fn logWasm(s: [*]u8, len: usize) void;

var map_data_arr = std.ArrayList(u8).empty;
pub export var global_chunk: [16384]u8 = undefined;

// Call this once from JS before pushing any data
pub export fn init() void {
    map_data_arr.ensureTotalCapacity(std.heap.wasm_allocator, 5_000_000) catch unreachable;
}

pub export fn pushData(len: usize) void {
    map_data_arr.appendSlice(std.heap.wasm_allocator, global_chunk[0..len]) catch unreachable;
}

pub export fn run() void {
    logWasm(map_data_arr.items.ptr, 1000);
    const program = compileLinkProgram(vs_source, vs_source.len, fs_source, fs_source.len);
    const map_data_f32: []const f32 = @alignCast(std.mem.bytesAsSlice(f32, map_data_arr.items));
    const vao = bind2DFloat32Data(map_data_f32.ptr, map_data_f32.len);
    glBindVertexArray(vao);
    glClearColor(0.0, 0.0, 0.0, 1.0);
    glClear(Gl.COLOR_BUFFER_BIT);

    glUseProgram(program);
    const lat_centre = glGetUniformLoc(program, lat_centre_key, lat_centre_key.len);
    const lon_centre = glGetUniformLoc(program, lon_centre_key, lon_centre_key.len);
    _ = MAP_DATA.min_lat + ((MAP_DATA.max_lat - MAP_DATA.min_lat) / 2);
    _ = MAP_DATA.min_lon + ((MAP_DATA.max_lon - MAP_DATA.min_lon) / 2);
    glUniform1f(lat_centre, 55.66385);
    glUniform1f(lon_centre, 4.724538);
    {
        const offset = 0;
        const vertexCount = map_data_f32.len / 2;
        glDrawArrays(Gl.POINTS, offset, @intCast(vertexCount));
    }
}
