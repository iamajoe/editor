const std = @import("std");
const ts = @import("tree-sitter");
const debug = @import("./debug.zig");
const tree_sitter = @import("./tree_sitter.zig");

const Buffer = @This();

allocator: std.mem.Allocator,
syntax: ?[]u8,
file_path: ?[]u8,
data: ?[]u8,

// treesitter specific
ts_tree: ?*ts.Tree,
ts_grammar: ?*ts.Language,
ts_highlight_query: ?*ts.Query,
ts_highlight_cursor: ?*ts.QueryCursor,

pub fn init(alloc: std.mem.Allocator) !*Buffer {
    const buffer = try alloc.create(Buffer);
    buffer.* = Buffer{
        .allocator = alloc,
        .syntax = null,
        .file_path = null,
        .data = null,

        // treesitter specific
        .ts_tree = null,
        .ts_grammar = null,
        .ts_highlight_query = null,
        .ts_highlight_cursor = null,
    };

    return buffer;
}

pub fn deinit(self: *Buffer) void {
    if (self.ts_highlight_cursor) |cursor| {
        cursor.destroy();
    }
    if (self.ts_highlight_query) |query| {
        query.destroy();
    }
    if (self.ts_grammar) |grammar| {
        grammar.destroy();
    }
    if (self.ts_tree) |tree| {
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

    // TODO: we should dupe so we have the original since later we need to save
    // TODO: we should probably have transformation changes so we can re-enact
    //       later (undo, redo)

    // cache values
    self.file_path = file_path;
    self.data = file_data;

    try self.update();
}

pub fn update(self: *Buffer) !void {
    if (self.file_path == null or self.data == null) {
        self.syntax = null;

        // treesitter specific
        self.ts_tree = null;
        self.ts_grammar = null;
        self.ts_highlight_query = null;
        self.ts_highlight_cursor = null;
        return;
    }

    self.syntax = @constCast(std.fs.path.extension(self.file_path.?));
    if (self.syntax) |syntax| {
        const tree = try tree_sitter.parseCode(self.data.?, syntax);
        self.ts_tree = tree.tree;
        self.ts_grammar = tree.grammar;
        self.ts_highlight_query = tree.highlight_query;
        self.ts_highlight_cursor = null;
    } else {
        self.ts_tree = null;
        self.ts_grammar = null;
        self.ts_highlight_query = null;
        self.ts_highlight_cursor = null;
    }
}

pub fn highlightAt(self: *Buffer, row: usize, col: usize) !tree_sitter.TSTokenType {
    // TODO: we are redoing this over and over, there must be a better way
    //       can't we just reset the highlight cursor?!
    //       tried already to only run it once but for some reason
    //       the buffer is not resetting. need to figure why
    if (self.ts_highlight_cursor) |cursor| {
        cursor.destroy();
    }

    self.ts_highlight_cursor = tree_sitter.getHighlightCursor(
        self.ts_tree,
        self.ts_highlight_query,
    );

    // TODO: if we can't reset the cursor, maybe we can redo the highlight
    //       one per update

    if (self.ts_highlight_cursor) |cursor| {
        return try tree_sitter.highlightAt(cursor, row, col);
    }

    return tree_sitter.TSTokenType.none;
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

    var buffer = init(alloc);

    // case 1
    var open_file_path = try std.fs.cwd().realpathAlloc(alloc, "./src/buffer.zig");
    try buffer.read(open_file_path);
    // try std.testing.expect(buffer.data_lines.?.items.len > 90);

    // case 2
    open_file_path = try std.fs.cwd().realpathAlloc(
        alloc,
        "./src/fixtures/case-md.md",
    );
    try buffer.read(open_file_path);
    // try std.testing.expectEqual(buffer.data_lines.?.items.len, 20);
    // try std.testing.expectEqualDeep(
    //     buffer.data_lines.?.items[0],
    //     "# My Sample Markdown File",
    // );
    // try std.testing.expectEqualDeep(buffer.data_lines.?.items[12], "## Code Example");
    // try std.testing.expectEqualDeep(buffer.data_lines.?.items[19], "```");

    // case 3
    open_file_path = try std.fs.cwd().realpathAlloc(
        alloc,
        "./src/fixtures/tiny.txt",
    );

    try buffer.read(open_file_path);
    // try std.testing.expectEqual(buffer.data_lines.?.items.len, 2);
    // try std.testing.expectEqualDeep(buffer.data_lines.?.items[0], "1234");
    // try std.testing.expectEqualDeep(buffer.data_lines.?.items[1], "567");
}
