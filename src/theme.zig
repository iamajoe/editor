const std = @import("std");
const vaxis = @import("vaxis");
const tree_sitter = @import("./tree_sitter.zig");
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
const color_white = [_]u8{ 224, 224, 255 };
const color_err = [_]u8{ 255, 0, 0 };
const color_comment = [_]u8{ 140, 140, 191 };

const theme_col_gap: usize = 2;
const theme_line: vaxis.Style = .{
    // .dim = true,
};
const theme_line_selected: vaxis.Style = .{
    .bg = .{ .rgb = [_]u8{ 50, 50, 50 } },
};
const theme_cursor: vaxis.Style = .{
    // .bg = .{ .rgb = [_]u8{ 85, 85, 85 } },
    .bg = .{ .rgb = color_catppuccin.rosewater },
};

const token_to_color_map: [35]std.meta.Tuple(&.{
    tree_sitter.TSTokenType,
    [3]u8,
}) = .{
    .{ tree_sitter.TSTokenType.none, color_err },
    .{ tree_sitter.TSTokenType.comment, color_comment },
    .{ tree_sitter.TSTokenType.spell, color_comment },
    .{ tree_sitter.TSTokenType.comment_documentation, color_comment },
    .{ tree_sitter.TSTokenType.type, color_catppuccin.yellow },
    .{ tree_sitter.TSTokenType.type_builtin, color_catppuccin.yellow },
    .{ tree_sitter.TSTokenType.keyword, color_catppuccin.mauve },
    .{ tree_sitter.TSTokenType.keyword_import, color_catppuccin.mauve },
    .{ tree_sitter.TSTokenType.keyword_modifier, color_catppuccin.mauve },
    .{ tree_sitter.TSTokenType.keyword_function, color_catppuccin.mauve },
    .{ tree_sitter.TSTokenType.keyword_return, color_catppuccin.mauve },
    .{ tree_sitter.TSTokenType.keyword_conditional, color_catppuccin.mauve },
    .{ tree_sitter.TSTokenType.keyword_repeat, color_catppuccin.mauve },
    .{ tree_sitter.TSTokenType.keyword_exception, color_catppuccin.mauve },
    .{ tree_sitter.TSTokenType.keyword_operator, color_catppuccin.mauve },
    .{ tree_sitter.TSTokenType.keyword_type, color_catppuccin.mauve },
    .{ tree_sitter.TSTokenType.variable, color_err },
    .{ tree_sitter.TSTokenType.variable_member, color_err },
    .{ tree_sitter.TSTokenType.variable_parameter, color_err },
    // TODO: this one is doing too much!!
    .{ tree_sitter.TSTokenType.variable_builtin, color_white },
    // .{ tree_sitter.TSTokenType.variable_builtin, color_catppuccin.blue },
    // .{ tree_sitter.TSTokenType.variable_builtin, color_err },
    .{ tree_sitter.TSTokenType.constant, color_err },
    .{ tree_sitter.TSTokenType.constant_builtin, color_err },
    .{ tree_sitter.TSTokenType.number, color_catppuccin.maroon },
    .{ tree_sitter.TSTokenType.boolean, color_catppuccin.maroon },
    .{ tree_sitter.TSTokenType.character, color_catppuccin.green },
    .{ tree_sitter.TSTokenType.operator, color_catppuccin.teal },
    .{ tree_sitter.TSTokenType.module, color_catppuccin.lavender },
    .{ tree_sitter.TSTokenType.string, color_catppuccin.green },
    .{ tree_sitter.TSTokenType.string_escape, color_catppuccin.green },
    .{ tree_sitter.TSTokenType.function, color_catppuccin.yellow },
    .{ tree_sitter.TSTokenType.function_call, color_catppuccin.yellow },
    .{ tree_sitter.TSTokenType.function_builtin, color_catppuccin.mauve },
    .{ tree_sitter.TSTokenType.punctuation, color_catppuccin.teal },
    .{ tree_sitter.TSTokenType.punctuation_bracket, color_catppuccin.teal },
    .{ tree_sitter.TSTokenType.punctuation_delimiter, color_catppuccin.teal },
};

fn getTokenColor(token: tree_sitter.TSTokenType) [3]u8 {
    for (token_to_color_map) |tup| {
        if (tup[0] == token) {
            return tup[1];
        }
    }

    return color_base;
}

pub fn getStyle(token: tree_sitter.TSTokenType, is_line_selected: bool, is_cursor: bool) vaxis.Style {
    var style = theme_line;
    if (is_line_selected) {
        style = theme_line_selected;

        if (is_cursor) {
            style = theme_cursor;
        }
    }

    // if (token == tree_sitter.TSTokenType.comment) {
    //     style.dim = true;
    // }

    style.fg = .{ .rgb = getTokenColor(token) };

    return style;
}
