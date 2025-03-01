const std = @import("std");
const vaxis = @import("vaxis");
const grapheme = @import("grapheme");
const tree_sitter = @import("./tree_sitter.zig");
const Buffer = @import("./buffer.zig");
const theme = @import("./theme.zig");
const debug = @import("./debug.zig");
const number = @import("./number.zig");

const EditorView = @This();

// configs
line_blank: []const u8,
show_line_numbers: bool,
is_line_number_relative: bool,

// to be used internally
allocator: std.mem.Allocator,
win_width: usize,
win_height: usize,

offset: struct {
    x: usize,
    y: usize,
},
cursor: struct {
    x: usize,
    y: usize,
},

buffer: *Buffer,

pub fn init(alloc: std.mem.Allocator, buffer: *Buffer) !*EditorView {
    const editor_view = try alloc.create(EditorView);
    editor_view.* = EditorView{
        .buffer = buffer,

        // configs
        .line_blank = " ",
        .show_line_numbers = true,
        .is_line_number_relative = true,

        // to be used internally
        .allocator = alloc,
        .win_width = 0,
        .win_height = 0,

        .offset = .{ .x = 0, .y = 0 },
        .cursor = .{ .x = 0, .y = 0 },
    };

    return editor_view;
}

pub fn deinit(self: *EditorView) void {
    self.buffer.deinit();
}

fn renderFillLine(
    self: *EditorView,
    win: vaxis.Window,
    row: usize,
    start_x: usize,
    gap_right: usize,
    style: vaxis.Style,
) usize {
    if (start_x >= (win.width -| gap_right)) {
        return start_x;
    }

    var curr_pos = start_x;
    while (curr_pos < win.width - gap_right) {
        win.writeCell(curr_pos, row, .{
            .char = .{ .grapheme = self.line_blank, .width = 1 },
            .wrapped = false,
            .style = style,
        });

        curr_pos += 1;
    }

    return curr_pos;
}

fn renderLineGap(
    self: *EditorView,
    win: vaxis.Window,
    row: usize,
    start_x: usize,
    gap: usize,
    style: vaxis.Style,
) usize {
    if (gap == 0) {
        return start_x;
    }

    var curr_pos = start_x;
    for (0..gap) |i| {
        _ = i;
        win.writeCell(curr_pos, row, .{
            .char = .{ .grapheme = self.line_blank, .width = 1 },
            .wrapped = false,
            .style = style,
        });
        curr_pos += 1;
    }

    return curr_pos;
}

fn renderLineNumber(
    self: *EditorView,
    win: vaxis.Window,
    line_number: usize,
    render_row: usize,
    start_x: usize,
    style: vaxis.Style,
) usize {
    var curr_pos = start_x;

    // handle relative numbers
    // we want +1 because we show the current line number
    // from 1 not 0 as the index is
    var curr_num = line_number + 1;
    // if (self.is_line_number_relative and !isSelected(self, line_number)) {
    if (self.is_line_number_relative) {
        // if (self.is_line_number_relative and !isSelected(self, row) and self.cursor_list.items.len > 0) {
        const last_cursor_y: usize = 0;
        // const last_cursor_y = self.cursor_list.getLast().end_y;
        if (curr_num > last_cursor_y) {
            curr_num = line_number -| last_cursor_y;
        } else {
            curr_num = last_cursor_y -| line_number;
        }
    }

    const num_digits = number.countDigits(curr_num);
    // TODO: need to do this...
    // const line_number_cols = number.countDigits(self.buffer.line_count);
    const line_number_cols = number.countDigits(1000);

    const diff = line_number_cols - num_digits;
    var digit_index: usize = 0;

    // iterate each column and add the number
    for (0..line_number_cols) |i| {
        var char: []const u8 = self.line_blank;
        if (i >= diff) {
            const digit = number.extractDigitFromLeft(curr_num, digit_index);
            char = number.digitToStr(digit);
            digit_index += 1;
        }

        // render the number
        win.writeCell(curr_pos, render_row, .{
            .char = .{
                .grapheme = char,
                .width = 1,
            },
            .style = style,
        });

        curr_pos += 1;
    }

    return curr_pos;
}

pub fn update(self: *EditorView) void {
    _ = self;
    // TODO: should have something like... "has been modified"
    //       no point in making calculations without modifications
    //       dont forget, changing cursor can be considered a modification
    //       either that or we compute the whole file onc
    //       maybe cached struct should have a "should render"
    // TODO: calculate each character that can be renderer and cache
    //       the style
    // NOTE: nothing to do for now...
}

pub fn render(self: *EditorView, win: vaxis.Window) !void {
    // cache for usage on events
    self.win_width = win.width;
    self.win_height = win.height;

    if (self.buffer.data == null) {
        return;
    }

    const gd = try grapheme.GraphemeData.init(self.allocator);
    defer gd.deinit();

    const data = self.buffer.data.?;
    var row: usize = 0;
    var col: usize = 0;
    var i: usize = 0;
    var iter = grapheme.Iterator.init(data, &gd);

    var last_node_kind = tree_sitter.TSTokenType.none;
    var style: vaxis.Style = theme.getStyle(last_node_kind, false, false);

    while (iter.next()) |gc| : (i += 1) {
        // no point in render anything outside of scope
        if (row >= win.height - 1) {
            break;
        }

        const char = gc.bytes(data);

        // find the selections
        const is_line_selected = row == self.cursor.y;
        var is_cursor = false;
        if (is_line_selected) {
            // need to cap cursor to the end of the line
            var cursor_x = self.cursor.x;
            if (iter.peek()) |next| {
                const next_char = next.bytes(data);
                if (std.mem.eql(u8, next_char, "\n") and cursor_x > col) {
                    cursor_x = col;
                }
            }

            is_cursor = col == cursor_x;
        }

        // decide style if the node kind changed
        const node_kind = try self.buffer.highlightAt(row, col);
        if (tree_sitter.TSTokenType.none != node_kind) {
            last_node_kind = node_kind;
        }
        style = theme.getStyle(last_node_kind, is_line_selected, is_cursor);

        // ignore any new lines
        const is_newline = std.mem.eql(u8, char, "\n");
        if (!is_newline) {
            win.writeCell(col, row, .{
                .char = .{ .grapheme = char, .width = 1 },
                .wrapped = false,
                .style = style,
            });
            col += 1;
        } else {
            _ = self.renderFillLine(win, row, col, 0, style);
            row += 1;
            col = 0;
        }
    }
}

pub fn moveCursorX(self: *EditorView, offset: usize, is_left: bool) void {
    var new_value: usize = self.cursor.x;

    if (is_left) {
        new_value -|= offset;
    } else {
        new_value +|= offset;
    }

    // TODO: set the limit on the line

    self.cursor.x = new_value;
}

pub fn moveCursorY(self: *EditorView, offset: usize, is_up: bool) void {
    var new_value: usize = self.cursor.y;

    if (is_up) {
        new_value -|= offset;
    } else {
        new_value +|= offset;
    }

    // TODO: set the limit on the page

    self.cursor.y = new_value;
}

test {
    _ = number;
    _ = theme;
}
