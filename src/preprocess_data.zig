const std = @import("std");
const c = @cImport({
    @cInclude("expat.h");
});

const UserData = struct {
    stdout: std.io.Writer,
    num_nodes: u64 = 0,
};

pub fn startElement(ctx: ?*anyopaque, name_c: [*c]const c.XML_Char, attrs: [*c][*c]const c.XML_Char) callconv(.c) void {
    // _ = user_data;
    // _ = name_c;
    _ = attrs;
    //   int i;
    //   struct parser_data *parser_data = (struct parser_data *)userData;
    //   (void)atts;
    //
    const user_data: *UserData = @ptrCast(@alignCast(ctx));
    const name = std.mem.span(name_c);
    if (std.mem.eql(u8, name, "node")) {
        user_data.num_nodes += 1;
    }
    //   if (strcmp("node", name) == 0) {
    //     parser_data->num_nodes += 1;
    //   } else if (strcmp("way", name) == 0) {
    //     parser_data->num_ways += 1;
    //   } else if (strcmp("nd", name) == 0) {
    //     parser_data->node_refs += 1;
    //   }
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

    // const stdout_writer = std.io.std().writer();
    var stdout_buf: [4096]u8 = undefined;
    var stdout_buf_writer = std.fs.File.stdout().writer(&stdout_buf);
    defer stdout_buf_writer.end() catch {
        unreachable;
    };
    var stdout_writer = stdout_buf_writer.interface;
    try stdout_writer.writeAll(
        \\ const Point = struct {
        \\   long: f32,
        \\   lat: f32,
        \\ };
        \\ 
        \\ const points = [_]Point {
    );
    defer stdout_writer.writeAll(
        \\ };
    ) catch unreachable;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();
    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    // const f = std.fs.cwd().openFile(args[1], .{});
    // const buffered_reader = std.io.Reader.buffered(try f.Reader());

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
        if (i % 1000 == 0) {
            std.debug.print(
                "{d}\n",
                .{user_data.num_nodes},
            );
        }
        //   int i = 0;
        //   do {
        //     i += 1;
        //     if (i == 3000000) {
        //       break;
        //     }
        //     if (i % 1000 == 0) {
        //       printf("nodes: %lu\tways: %lu\trefs: %lu\n", data.num_nodes,
        //              data.num_ways, data.node_refs);
        //     }
        const BUF_SIZE = 4096;
        const buf = c.XML_GetBuffer(parser, BUF_SIZE);
        if (buf == null) {
            return error.NoBuffer;
        }
        //     void *const buf = XML_GetBuffer(parser, BUFSIZ);
        //     if (!buf) {
        //       fprintf(stderr, "Couldn't allocate memory for buffer\n");
        //       XML_ParserFree(parser);
        //       return 1;
        //     }
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
        //     if (XML_ParseBuffer(parser, (int)len, done) == XML_STATUS_ERROR) {
        //       fprintf(stderr,
        //               "Parse error at line %" XML_FMT_INT_MOD "u:\n%" XML_FMT_STR "\n",
        //               XML_GetCurrentLineNumber(parser),
        //               XML_ErrorString(XML_GetErrorCode(parser)));
        //       XML_ParserFree(parser);
        //       return 1;
        //     }
        //   } while (!done);
        //
        //   printf("nodes: %lu\tways: %lu\trefs: %lu\n", data.num_nodes, data.num_ways,
        //          data.node_refs);
        //
        //   XML_ParserFree(parser);
        //   return 0;
        // }
        //
    }
}
