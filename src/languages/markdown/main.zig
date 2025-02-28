const std = @import("std");
const ts = @import("tree-sitter");

const highlights_scm: []const u8 = @embedFile("./highlights.scm");

extern fn tree_sitter_markdown() callconv(.C) *ts.Language;

pub const grammar = tree_sitter_markdown;

pub fn getHighlight(allocator: std.mem.Allocator, source: []u8) !void {
    _ = allocator;

    // ts.Query.create(grammar(), , error_offset: *u32);
    var error_offset: u32 = 0;
    const language = grammar();
    const query = try ts.Query.create(language, highlights_scm, &error_offset);

    _ = query;
    _ = source;

    // TODO: need to defer somewhere query.destroy();
}

// TODO: lsp?!
// TODO: highlights?!
