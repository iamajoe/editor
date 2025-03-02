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
ts_highlight_matches: ?std.ArrayList(tree_sitter.MatchCapture),

pub fn init(alloc: std.mem.Allocator) !*Buffer {
    const buffer = try alloc.create(Buffer);
    buffer.* = Buffer{
        .allocator = alloc,
        .syntax = null,
        .file_path = null,
        .data = null,

        // treesitter specific
        .ts_tree = null,
        .ts_highlight_matches = null,
    };

    return buffer;
}

pub fn deinit(self: *Buffer) void {
    if (self.ts_highlight_matches) |matches| {
        matches.deinit();
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
    self.ts_tree = null;
    self.ts_highlight_matches = null;

    if (self.file_path == null or self.data == null) {
        self.syntax = null;
        return;
    }

    self.syntax = @constCast(std.fs.path.extension(self.file_path.?));
    if (self.syntax) |syntax| {
        const tree = try tree_sitter.parseCode(self.data.?, syntax);
        self.ts_tree = tree.tree;
        self.ts_highlight_matches = try tree_sitter.highlightMatches(
            self.allocator,
            tree.tree,
            tree.highlight_query,
            0,
            std.math.maxInt(u16),
        );
    }
}

pub fn highlightAt(self: *Buffer, row: usize, col: usize) !tree_sitter.TSTokenType {
    var token = tree_sitter.TSTokenType.none;

    if (self.ts_highlight_matches) |matches| {
        for (matches.items) |match| {
            // row is not part of the match
            if (row < match.start_y or row > match.end_y) {
                continue;
            }

            // col is not part of the match
            if (col < match.start_x or col > match.end_x) {
                continue;
            }

            token = match.token;
        }
    }

    return token;
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
        "./src/languages/markdown/fixture.md",
    );
    try buffer.read(open_file_path);
    // try std.testing.expectEqual(buffer.data_lines.?.items.len, 20);
    // try std.testing.expectEqualDeep(
    //     buffer.data_lines.?.items[0],
    //     "# My Sample Markdown File",
    // );
    // try std.testing.expectEqualDeep(buffer.data_lines.?.items[12], "## Code Example");
    // try std.testing.expectEqualDeep(buffer.data_lines.?.items[19], "```");
}
