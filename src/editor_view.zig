const std = @import("std");
const vaxis = @import("vaxis");
const Buffer = @import("./buffer.zig");
const number = @import("./number.zig");

const EditorView = @This();

// configs
line_blank: []const u8,
show_line_numbers: bool,
is_line_number_relative: bool,

// theme
theme_col_gap: usize,
theme_line: vaxis.Style,
theme_line_selected: vaxis.Style,
theme_cursor: vaxis.Style,

// to be used internally
allocator: std.mem.Allocator,
win_width: usize,
win_height: usize,

scroll_offset_x: usize,
scroll_offset_y: usize,
cursor_list: std.ArrayList(*Cursor),

buffer: *Buffer,

const Cursor = struct {
    start_x: usize,
    start_y: usize,
    end_x: usize,
    end_y: usize,
};

pub fn init(alloc: std.mem.Allocator, buffer: *Buffer) !*EditorView {
    const editor_view = try alloc.create(EditorView);
    editor_view.* = EditorView{
        .buffer = buffer,

        // configs
        .line_blank = " ",
        .show_line_numbers = true,
        .is_line_number_relative = true,

        // theme
        .theme_col_gap = 2,
        .theme_line = .{ .dim = true },
        .theme_line_selected = .{
            .bg = .{ .rgb = [_]u8{ 50, 50, 50 } },
        },
        .theme_cursor = .{
            .bg = .{ .rgb = [_]u8{ 75, 75, 75 } },
        },

        // to be used internally
        .allocator = alloc,
        .win_width = 0,
        .win_height = 0,

        .scroll_offset_x = 0,
        .scroll_offset_y = 0,
        .cursor_list = std.ArrayList(*Cursor).init(alloc),
    };

    // add at least one cursor
    const first_cursor = try alloc.create(Cursor);
    first_cursor.* = Cursor{
        .start_x = 0,
        .start_y = 0,
        .end_x = 0,
        .end_y = 0,
    };
    try editor_view.cursor_list.append(first_cursor);

    return editor_view;
}

pub fn update(self: *EditorView) void {
    _ = self;
    // NOTE: nothing to do for now...
}

fn isSelected(
    self: *EditorView,
    row: usize,
) bool {
    if (self.cursor_list.items.len == 0) {
        return false;
    }

    const last_cursor_y = self.cursor_list.getLast().start_y;
    const is_selected_row = row == last_cursor_y;

    return is_selected_row;
}

