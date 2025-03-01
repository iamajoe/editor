const std = @import("std");
const vaxis = @import("vaxis");
const debug = @import("./debug.zig");

const color_catppuccin = struct {
    const rosewater = [_]u8{ 245, 224, 220 };
    const flamingo = [_]u8{ 242, 205, 205 };
    const pink = [_]u8{ 245, 194, 231 };
    const mauve = [_]u8{ 203, 166, 247 };
    const red = [_]u8{ 243, 139, 168 };
    const maroon = [_]u8{ 235, 160, 172 };
    const peach = [_]u8{ 250, 179, 135 };
    const yellow = [_]u8{ 249, 226, 175 };
    const green = [_]u8{ 166, 227, 161 };
    const teal = [_]u8{ 148, 226, 213 };
    const sky = [_]u8{ 137, 220, 235 };
    const sapphire = [_]u8{ 116, 199, 236 };
    const blue = [_]u8{ 137, 180, 250 };
    const lavender = [_]u8{ 180, 190, 254 };
    const text = [_]u8{ 205, 214, 244 };
    const subtext1 = [_]u8{ 186, 194, 222 };
    const subtext0 = [_]u8{ 166, 173, 200 };
    const overlay2 = [_]u8{ 147, 153, 178 };
    const overlay1 = [_]u8{ 127, 132, 156 };
    const overlay0 = [_]u8{ 108, 112, 134 };
    const surface2 = [_]u8{ 88, 91, 112 };
    const surface1 = [_]u8{ 69, 71, 90 };
    const surface0 = [_]u8{ 49, 50, 68 };
    const base = [_]u8{ 30, 30, 46 };
    const mantle = [_]u8{ 24, 24, 37 };
    const crust = [_]u8{ 17, 17, 27 };
};
const color_base = [_]u8{ 162, 162, 203 };
const theme_col_gap: usize = 2;
const theme_line: vaxis.Style = .{
    // .dim = true,
};
const theme_line_selected: vaxis.Style = .{
    .bg = .{ .rgb = [_]u8{ 50, 50, 50 } },
};
const theme_cursor: vaxis.Style = .{
    .bg = .{ .rgb = [_]u8{ 85, 85, 85 } },
};

const TSTokenType = enum {
    none, // means it hasn't found one

    comment,
    identifier,
    integer,
    operator, // +, -, /, *, =
    string,
    symbol, // ;, ,, :, (, ), {, }

    struct_keyword,
    var_keyword, // const, var, let...
    macro,
    function, // function, fn, fun
};
const kind_to_token_map: [33]std.meta.Tuple(&.{
    []const u8,
    TSTokenType,
}) = .{
    .{ "comment", TSTokenType.comment },
    .{ "identifier", TSTokenType.identifier },
    .{ "property_identifier", TSTokenType.identifier },
    .{ "shorthand_property_identifier_pattern", TSTokenType.identifier },
    .{ "number", TSTokenType.integer },
    .{ "integer", TSTokenType.integer },
    .{ "+", TSTokenType.operator },
    .{ "-", TSTokenType.operator },
    .{ "/", TSTokenType.operator },
    .{ "*", TSTokenType.operator },
    .{ "=", TSTokenType.operator },
    .{ "string", TSTokenType.string },
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
    .{ "struct", TSTokenType.struct_keyword },
    .{ "enum", TSTokenType.struct_keyword },
    .{ "macro", TSTokenType.macro },
    .{ "builtin_type", TSTokenType.macro },
    .{ "var", TSTokenType.var_keyword },
    .{ "let", TSTokenType.var_keyword },
    .{ "const", TSTokenType.var_keyword },
    .{ "function", TSTokenType.function },
    .{ "fn", TSTokenType.function },
    .{ "fun", TSTokenType.function },
};
const token_to_color_map: [11]std.meta.Tuple(&.{
    TSTokenType,
    [3]u8,
}) = .{
    .{ TSTokenType.none, color_base },
    .{ TSTokenType.comment, color_base },
    .{ TSTokenType.identifier, color_catppuccin.text },
    .{ TSTokenType.integer, color_catppuccin.peach },
    .{ TSTokenType.operator, color_catppuccin.teal },
    .{ TSTokenType.string, color_catppuccin.green },
    .{ TSTokenType.symbol, color_base },
    .{ TSTokenType.struct_keyword, color_catppuccin.mauve },
    .{ TSTokenType.macro, color_catppuccin.yellow },
    .{ TSTokenType.var_keyword, color_catppuccin.mauve },
    .{ TSTokenType.function, color_catppuccin.mauve },
};

fn getToken(kind: []const u8) TSTokenType {
    for (kind_to_token_map) |tup| {
        if (std.mem.eql(u8, kind, tup[0])) {
            return tup[1];
        }
    }

    return TSTokenType.none;
}

fn getTokenColor(token: TSTokenType) [3]u8 {
    for (token_to_color_map) |tup| {
        if (tup[0] == token) {
            return tup[1];
        }
    }

    return color_base;
}

pub fn getStyle(kind: []const u8, is_line_selected: bool, is_cursor: bool) vaxis.Style {
    var style = theme_line;
    if (is_line_selected) {
        style = theme_line_selected;

        if (is_cursor) {
            style = theme_cursor;
        }
    }

    const token = getToken(kind);

    // debug so we can find out which token is missing
    if (token == TSTokenType.none) {
        debug.add(kind) catch |err| {
            std.debug.print("error: {}\n", .{err});
        };
    }

    if (token == TSTokenType.comment) {
        style.dim = true;
    }

    style.fg = .{ .rgb = getTokenColor(token) };

    return style;
}
