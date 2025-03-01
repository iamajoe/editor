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

pub const MatchCapture = struct {
    start_x: u32,
    start_y: u32,
    end_x: u32,
    end_y: u32,
    node: ts.Node,
    token: TSTokenType,
};

pub const TSTokenType = enum {
    none, // means it hasn't found one

    comment,
    identifier,
    property_identifier,
    integer,
    operator, // +, -, /, *, =
    string,
    symbol, // ;, ,, :, (, ), {, }

    null_keyword, // null, undefined
    lang_keyword, // struct, pub extern, callconv...
    var_keyword, // const, var, let...
    builtin_type,
    builtin_identifier,
    function, // function, fn, fun
};
const kind_to_token_map: [60]std.meta.Tuple(&.{
    []const u8,
    TSTokenType,
}) = .{
    .{ "comment", TSTokenType.comment },
    .{ "identifier", TSTokenType.identifier },
    .{ "property_identifier", TSTokenType.property_identifier },
    .{ "shorthand_property_identifier_pattern", TSTokenType.property_identifier },
    .{ "number", TSTokenType.integer },
    .{ "integer", TSTokenType.integer },
    .{ "+", TSTokenType.operator },
    .{ "+=", TSTokenType.operator },
    .{ "-=", TSTokenType.operator },
    .{ ">=", TSTokenType.operator },
    .{ "<=", TSTokenType.operator },
    .{ "!=", TSTokenType.operator },
    .{ "-", TSTokenType.operator },
    .{ "/", TSTokenType.operator },
    .{ "*", TSTokenType.operator },
    .{ "=", TSTokenType.operator },
    .{ ">", TSTokenType.operator },
    .{ "<", TSTokenType.operator },
    .{ "?", TSTokenType.operator },
    .{ "string", TSTokenType.string },
    .{ "string_content", TSTokenType.string },
    .{ "template_string", TSTokenType.string },
    .{ ";", TSTokenType.symbol },
    .{ ",", TSTokenType.symbol },
    .{ ":", TSTokenType.symbol },
    .{ ".", TSTokenType.symbol },
    .{ "(", TSTokenType.symbol },
    .{ ")", TSTokenType.symbol },
    .{ "{", TSTokenType.symbol },
    .{ "}", TSTokenType.symbol },
    .{ "[", TSTokenType.symbol },
    .{ "]", TSTokenType.symbol },
    .{ "null", TSTokenType.null_keyword },
    .{ "undefined", TSTokenType.null_keyword },
    .{ "builtin_type", TSTokenType.builtin_type },
    .{ "builtin_identifier", TSTokenType.builtin_identifier },
    .{ "return", TSTokenType.lang_keyword },
    .{ "defer", TSTokenType.lang_keyword },
    .{ "boolean", TSTokenType.lang_keyword },
    .{ "if", TSTokenType.lang_keyword },
    .{ "and", TSTokenType.lang_keyword },
    .{ "or", TSTokenType.lang_keyword },
    .{ "else", TSTokenType.lang_keyword },
    .{ "try", TSTokenType.lang_keyword },
    .{ "catch", TSTokenType.lang_keyword },
    .{ "switch", TSTokenType.lang_keyword },
    .{ "while", TSTokenType.lang_keyword },
    .{ "for", TSTokenType.lang_keyword },
    .{ "struct", TSTokenType.lang_keyword },
    .{ "enum", TSTokenType.lang_keyword },
    .{ "callconv", TSTokenType.lang_keyword },
    .{ "extern", TSTokenType.lang_keyword },
    .{ "pub", TSTokenType.lang_keyword },
    .{ "var", TSTokenType.var_keyword },
    .{ "let", TSTokenType.var_keyword },
    .{ "const", TSTokenType.var_keyword },
    .{ "function", TSTokenType.function },
    .{ "=>", TSTokenType.function },
    .{ "fn", TSTokenType.function },
    .{ "fun", TSTokenType.function },
    // TODO: missing escape_sequence
    // TODO: missing character_content
};

fn getToken(kind: []const u8) TSTokenType {
    for (kind_to_token_map) |tup| {
        if (std.mem.eql(u8, kind, tup[0])) {
            return tup[1];
        }
    }

    return TSTokenType.none;
}

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

fn saveMatchesToFile(matches: std.ArrayList(MatchCapture), file_path: []const u8) !void {
    if (!debug.should_debug) {
        return;
    }

    const gpa = std.heap.page_allocator;
    var list = std.ArrayList([]const u8).init(gpa);
    defer list.deinit();

    for (matches.items) |match| {
        const raw_sexp = match.node.toSexp();
        const sexp = try prettyPrintSexp(gpa, raw_sexp);
        // defer gpa.free(sexp);

        try list.append(sexp);
    }

    const combined = try std.mem.concat(gpa, u8, list.items);
    defer gpa.free(combined);

    var file = try std.fs.cwd().createFile(file_path, .{ .truncate = true });
    defer file.close();
    try file.writeAll(combined);
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

pub fn highlightMatches(
    alloc: std.mem.Allocator,
    cursor: *ts.QueryCursor,
    start_row: usize,
    end_row: usize,
) !std.ArrayList(MatchCapture) {
    try cursor.setPointRange(
        .{ .row = @intCast(start_row), .column = 0 },
        .{ .row = @intCast(end_row + 1), .column = 0 },
    );

    var arr = std.ArrayList(MatchCapture).init(alloc);

    while (cursor.nextMatch()) |match| {
        for (match.captures) |capture| {
            const start = capture.node.startPoint();
            const end = capture.node.endPoint();
            try arr.append(.{
                .start_x = start.column,
                .start_y = start.row,
                .end_x = end.column,
                .end_y = end.row,
                .node = capture.node,
                .token = getToken(capture.node.kind()),
            });
        }
    }

    // for debugging purposes...
    try saveMatchesToFile(arr, "./tmp_highlights");

    return arr;
}

pub fn highlightAt(cursor: *ts.QueryCursor, row: usize, col: usize) !TSTokenType {
    try cursor.setPointRange(
        .{ .row = @intCast(row), .column = col },
        .{ .row = @intCast(row), .column = col +| 10 },
    );

    var token = TSTokenType.none;

    while (cursor.nextMatch()) |match| {
        for (match.captures) |capture| {
            const range = capture.node.range();
            const start = range.start_point;
            const end = range.end_point;
            // const scope = query.captureNameForId(capture.id);
            if (start.row == row and start.column <= col and col < end.column) {
                token = getToken(capture.node.kind());
            }
        }
    }

    return token;
}