fn getSelected(self: *EditorView) ?Buffer.Line {
    const data_lines_or_null = self.buffer.data_lines;
    if (data_lines_or_null == null) {
        return null;
    }
    const data_lines = data_lines_or_null.?;

    if (data_lines.items.len == 0) {
        return null;
    }

    for (data_lines.items, 0..) |line, i| {
        if (self.isSelected(i)) {
            return line;
        }
    }

    return null;
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
    if (self.is_line_number_relative and !isSelected(self, line_number)) {
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
    const line_number_cols = number.countDigits(self.buffer.line_count);

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

fn renderLine(
    self: *EditorView,
    win: vaxis.Window,
    render_row: usize,
    start_x: usize,
    line_offset_x: usize,
    line: Buffer.Line,
    style: vaxis.Style,
) usize {
    // TODO: enable wrapping

    const available_space: usize = win.width - start_x - 1;
    var render_pos: usize = start_x;
    var curr_line_pos: usize = 0;

    // need to calculate the max offset so it doesnt go over the line
    // offset only matters when the line is smaller than the available space
    if (line.len > available_space) {
        const diff = line.len - available_space;
        curr_line_pos = line_offset_x;
        if (diff < line_offset_x) {
            curr_line_pos = diff;
        }
    }

    // iterate each character
    if (line.len > 0) {
        for (curr_line_pos..line.len) |i| {
            // render the character
            const portion = line.data[i .. i + 1];
            win.writeCell(render_pos, render_row, .{
                .char = .{ .grapheme = portion, .width = 1 },
                .wrapped = false,
                .style = style,
            });
            curr_line_pos += 1;

            render_pos += 1;
        }
    }

    // we want to fill every wrapped line
    if (render_pos < win.width) {
        curr_line_pos = self.renderFillLine(win, render_row, render_pos, 0, style);
    }

    return render_row + 1;
}

pub fn render(self: *EditorView, win: vaxis.Window) !void {
    // cache for usage on events
    self.win_width = win.width;
    self.win_height = win.height;

    // iterate over each line on the file
    const linesOrNull = self.buffer.data_lines;
    if (linesOrNull == null) {
        return;
    }

    const lines = linesOrNull.?.items;
    var row_render: usize = 0;
    for (lines, 0..) |line, row_line| {
        // no point in render anything outside of scope
        if (row_render > win.height) {
            break;
        }

        var curr_pos: usize = 0;

        // handle selected row styles
        const is_selected = isSelected(self, row_line);
        var style = self.theme_line;
        if (is_selected) {
            style = self.theme_line_selected;
        }

        if (self.show_line_numbers) {
            curr_pos = self.renderLineGap(win, row_render, curr_pos, self.theme_col_gap, style);
            curr_pos = self.renderLineNumber(win, row_line, row_render, curr_pos, style);
        }
        curr_pos = self.renderLineGap(win, row_render, curr_pos, self.theme_col_gap, style);

        var scroll_offset_x = self.scroll_offset_x;
        if (!is_selected) {
            scroll_offset_x = 0;
        }
        row_render = self.renderLine(win, row_render, curr_pos, scroll_offset_x, line, style);
    }
}

pub fn moveCursorX(self: *EditorView, offset: usize, is_left: bool) void {
    const last_cursor_or_null = self.cursor_list.getLastOrNull();
    if (last_cursor_or_null == null) {
        self.scroll_offset_x = 0;
        return;
    }
    var last_cursor = last_cursor_or_null.?;
    var new_value: usize = 0;

    if (is_left) {
        new_value = last_cursor.start_x -| offset;
    } else {
        new_value = last_cursor.start_x +| offset;
    }

    // if we are moving without a line, just reset
    const line_or_null = self.getSelected();
    if (line_or_null == null or line_or_null.?.len == 0) {
        new_value = 0;
    }

    // something must have got wrong, get out
    if (new_value == 0) {
        last_cursor.start_x = new_value;
        last_cursor.end_x = new_value;
        self.scroll_offset_x = new_value;
        return;
    }

    last_cursor.start_x = new_value;
    last_cursor.end_x = new_value;
    self.scroll_offset_x = new_value;

    // const line = line_or_null.?;

    // TODO: this seems to not be working
    // TODO: what about gaps?
    // only let select until the last character
    // const line_number_cols = number.countDigits(self.buffer.line_count);
    // const available_space = line.len -| line_number_cols;
    // if (last_cursor.start_x > available_space) {
    //     last_cursor.start_x = available_space;
    //     last_cursor.end_x = available_space;
    //     self.scroll_offset_x = available_space;
    // }
}

pub fn moveCursorY(self: *EditorView, offset: usize, is_up: bool) void {
    const last_cursor_or_null = self.cursor_list.getLastOrNull();
    if (last_cursor_or_null == null) {
        self.scroll_offset_y = 0;
        return;
    }
    var last_cursor = last_cursor_or_null.?;

    // this must be an error but for now, just reset the cursor
    if (self.buffer.data_lines == null) {
        last_cursor.start_y = 0;
        last_cursor.end_y = 0;
        return;
    }

    if (is_up) {
        last_cursor.start_y -|= offset;
        last_cursor.end_y -|= offset;
    } else {
        last_cursor.start_y +|= offset;
        last_cursor.end_y +|= offset;
    }

    // you can't select over the last line
    if (last_cursor.start_y > self.buffer.line_count - 1) {
        last_cursor.start_y = self.buffer.line_count - 1;
        last_cursor.end_y = self.buffer.line_count - 1;
    }
}

test {
    _ = number;
}
