const std = @import("std");

const max_file_buffer_size = 50000;

pub fn readFile(
    allocator: std.mem.Allocator,
    absolute_path: []u8,
) !std.ArrayList([]const u8) {
    const file = try std.fs.openFileAbsolute(absolute_path, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();
    var file_line_data = std.ArrayList([]const u8).init(allocator);

    // go line by line on the file caching it
    var buf: [max_file_buffer_size]u8 = undefined;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        const duped = try allocator.dupe(u8, line);
        try file_line_data.append(duped);
    }

    return file_line_data;
}

test "readFile" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        _ = gpa.detectLeaks();
        _ = gpa.deinit();
    }
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const alloc = arena.allocator();
    const cwd = try std.fs.cwd().realpathAlloc(alloc, ".");

    // case 1
    var open_file_path = try std.fs.path.join(alloc, &[_][]const u8{
        cwd,
        "src/buffer.zig",
    });

    var res = try readFile(alloc, open_file_path);
    try std.testing.expect(res.items.len > 40);

    // case 2
    open_file_path = try std.fs.path.join(alloc, &[_][]const u8{
        cwd,
        "src/main.zig",
    });

    res = try readFile(alloc, open_file_path);
    try std.testing.expect(res.items.len > 40);

    // case 3
    open_file_path = try std.fs.path.join(alloc, &[_][]const u8{
        cwd,
        "build.zig",
    });

    res = try readFile(alloc, open_file_path);
    try std.testing.expect(res.items.len > 40);
}
