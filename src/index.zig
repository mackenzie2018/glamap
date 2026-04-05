pub extern fn compileLinkProgram(vs: [*]const u8, vs_len: usize, fs: [*]const u8, fs_len: usize) i32;
pub extern fn bind2DFloat32Data(data: [*]const f32, data_len: usize) i32;
pub extern fn glBindVertexArray(vao: i32) void;
pub extern fn glClearColor(r: f32, g: f32, b: f32, a: f32) void;
pub extern fn glClear(mask: i32) void;
pub extern fn glUseProgram(program: i32) void;
pub extern fn glDrawArrays(mode: i32, first: i32, last: i32) void;
pub extern fn glPointSize(size: f32) void;
//
//
// Taken from web sys rust defintions...
const COLOR_BUFFER_BIT: comptime_int = 16384;
const TRIANGLE_STRIP: comptime_int = 5;
const LINE_STRIP: comptime_int = 3;
const POINTS: u32 = 0;

pub export fn add(a: i32, b: i32) i32 {
    return a + b;
}

pub export fn run() void {
    const vs_source =
        \\ attribute vec4 aVertexPosition;
        \\ void main() {
        \\   gl_Position = aVertexPosition;
        \\   gl_PointSize = 10.0;
        \\ }
    ;

    const fs_source =
        \\ void main() {
        \\   gl_FragColor = vec4(0.0, 0.0, 1.0, 1.0);
        \\ }
    ;
    const program = compileLinkProgram(vs_source, vs_source.len, fs_source, fs_source.len);
    const positions: []const f32 = &.{
        0.5,
        0.5,
        -0.5,
        0.5,
        0.5,
        -0.5,
    };
    const vao = bind2DFloat32Data(positions.ptr, positions.len);

    glBindVertexArray(vao);
    glClearColor(1.0, 1.0, 0.0, 1.0);
    glClear(COLOR_BUFFER_BIT);
    glUseProgram(program);
    {
        const offset = 0;
        const vertexCount = 3;
        glDrawArrays(POINTS, offset, vertexCount);
    }
}
