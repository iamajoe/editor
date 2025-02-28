const std = @import("std");
const ts = @import("tree-sitter");

const highlights_scm: []const u8 = @embedFile("./highlights.scm");

extern fn tree_sitter_javascript() callconv(.C) *ts.Language;

pub const grammar = tree_sitter_javascript;

pub fn getHighlight(allocator: std.mem.Allocator, tree: *ts.Tree) !void {
    var error_offset: u32 = 0;
    const query = try ts.Query.create(grammar(), highlights_scm, &error_offset);
    const cursor = ts.QueryCursor.create();
    cursor.exec(query, tree.rootNode());

    while (cursor.nextCapture()) |match| {
        const m: ts.Query.Match = match[1];
        for (m.captures) |capture| {
            std.debug.print("{any} \n\n", .{capture.node});
        }
    }

    _ = allocator;

    // TODO: need to defer somewhere query.destroy();
}

// TODO: lsp?!
// TODO: highlights?!
