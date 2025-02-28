const std = @import("std");
const tree_sitter = @import("./tree_sitter.zig");

const Buffer = @This();

allocator: std.mem.Allocator,
line_count: usize,
syntax: ?[]u8,
file_path: ?[]u8,
data: ?[]u8,
data_tree: ?*tree_sitter.Tree,
data_lines: ?std.ArrayList(Line),

pub const Line = struct {
    data: []u8,
    len: usize,
    number: usize,
};

pub fn init(alloc: std.mem.Allocator) !*Buffer {
    const buffer = try alloc.create(Buffer);
    buffer.* = Buffer{
        .allocator = alloc,
        .line_count = 0,
        .syntax = null,
        .file_path = null,
        .data = null,
        .data_tree = null,
        .data_lines = null,
    };

    return buffer;
}

pub fn deinit(self: *Buffer) void {
    if (self.data_tree) |tree| {
        tree.destroy();
    }
}

pub fn read(self: *Buffer, file_path: []u8) !void {
    const max_size = std.math.maxInt(usize);
    const file_data = try std.fs.cwd().readFileAlloc(
        self.allocator,
        file_path,
        max_size,
    );

    // separate into lines
    var file_line_data = std.ArrayList(Line).init(self.allocator);
    var start_new_line: usize = 0;
    for (file_data, 0..) |byte, i| {
        if (byte != '\n') {
            continue;
        }

        // NOTE: we dont +1 because we don't want the newline byte
        const line_raw = file_data[start_new_line..i];
        try file_line_data.append(Line{
            .data = line_raw,
            .len = line_raw.len,
            .number = file_line_data.items.len,
        });
        start_new_line = i + 1;
    }

    // TODO: we should dupe so we have the original since later we need to save
    // TODO: we should probably have transformation changes so we can re-enact
    //       later (undo, redo)

    // cache values
    self.file_path = file_path;
    self.data = file_data;
    self.data_lines = file_line_data;
    self.line_count = file_line_data.items.len;
    self.syntax = @constCast(std.fs.path.extension(file_path));

    // TODO: handle syntax special cases like Makefile

    // TODO: we should do tree sitter but async
    //       we need to do it on every single change
    // TODO: this doesn't do much, we want it to test
    // TODO: need to actually get the syntax out of the file
    //       maybe a map for each file extension we can think of
    //       maybe that should be within tree sitter
    // TODO: should be able to set the syntax manually
    if (self.syntax) |syntax| {
        const tree = try tree_sitter.parseCode(file_data, syntax);
        try tree_sitter.getHighlight(self.allocator, tree, syntax);

        self.data_tree = tree;
    }
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
