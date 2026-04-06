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

const vs_source = @embedFile("vertex.glsl");
const fs_source = @embedFile("fragment.glsl");
const lat_centre_key = "lat_centre";
const lon_centre_key = "lon_centre";

pub export fn run() void {
    const program = compileLinkProgram(vs_source, vs_source.len, fs_source, fs_source.len);
    const vao = bind2DFloat32Data(&map_data.points, map_data.points.len);
    glBindVertexArray(vao);
    glClearColor(0.0, 0.0, 0.0, 1.0);
    glClear(Gl.COLOR_BUFFER_BIT);

    glUseProgram(program);
    const lat_centre = glGetUniformLoc(program, lat_centre_key, lat_centre_key.len);
    const lon_centre = glGetUniformLoc(program, lon_centre_key, lon_centre_key.len);
    glUniform1f(lat_centre, 55.66385);
    glUniform1f(lon_centre, 4.724538);
    {
        const offset = 0;
        const vertexCount = map_data.points.len / 2;
        glDrawArrays(Gl.POINTS, offset, vertexCount);
    }
}
