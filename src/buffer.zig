const std = @import("std");

const Buffer = @This();

allocator: std.mem.Allocator,
line_count: usize,
file_path: ?[]u8,
data: ?[]u8,
data_lines: ?std.ArrayList([]u8),

pub fn read(self: *Buffer, file_path: []u8) !void {
    const max_size = std.math.maxInt(usize);
    const file_data = try std.fs.cwd().readFileAlloc(
        self.allocator,
        file_path,
        max_size,
    );

    // separate into lines
    var file_line_data = std.ArrayList([]u8).init(self.allocator);
    var start_new_line: usize = 0;
    for (file_data, 0..) |byte, i| {
        if (byte == '\n') {
            // NOTE: we dont +1 because we don't want the newline byte
            try file_line_data.append(file_data[start_new_line..i]);
            start_new_line = i + 1;
        }
    }

    // cache values
    self.file_path = file_path;
    self.data = file_data;
    self.data_lines = file_line_data;
    self.line_count = file_line_data.items.len;
}

test "read" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        _ = gpa.detectLeaks();
        _ = gpa.deinit();
    }
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const alloc = arena.allocator();

    var buffer = Buffer{
        .allocator = alloc,
        .line_count = 0,
        .file_path = null,
        .data = null,
        .data_lines = null,
    };

    // case 1
    var open_file_path = try std.fs.cwd().realpathAlloc(alloc, "./src/buffer.zig");
    try buffer.read(open_file_path);
    try std.testing.expect(buffer.data_lines.?.items.len > 90);

    // case 2
    open_file_path = try std.fs.cwd().realpathAlloc(
        alloc,
        "./src/fixtures/case-md.md",
    );
    try buffer.read(open_file_path);
    try std.testing.expectEqual(buffer.data_lines.?.items.len, 20);
    try std.testing.expectEqualDeep(
        buffer.data_lines.?.items[0],
        "# My Sample Markdown File",
    );
    try std.testing.expectEqualDeep(buffer.data_lines.?.items[12], "## Code Example");
    try std.testing.expectEqualDeep(buffer.data_lines.?.items[19], "```");

    // case 3
    open_file_path = try std.fs.cwd().realpathAlloc(
        alloc,
        "./src/fixtures/tiny.txt",
    );

    try buffer.read(open_file_path);
    try std.testing.expectEqual(buffer.data_lines.?.items.len, 2);
    try std.testing.expectEqualDeep(buffer.data_lines.?.items[0], "1234");
    try std.testing.expectEqualDeep(buffer.data_lines.?.items[1], "567");
}
