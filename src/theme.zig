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

const token_to_color_map: [14]std.meta.Tuple(&.{
    tree_sitter.TSTokenType,
    [3]u8,
}) = .{
    .{ tree_sitter.TSTokenType.none, color_base },
    .{ tree_sitter.TSTokenType.comment, [_]u8{ 140, 140, 191 } },
    .{ tree_sitter.TSTokenType.identifier, color_catppuccin.text },
    .{ tree_sitter.TSTokenType.null_keyword, color_catppuccin.peach },
    .{ tree_sitter.TSTokenType.property_identifier, color_catppuccin.peach },
    .{ tree_sitter.TSTokenType.integer, color_catppuccin.peach },
    .{ tree_sitter.TSTokenType.operator, color_catppuccin.teal },
    .{ tree_sitter.TSTokenType.string, color_catppuccin.green },
    .{ tree_sitter.TSTokenType.symbol, color_base },
    .{ tree_sitter.TSTokenType.lang_keyword, color_catppuccin.mauve },
    .{ tree_sitter.TSTokenType.builtin_type, color_catppuccin.yellow },
    .{ tree_sitter.TSTokenType.builtin_identifier, color_catppuccin.mauve },
    .{ tree_sitter.TSTokenType.var_keyword, color_catppuccin.mauve },
    .{ tree_sitter.TSTokenType.function, color_catppuccin.mauve },
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
