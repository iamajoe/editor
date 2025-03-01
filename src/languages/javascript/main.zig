const ts = @import("tree-sitter");

extern fn tree_sitter_javascript() callconv(.C) *ts.Language;

pub const grammar = tree_sitter_javascript;
pub const highlight_query: []const u8 = @embedFile("./highlights.scm");

// TODO: lsp?!
