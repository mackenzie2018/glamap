const std = @import("std");
const c = @cImport({
    @cInclude("expat.h");
});
const builtin = @import("builtin");

// const metadata_out: *std.json.Stringify,
// New Strategy: Two outputs from the application:
//  1. Metadata is written to json file
//  2. Points data is written as native / binary floating point data.

const UserData = struct {
    points_out: *std.Io.Writer,
    metadata_out: *std.json.Stringify,
    num_nodes: u64 = 0,
    min_lat: f32 = std.math.floatMax(f32),
    max_lat: f32 = -std.math.floatMax(f32),
    min_lon: f32 = std.math.floatMax(f32),
    max_lon: f32 = -std.math.floatMax(f32),
    lat_fails: u64 = 0,
    lon_fails: u64 = 0,
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
    const lat = std.fmt.parseFloat(f32, lat_s) catch {
        user_data.lat_fails += 1;
        return;
    };
    const lon = std.fmt.parseFloat(f32, lon_s) catch {
        user_data.lon_fails += 1;
        return;
    };

    user_data.max_lon = @max(lon, user_data.max_lon);
    user_data.min_lon = @min(lon, user_data.min_lon);
    user_data.max_lat = @max(lat, user_data.max_lat);
    user_data.min_lat = @min(lat, user_data.min_lat);

    // user_data.points_out.print(
    //     \\ {}, {},
    //     \\
    // , .{ lon, lat }) catch return;

    std.debug.assert(builtin.cpu.arch.endian() == .little);
    user_data.points_out.writeAll(std.mem.asBytes(&lon)) catch unreachable;
    user_data.points_out.writeAll(std.mem.asBytes(&lat)) catch unreachable;

    if (std.mem.eql(u8, name, "node")) {
        user_data.num_nodes += 1;
    }
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const parser = c.XML_ParserCreate(null);
    defer c.XML_ParserFree(parser);

    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    // const alloc = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const args = try init.minimal.args.toSlice(arena.allocator());
    // const args = try std.process.argsAlloc(alloc);
    // defer std.process.argsFree(alloc, args);

    var in_f_buf: [4096]u8 = undefined;
    const in_f = try std.Io.Dir.cwd().openFile(io, args[1], .{});
    // const in_f = try std.fs.cwd().openFile(args[1], .{});
    defer in_f.close(io);
    var in_reader_obj = in_f.reader(io, &in_f_buf);
    var in_reader = &in_reader_obj.interface;

    var out_f_buf: [4096]u8 = undefined;
    const out_f = try std.Io.Dir.cwd().createFile(io, args[2], .{});
    // const out_f = try std.fs.cwd().createFile(args[2], .{});
    var points_out_writer_obj = out_f.writer(io, &out_f_buf);
    const points_out_writer = &points_out_writer_obj.interface;
    defer points_out_writer.flush() catch {};

    var metadata_out_buf: [4096]u8 = undefined;
    const metadata_out_f = try std.Io.Dir.cwd().createFile(io, args[3], .{});
    // const metadata_out_f = try std.fs.cwd().createFile(args[3], .{});
    defer metadata_out_f.close(io);
    var metadata_out_writer_obj = metadata_out_f.writer(io, &metadata_out_buf);
    const metadata_out_writer = &metadata_out_writer_obj.interface;
    defer metadata_out_writer.flush() catch {};

    var json_writer: std.json.Stringify = .{
        .writer = metadata_out_writer,
        .options = .{ .whitespace = .indent_2 },
    };

    if (parser == null) {
        return error.NoParser;
    }
    var user_data = UserData{
        .points_out = points_out_writer,
        .metadata_out = &json_writer,
    };

    c.XML_SetUserData(parser, &user_data);
    c.XML_SetElementHandler(parser, startElement, null);

    var i: u64 = 0;
    while (true) {
        i += 1;
        const BUF_SIZE = 4096;
        const buf = c.XML_GetBuffer(parser, BUF_SIZE);
        if (buf == null) {
            return error.NoBuffer;
        }
        const buf_u8: [*]u8 = @ptrCast(buf);
        const buf_slice = buf_u8[0..BUF_SIZE];
        const read_data_len = try in_reader.readSliceShort(buf_slice);
        // const read_data_len = buffered_reader.read(buf_slice);
        if (read_data_len == 0) {
            break;
        }

        const parse_ret = c.XML_ParseBuffer(parser, @intCast(read_data_len), 0);
        if (parse_ret == c.XML_STATUS_ERROR) {
            return error.ParseError;
        }
    }
    try user_data.metadata_out.beginObject();
    try user_data.metadata_out.objectField("lat_fails");
    try user_data.metadata_out.write(user_data.lat_fails);
    try user_data.metadata_out.objectField("lon_fails");
    try user_data.metadata_out.write(user_data.lon_fails);
    try user_data.metadata_out.objectField("num_nodes");
    try user_data.metadata_out.write(user_data.num_nodes);
    try user_data.metadata_out.objectField("min_lat");
    try user_data.metadata_out.write(user_data.min_lat);
    try user_data.metadata_out.objectField("max_lat");
    try user_data.metadata_out.write(user_data.max_lat);
    try user_data.metadata_out.objectField("min_lon");
    try user_data.metadata_out.write(user_data.min_lon);
    try user_data.metadata_out.objectField("max_lon");
    try user_data.metadata_out.write(user_data.max_lon);
    try user_data.metadata_out.endObject();
}
