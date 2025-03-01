const ts = @import("tree-sitter");

extern fn tree_sitter_zig() callconv(.C) *ts.Language;

pub const grammar = tree_sitter_zig;
pub const highlight_query: []const u8 = @embedFile("./highlights.scm");

// TODO: lsp?!
