const std = @import("std");
const ts = @import("tree-sitter");
const javascript = @import("./languages/javascript/main.zig");
const markdown = @import("./languages/markdown/main.zig");

pub const Tree = ts.Tree;

extern fn tree_sitter_csv() callconv(.C) *ts.Language;
extern fn tree_sitter_make() callconv(.C) *ts.Language;
extern fn tree_sitter_toml() callconv(.C) *ts.Language;
extern fn tree_sitter_yaml() callconv(.C) *ts.Language;
extern fn tree_sitter_zig() callconv(.C) *ts.Language;

fn findSyntax(syntax: []u8) *ts.Language {
    // TODO: still need to implement these
    // https://tree-sitter.github.io/tree-sitter/index.html
    // - json
    // - typescript
    // - html
    // - go
    // - c
    // - css

    // TODO: would prefer to have this at comptime somehow, with anonymous fns
    const extension_mapping: [17]std.meta.Tuple(&.{
        []const u8,
        *ts.Language,
    }) = .{
        .{ "csv", tree_sitter_csv() },
        .{ ".csv", tree_sitter_csv() },

        .{ "javascript", javascript.grammar() },
        .{ "js", javascript.grammar() },
        .{ ".js", javascript.grammar() },

        .{ "make", tree_sitter_make() },
        .{ "Makefile", tree_sitter_make() },

        .{ "markdown", markdown.grammar() },
        .{ ".md", markdown.grammar() },

        .{ "toml", tree_sitter_toml() },
        .{ ".toml", tree_sitter_toml() },

        .{ "yaml", tree_sitter_yaml() },
        .{ ".yaml", tree_sitter_yaml() },
        .{ ".yml", tree_sitter_yaml() },

        .{ "zig", tree_sitter_zig() },
        .{ ".zig", tree_sitter_zig() },

        .{ "default", markdown.grammar() },
    };

    for (extension_mapping) |tup| {
        if (!std.mem.eql(u8, tup[0], syntax)) {
            continue;
        }

        return tup[1];
    }

    return findSyntax(@constCast("default"));
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

fn saveTreeToFile(tree: *Tree, file_path: []const u8) !void {
    const raw_sexp = tree.rootNode().toSexp();
    const sexp = try prettyPrintSexp(std.heap.page_allocator, raw_sexp);
    defer std.heap.page_allocator.free(sexp);

    var file = try std.fs.cwd().createFile(file_path, .{ .truncate = true });
    defer file.close();
    try file.writeAll(sexp);
}

pub fn parseCode(code: []u8, syntax: []u8) !*Tree {
    // TODO: maybe we should just do a switch case with a block for the syntax language
    //       instead of the method
    // find the right language
    const language = findSyntax(syntax);
    defer language.destroy();

    // set the parser
    const parser = ts.Parser.create();
    defer parser.destroy();
    try parser.setLanguage(language);

    // build the tree
    const tree = parser.parseStringEncoding(code, null, .UTF_8) orelse unreachable;
    // TODO: what now?

    // for debugging purposes...
    try saveTreeToFile(tree, "./tmp_tree");

    return tree;
}

pub fn getHighlight(allocator: std.mem.Allocator, tree: *Tree, syntax: []u8) !void {
    if (std.mem.eql(u8, syntax, ".js") or std.mem.eql(u8, syntax, "javascript")) {
        try javascript.getHighlight(allocator, tree);
    }

    // TODO: ...
}
