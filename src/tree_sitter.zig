const std = @import("std");
const ts = @import("tree-sitter");
const ts_javascript = @import("./languages/javascript/main.zig");
const ts_zig = @import("./languages/zig/main.zig");
const ts_markdown = @import("./languages/markdown/main.zig");
const debug = @import("./debug.zig");

extern fn tree_sitter_csv() callconv(.C) *ts.Language;
extern fn tree_sitter_make() callconv(.C) *ts.Language;
extern fn tree_sitter_toml() callconv(.C) *ts.Language;
extern fn tree_sitter_yaml() callconv(.C) *ts.Language;

fn prettyPrintSexp(allocator: std.mem.Allocator, sexp: []const u8) ![]const u8 {
    var output = std.ArrayList(u8).init(allocator);
    defer output.deinit();

    var indent: usize = 0;
    var i: usize = 0;
    while (i < sexp.len) : (i += 1) {
        const c = sexp[i];

        switch (c) {
            '(' => {
                try output.append('\n');
                try output.appendNTimes(' ', indent * 2);
                try output.append(c);
                indent += 1;
            },
            ')' => {
                indent = if (indent > 0) indent - 1 else 0;
                try output.append(c);
            },
            ' ' => {
                if (i > 0 and sexp[i - 1] != '(' and sexp[i + 1] != ')') {
                    try output.append(c);
                }
            },
            else => {
                try output.append(c);
            },
        }
    }

    return output.toOwnedSlice();
}

fn saveNodeToFile(node: ts.Node, file_path: []const u8) !void {
    if (!debug.should_debug) {
        return;
    }

    const raw_sexp = node.toSexp();
    const sexp = try prettyPrintSexp(std.heap.page_allocator, raw_sexp);
    defer std.heap.page_allocator.free(sexp);

    var file = try std.fs.cwd().createFile(file_path, .{ .truncate = true });
    defer file.close();
    try file.writeAll(sexp);
}

fn getSyntaxData(syntax: []u8) struct {
    grammar: ?*ts.Language,
    highlight_query: ?[]const u8,
} {
    var grammar_raw: ?*ts.Language = null;
    var highlight_query_raw: ?[]const u8 = null;

    // figure the grammar and highlights query
    if (std.mem.eql(u8, syntax, ".js") or std.mem.eql(u8, syntax, "javascript") or std.mem.eql(u8, syntax, "js")) {
        grammar_raw = ts_javascript.grammar();
        highlight_query_raw = ts_javascript.highlight_query;
    } else if (std.mem.eql(u8, syntax, ".csv") or std.mem.eql(u8, syntax, "csv")) {
        grammar_raw = tree_sitter_csv();
    } else if (std.mem.eql(u8, syntax, "Makefile") or std.mem.eql(u8, syntax, "make")) {
        grammar_raw = tree_sitter_make();
    } else if (std.mem.eql(u8, syntax, ".md") or std.mem.eql(u8, syntax, "markdown")) {
        grammar_raw = ts_markdown.grammar();
    } else if (std.mem.eql(u8, syntax, ".toml") or std.mem.eql(u8, syntax, "toml")) {
        grammar_raw = tree_sitter_toml();
    } else if (std.mem.eql(u8, syntax, ".yaml") or std.mem.eql(u8, syntax, ".yml") or std.mem.eql(u8, syntax, "yaml")) {
        grammar_raw = tree_sitter_yaml();
    } else if (std.mem.eql(u8, syntax, ".zig") or std.mem.eql(u8, syntax, "zig")) {
        grammar_raw = ts_zig.grammar();
        highlight_query_raw = ts_zig.highlight_query;
    }

    return .{
        .grammar = grammar_raw,
        .highlight_query = highlight_query_raw,
    };
}

pub fn parseCode(code: []u8, syntax: []u8) !struct {
    tree: ?*ts.Tree,
    grammar: ?*ts.Language,
    highlight_query: ?*ts.Query,
} {
    const language = getSyntaxData(syntax);
    if (language.grammar == null) {
        return .{ .tree = null, .grammar = null, .highlight_query = null };
    }

    const grammar = language.grammar.?;

    // set the parser
    const parser = ts.Parser.create();
    defer parser.destroy();
    try parser.setLanguage(grammar);

    // build the tree
    const tree = parser.parseStringEncoding(code, null, .UTF_8) orelse unreachable;
    // TODO: what now?

    var highlight_query: ?*ts.Query = null;
    if (language.highlight_query) |query| {
        var error_offset: u32 = 0;
        highlight_query = try ts.Query.create(grammar, query, &error_offset);
    }

    // for debugging purposes...
    // try saveNodeToFile(tree.rootNode(), "./tmp_tree");

    return .{
        .tree = tree,
        .grammar = grammar,
        .highlight_query = highlight_query,
    };
}

pub fn getHighlightCursor(tree: ?*ts.Tree, query: ?*ts.Query) ?*ts.QueryCursor {
    if (tree == null or query == null) {
        return null;
    }

    const cursor = ts.QueryCursor.create();
    cursor.exec(query.?, tree.?.rootNode());

    return cursor;
}

pub fn highlightAt(cursor: *ts.QueryCursor, row: usize, col: usize) !?struct {
    node: ts.Node,
    index: u32,
} {
    try cursor.setPointRange(
        // .{ .row = @intCast(row), .column = 0 },
        // .{ .row = @intCast(row + 1), .column = 0 },
        .{ .row = @intCast(row), .column = @intCast(col) },
        .{ .row = @intCast(row), .column = @intCast(col +| 10) },
    );

    // find the query match relevant
    // NOTE: since we already set the point range, it should be the next one
    while (cursor.nextMatch()) |match| {
        for (match.captures) |capture| {
            // const range = capture.node.range();
            // const start = range.start_point;
            // const end = range.end_point;
            // const scope = query.captureNameForId(capture.id);
            // if (start.row == row and start.column <= col and col < end.column) {
            // if (start.row == row and start.column == col) {
            // for debugging purposes...
            // try saveNodeToFile(capture.node, "./tmp_highlight_at");

            return .{
                .index = capture.index,
                .node = capture.node,
            };
            // }
        }
    }

    return null;
}

pub fn highlightAtByte(cursor: *ts.QueryCursor, start_byte: u32, end_byte: u32) !?struct {
    node: ts.Node,
    index: u32,
} {
    try cursor.setByteRange(start_byte, end_byte);

    // find the query match relevant
    // NOTE: since we already set the point range, it should be the next one
    while (cursor.nextMatch()) |match| {
        for (match.captures) |capture| {
            return .{
                .index = capture.index,
                .node = capture.node,
            };
        }
    }

    return null;
}
