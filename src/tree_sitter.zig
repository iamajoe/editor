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
    scope: []const u8,
    token: TSTokenType,
};

pub const TSTokenType = enum {
    none, // means it hasn't found one

    comment, // comment
    spell, // comment
    comment_documentation, // comment

    type, // (identifier)
    type_builtin,
    keyword, // const
    keyword_import, // (builtin_identifier)
    keyword_modifier, // extern pub callconv
    keyword_function, // fn func function
    keyword_return, // return
    keyword_conditional, // switch if else
    keyword_repeat, // for while
    keyword_exception, // try catch
    keyword_operator, // and or
    keyword_type, // struct enum
    variable, // (identifier)
    variable_member, // (identifier)
    variable_parameter, // (identifier)
    variable_builtin, // (identifier)
    constant, // (identifier)
    constant_builtin,
    number,
    boolean,
    character,
    operator, // = *
    module, // (identifier)
    string,
    string_escape,
    function, // (identifier)
    function_call, // (identifier)
    function_builtin, // (builtin_identifier)
    punctuation,
    punctuation_bracket, // " ) } ]
    punctuation_delimiter, // ; . :
};
const kind_to_token_map: [35]std.meta.Tuple(&.{
    []const u8,
    TSTokenType,
}) = .{
    .{ "", TSTokenType.none },
    .{ "comment", TSTokenType.comment },
    .{ "spell", TSTokenType.spell },
    .{ "comment.documentation", TSTokenType.comment_documentation },
    .{ "type", TSTokenType.type },
    .{ "type.builtin", TSTokenType.type_builtin },
    .{ "keyword", TSTokenType.keyword },
    .{ "keyword.import", TSTokenType.keyword_import },
    .{ "keyword.modifier", TSTokenType.keyword_modifier },
    .{ "keyword.function", TSTokenType.keyword_function },
    .{ "keyword.return", TSTokenType.keyword_return },
    .{ "keyword.conditional", TSTokenType.keyword_conditional },
    .{ "keyword.repeat", TSTokenType.keyword_repeat },
    .{ "keyword.exception", TSTokenType.keyword_exception },
    .{ "keyword.operator", TSTokenType.keyword_operator },
    .{ "keyword.type", TSTokenType.keyword_type },
    .{ "variable", TSTokenType.variable },
    .{ "variable.member", TSTokenType.variable_member },
    .{ "variable.parameter", TSTokenType.variable_parameter },
    .{ "variable.builtin", TSTokenType.variable_builtin },
    .{ "constant", TSTokenType.constant },
    .{ "constant.builtin", TSTokenType.constant_builtin },
    .{ "number", TSTokenType.number },
    .{ "boolean", TSTokenType.boolean },
    .{ "character", TSTokenType.character },
    .{ "operator", TSTokenType.operator },
    .{ "module", TSTokenType.module },
    .{ "string", TSTokenType.string },
    .{ "string.escape", TSTokenType.string_escape },
    .{ "function", TSTokenType.function },
    .{ "function.builtin", TSTokenType.function_builtin },
    .{ "function.call", TSTokenType.function_call },
    .{ "punctuation", TSTokenType.punctuation },
    .{ "punctuation.bracket", TSTokenType.punctuation_bracket },
    .{ "punctuation.delimiter", TSTokenType.punctuation_delimiter },
};

fn getToken(kind: []const u8) TSTokenType {
    for (kind_to_token_map) |tup| {
        if (std.mem.eql(u8, kind, tup[0])) {
            return tup[1];
        }
    }

    // std.debug.print("Kind: {s}\n", .{kind});

    // not found? check if there is a dot and separate, pop the back portion
    var nest_split = std.mem.split(u8, kind, ".");
    while (nest_split.next()) |next| {
        if (std.mem.eql(u8, kind, next)) {
            break;
        }

        return getToken(next);
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

    var allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer allocator.deinit();
    const gpa = allocator.allocator();

    var list = std.ArrayList([]const u8).init(gpa);
    defer list.deinit();

    for (matches.items) |match| {
        const raw_sexp = match.node.toSexp();
        const sexp = try prettyPrintSexp(gpa, raw_sexp);

        try list.append(sexp);
        try list.append(" --> ");
        try list.append(match.scope);
    }

    const combined = try std.mem.concat(gpa, u8, list.items);

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

pub fn highlightMatches(
    alloc: std.mem.Allocator,
    tree_raw: ?*ts.Tree,
    query_raw: ?*ts.Query,
    start_row: usize,
    end_row: usize,
) !std.ArrayList(MatchCapture) {
    var arr = std.ArrayList(MatchCapture).init(alloc);
    if (tree_raw == null or query_raw == null) {
        return arr;
    }

    const tree = tree_raw.?;
    const query = query_raw.?;

    const cursor = ts.QueryCursor.create();
    defer cursor.destroy();
    cursor.exec(query, tree.rootNode());

    try cursor.setPointRange(
        .{ .row = @intCast(start_row), .column = 0 },
        .{ .row = @intCast(end_row + 1), .column = 0 },
    );

    while (cursor.nextMatch()) |match| {
        for (match.captures) |capture| {
            const start = capture.node.startPoint();
            const end = capture.node.endPoint();

            const scope_raw = query.captureNameForId(capture.index);
            var scope: []const u8 = "";
            if (scope_raw) |new_scope| {
                scope = new_scope;
            }

            try arr.append(.{
                .start_x = start.column,
                .start_y = start.row,
                .end_x = end.column,
                .end_y = end.row,
                .node = capture.node,
                .scope = scope,
                .token = getToken(scope),
            });
        }
    }

    // for debugging purposes...
    try saveMatchesToFile(arr, "./tmp_highlights");

    return arr;
}
