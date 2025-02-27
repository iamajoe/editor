const std = @import("std");
const ts = @import("tree-sitter");

pub const Tree = ts.Tree;

extern fn tree_sitter_csv() callconv(.C) *ts.Language;
extern fn tree_sitter_make() callconv(.C) *ts.Language;
extern fn tree_sitter_markdown() callconv(.C) *ts.Language;
extern fn tree_sitter_toml() callconv(.C) *ts.Language;
extern fn tree_sitter_yaml() callconv(.C) *ts.Language;
extern fn tree_sitter_zig() callconv(.C) *ts.Language;

fn findSyntax(syntax: []u8) *ts.Language {
    // TODO: still need to implement these
    // https://tree-sitter.github.io/tree-sitter/index.html
    // - json
    // - typescript
    // - javascript
    // - html
    // - go
    // - c
    // - css

    // TODO: would prefer to have this at comptime somehow, with anonymous fns
    const extension_mapping: [14]std.meta.Tuple(&.{ []const u8, *ts.Language }) = .{
        .{ "csv", tree_sitter_csv() },
        .{ ".csv", tree_sitter_csv() },

        .{ "make", tree_sitter_make() },
        .{ "Makefile", tree_sitter_make() },

        .{ "markdown", tree_sitter_markdown() },
        .{ ".md", tree_sitter_markdown() },

        .{ "toml", tree_sitter_toml() },
        .{ ".toml", tree_sitter_toml() },

        .{ "yaml", tree_sitter_yaml() },
        .{ ".yaml", tree_sitter_yaml() },
        .{ ".yml", tree_sitter_yaml() },

        .{ "zig", tree_sitter_zig() },
        .{ ".zig", tree_sitter_zig() },

        .{ "default", tree_sitter_markdown() },
    };

    for (extension_mapping) |tup| {
        if (!std.mem.eql(u8, tup[0], syntax)) {
            continue;
        }

        return tup[1];
    }

    return findSyntax(@constCast("default"));
}

pub fn parseCode(code: []u8, syntax: []u8) !*Tree {
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

    const root_node = tree.rootNode();
    const child_count = root_node.childCount();
    std.debug.print("Root node child count: {d}\n", .{child_count});

    // iterate children
    for (0..child_count) |i| {
        const child_node_raw = root_node.child(@intCast(i));
        if (child_node_raw) |child_node| {
            std.debug.print("\n\nChild {d} grammar kind: {s}\n", .{ i, child_node.grammarKind() });
            std.debug.print("Child: {s}\n", .{child_node.toSexp()});
        }
    }

    return tree;
}
