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

const GlobalState = struct {
    mouse_down: bool = false,
    mouse_down_x: f32 = 0.0,
    mouse_down_y: f32 = 0.0,
    lat_centre: f32 = MAP_DATA.min_lat + (MAP_DATA.max_lat - MAP_DATA.min_lat) / 2.0,
    lon_centre: f32 = MAP_DATA.min_lon + (MAP_DATA.max_lon - MAP_DATA.min_lon) / 2.0,
    lat_centre_loc: i32 = 0,
    lon_centre_loc: i32 = 0,
    program: i32 = 0,
    vao: i32 = 0,
};
var global = GlobalState{};

pub export fn mouseDown(x_norm: f32, y_norm: f32) void {
    global.mouse_down = true;
    global.mouse_down_x = x_norm;
    global.mouse_down_y = y_norm;
    render();
}

pub export fn mouseMove(x_norm: f32, y_norm: f32) void {
    if (!global.mouse_down) {
        return;
    }
    const scale = 1;
    global.lon_centre += (x_norm - global.mouse_down_x) * scale * -1.0;
    global.lat_centre += (y_norm - global.mouse_down_y) * scale;
    global.mouse_down_x = x_norm;
    global.mouse_down_y = y_norm;
    render();
}

pub export fn init_program() void {
    logWasm(map_data_arr.items.ptr, 1000);
    global.program = compileLinkProgram(vs_source, vs_source.len, fs_source, fs_source.len);
    const map_data_f32: []const f32 = @alignCast(std.mem.bytesAsSlice(f32, map_data_arr.items));
    global.vao = bind2DFloat32Data(map_data_f32.ptr, map_data_f32.len);
    global.lat_centre_loc = glGetUniformLoc(global.program, lat_centre_key, lat_centre_key.len);
    global.lon_centre_loc = glGetUniformLoc(global.program, lon_centre_key, lon_centre_key.len);
}

pub export fn render() void {
    const map_data_f32: []const f32 = @alignCast(std.mem.bytesAsSlice(f32, map_data_arr.items));
    glBindVertexArray(global.vao);
    glClearColor(0.0, 0.0, 0.0, 1.0);
    glClear(Gl.COLOR_BUFFER_BIT);

    glUseProgram(global.program);
    glUniform1f(global.lat_centre_loc, global.lat_centre);
    glUniform1f(global.lon_centre_loc, global.lon_centre);
    {
        const offset = 0;
        const vertexCount = map_data_f32.len / 2;
        glDrawArrays(Gl.POINTS, offset, @intCast(vertexCount));
    }
}
