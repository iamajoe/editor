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

const TSTokenType = enum {
    none, // means it hasn't found one

    comment,
    identifier,
    number,
    operator, // +, -, /, *, =
    string,
    symbol, // ;, ,, :, (, ), {, }

    var_keyword, // const, var, let...
    function, // function, fn, fun
};
const symbol_to_token_map: [24]std.meta.Tuple(&.{ TSTokenType, [3]u8 }) = .{
    .{ TSTokenType.none, color_base },
};

const theme_col_gap: usize = 2;
const theme_line: vaxis.Style = .{
    // .dim = true,
};
const theme_line_selected: vaxis.Style = .{
    .bg = .{ .rgb = [_]u8{ 50, 50, 50 } },
};
const theme_cursor: vaxis.Style = .{
    .bg = .{ .rgb = [_]u8{ 75, 75, 75 } },
};

fn getToken(kind: []const u8) TSTokenType {
    if (std.mem.eql(u8, kind, "comment")) {
        return TSTokenType.comment;
    }

    if (std.mem.eql(u8, kind, "identifier") or std.mem.eql(u8, kind, "property_identifier") or std.mem.eql(u8, kind, "shorthand_property_identifier_pattern")) {
        return TSTokenType.identifier;
    }

    if (std.mem.eql(u8, kind, "number")) {
        return TSTokenType.number;
    }

    if (std.mem.eql(u8, kind, "+") or std.mem.eql(u8, kind, "-") or std.mem.eql(u8, kind, "/") or std.mem.eql(u8, kind, "*") or std.mem.eql(u8, kind, "=")) {
        return TSTokenType.operator;
    }

    if (std.mem.eql(u8, kind, "string") or std.mem.eql(u8, kind, "template_string")) {
        return TSTokenType.string;
    }

    if (std.mem.eql(u8, kind, ";") or std.mem.eql(u8, kind, ",") or std.mem.eql(u8, kind, ":") or std.mem.eql(u8, kind, ".") or std.mem.eql(u8, kind, "=")) {
        return TSTokenType.symbol;
    }

    if (std.mem.eql(u8, kind, "(") or std.mem.eql(u8, kind, ")") or std.mem.eql(u8, kind, "{") or std.mem.eql(u8, kind, "}") or std.mem.eql(u8, kind, "[") or std.mem.eql(u8, kind, "]")) {
        return TSTokenType.symbol;
    }

    if (std.mem.eql(u8, kind, "var") or std.mem.eql(u8, kind, "const") or std.mem.eql(u8, kind, "let")) {
        return TSTokenType.var_keyword;
    }

    if (std.mem.eql(u8, kind, "function") or std.mem.eql(u8, kind, "fn") or std.mem.eql(u8, kind, "fun")) {
        return TSTokenType.function;
    }

    return TSTokenType.none;
}

fn getTokenColor(token: TSTokenType) [3]u8 {
    var color = color_base;

    switch (token) {
        TSTokenType.comment => {
            color = color_base;
        },
        TSTokenType.identifier => {
            color = color_catppuccin.text;
        },
        TSTokenType.number => {
            color = color_catppuccin.maroon;
        },
        TSTokenType.operator => {
            color = color_catppuccin.teal;
        },
        TSTokenType.string => {
            color = color_catppuccin.green;
        },
        TSTokenType.symbol => {
            color = color_base;
        },

        TSTokenType.var_keyword => {
            color = color_catppuccin.mauve;
        },
        TSTokenType.function => {
            color = color_catppuccin.mauve;
        },

        else => {
            // do nothing...
        },
    }

    return color;
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
