const std = @import("std");
const c = @cImport({
    @cInclude("expat.h");
});

const UserData = struct {
    stdout: *std.io.Writer,
    num_nodes: u64 = 0,
    min_lat: f32 = std.math.floatMax(f32),
    max_lat: f32 = -std.math.floatMax(f32),
    min_lon: f32 = std.math.floatMax(f32),
    max_lon: f32 = -std.math.floatMax(f32),
};

pub fn startElement(ctx: ?*anyopaque, name_c: [*c]const c.XML_Char, attrs: [*c][*c]const c.XML_Char) callconv(.c) void {
    const user_data: *UserData = @ptrCast(@alignCast(ctx));
    const name = std.mem.span(name_c);
    if (!std.mem.eql(u8, name, "node")) {
        return;
    }

    var i: usize = 0;
    var lat_opt: ?[]const u8 = null;
    var lon_opt: ?[]const u8 = null;
    while (true) {
        defer i += 2;
        if (attrs[i] == null) {
            break;
        }

        const field_name = std.mem.span(attrs[i]);
        const field_val = std.mem.span(attrs[i + 1]);

        if (std.mem.eql(u8, field_name, "lat")) {
            lat_opt = field_val;
        } else if (std.mem.eql(u8, field_name, "lon")) {
            lon_opt = field_val;
        }
    }

    const lat_s = lat_opt orelse return;
    const lon_s = lon_opt orelse return;
    const lat = std.fmt.parseFloat(f32, lat_s) catch return;
    const lon = std.fmt.parseFloat(f32, lon_s) catch return;

    user_data.max_lon = @max(lon, user_data.max_lon);
    user_data.min_lon = @min(lon, user_data.min_lon);
    user_data.max_lat = @max(lat, user_data.max_lat);
    user_data.min_lat = @min(lat, user_data.min_lat);

    user_data.stdout.print(
        \\ {}, {},
        \\
    , .{ lon, lat }) catch return;

    if (std.mem.eql(u8, name, "node")) {
        user_data.num_nodes += 1;
    }
}

// static void XMLCALL endElement(void *userData, const XML_Char *name) {
//   // int *const depthPtr = (int *)userData;
//   // (void)name;
//   //
//   // *depthPtr -= 1;
// }
//
pub fn main() !void {
    const parser = c.XML_ParserCreate(null);
    defer c.XML_ParserFree(parser);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var stdout_buf: [4096]u8 = undefined;
    var stdout_file = std.fs.File.stdout();
    var stdout_buf_writer = stdout_file.writer(&stdout_buf);
    defer stdout_buf_writer.end() catch |err| {
        std.debug.print("ERROR while flush stdout_buf_writer: {}\n", .{err});
    };
    var stdout_writer = &stdout_buf_writer.interface;
    try stdout_writer.writeAll(
        \\ pub const points = [_]f32 {
        \\
    );

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    const f = try std.fs.cwd().openFile(args[1], .{});
    defer f.close();

    var read_buf: [4096]u8 = undefined;
    var f_reader = f.reader(&read_buf);
    const buffered_reader = &f_reader.interface;

    if (parser == null) {
        return error.NoParser;
    }

    var user_data = UserData{
        .stdout = stdout_writer,
    };
    c.XML_SetUserData(parser, &user_data);
    c.XML_SetElementHandler(parser, startElement, null);
    //   XML_SetElementHandler(parser, startElement, endElement);
    //
    var i: u64 = 0;
    while (true) {
        i += 1;
        if (i == 100000) {
            break;
        }
        const BUF_SIZE = 4096;
        const buf = c.XML_GetBuffer(parser, BUF_SIZE);
        if (buf == null) {
            return error.NoBuffer;
        }
        const buf_u8: [*]u8 = @ptrCast(buf);
        const buf_slice = buf_u8[0..BUF_SIZE];
        const read_data_len = try buffered_reader.readSliceShort(buf_slice);
        // const read_data_len = buffered_reader.read(buf_slice);
        if (read_data_len == 0) {
            break;
        }

        const parse_ret = c.XML_ParseBuffer(parser, @intCast(read_data_len), 0);
        if (parse_ret == c.XML_STATUS_ERROR) {
            return error.ParseError;
        }
    }
    try stdout_writer.print(
        \\ 
        \\ }};
        \\ 
        \\ pub const min_lat = {d};
        \\ pub const max_lat = {d};
        \\ pub const min_lon = {d};
        \\ pub const max_lon = {d};
        \\ 
    , .{ user_data.min_lat, user_data.max_lat, user_data.min_lon, user_data.max_lon });
}
