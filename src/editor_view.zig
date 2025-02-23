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
theme_number_left_pad: usize,
theme_number_right_pad: usize,
theme_number: vaxis.Style,
theme_number_selected: vaxis.Style,
theme_code_left_pad: usize,
theme_code_base: vaxis.Style,
theme_code_base_selected: vaxis.Style,

// to be used internally
allocator: std.mem.Allocator,
win_width: usize,
win_height: usize,
cursor_x: usize,
cursor_y: usize,

buffer: ?*Buffer,

pub fn update(self: *EditorView) void {
    _ = self;
    // NOTE: nothing to do for now...
}

fn renderLineNumbers(
    self: *EditorView,
    win: vaxis.Window,
    row: usize,
    offset_x: usize,
) usize {
    const is_selected_row = row == self.cursor_y;
    var curr_pos = offset_x;

    // handle selected row styles
    var number_style = self.theme_number;
    if (is_selected_row) {
        number_style = self.theme_number_selected;
    }

    // handle relative numbers
    // we want +1 because we show the current line number
    // from 1 not 0 as the index is
    var curr_num = row + 1;
    if (self.is_line_number_relative and !is_selected_row) {
        if (curr_num > self.cursor_y) {
            curr_num = row -| self.cursor_y;
        } else {
            curr_num = self.cursor_y -| row;
        }
    }

    const num_digits = number.countDigits(curr_num);
    const line_number_cols = number.countDigits(self.buffer.?.line_count);

    const diff = line_number_cols - num_digits;
    var digit_index: usize = 0;

    // set extra padding for the left
    for (0..self.theme_number_left_pad) |i| {
        _ = i;
        win.writeCell(curr_pos, row, .{
            .char = .{ .grapheme = self.line_blank, .width = 1 },
            .wrapped = false,
            .style = number_style,
        });
        curr_pos += 1;
    }

    // iterate each column and add the number
    for (0..line_number_cols) |i| {
        var char: []const u8 = self.line_blank;
        if (i >= diff) {
            const digit = number.extractDigitFromLeft(curr_num, digit_index);
            char = number.digitToStr(digit);
            digit_index += 1;
        }

        // render the number
        win.writeCell(curr_pos, row, .{
            .char = .{
                .grapheme = char,
                .width = 1,
            },
            .style = number_style,
        });

        curr_pos += 1;
    }

    // set extra padding for the right
    for (0..self.theme_number_right_pad) |i| {
        _ = i;
        win.writeCell(curr_pos, row, .{
            .char = .{ .grapheme = self.line_blank, .width = 1 },
            .wrapped = false,
            .style = number_style,
        });
        curr_pos += 1;
    }

    return curr_pos;
}

fn renderLine(
    self: *EditorView,
    win: vaxis.Window,
    row: usize,
    offset_x: usize,
    line: []const u8,
) usize {
    // std.debug.print("selected row {d} cursor: {d}\n", .{ row, self.cursor_y });
    const is_selected_row = row == self.cursor_y;
    var curr_pos = offset_x;

    var line_style = self.theme_code_base;
    if (is_selected_row) {
        line_style = self.theme_code_base_selected;
    }

    // figure the left pad
    var left_pad = self.theme_code_left_pad;
    if (self.show_line_numbers) {
        if (self.theme_code_left_pad > self.theme_number_right_pad) {
            left_pad = self.theme_code_left_pad - self.theme_number_right_pad;
        } else {
            left_pad = 0;
        }
    }
    // set extra padding for the left
    for (0..left_pad) |i| {
        _ = i;
        win.writeCell(curr_pos, row, .{
            .char = .{ .grapheme = self.line_blank, .width = 1 },
            .wrapped = false,
            .style = line_style,
        });
        curr_pos += 1;
    }

    // TODO: when actually building the syntax coloring,
    //       we will need to extend instead of assign

    win.writeCell(curr_pos, row, .{
        .char = .{ .grapheme = line, .width = line.len },
        .wrapped = false,
        .style = line_style,
    });
    curr_pos += line.len;

    // render the remaining row
    while (curr_pos < win.width) {
        win.writeCell(curr_pos, row, .{
            .char = .{
                .grapheme = self.line_blank,
                .width = 1,
            },
            .wrapped = false,
            .style = line_style,
        });
        curr_pos += 1;
    }

    return curr_pos;
}

pub fn render(self: *EditorView, win: vaxis.Window) !void {
    // cache for usage on events
    self.win_width = win.width;
    self.win_height = win.height;

    if (self.buffer == null) {
        return;
    }

    // iterate over each line on the file
    const lines = self.buffer.?.data_lines.?.items;
    for (lines, 0..) |line, row| {
        // no point in render anything outside of scope
        if (row > win.height) {
            break;
        }

        var curr_pos: usize = 0;

        // render number
        if (self.show_line_numbers) {
            curr_pos = self.renderLineNumbers(win, row, curr_pos);
        }

        // render line
        // TODO: what about wrapped code?
        // _ = line;
        curr_pos = self.renderLine(win, row, curr_pos, line);
    }
}

pub fn moveCursorX(self: *EditorView, offset: usize, isLeft: bool) void {
    if (isLeft) {
        self.cursor_x -|= offset;
    } else {
        self.cursor_x +|= offset;
    }

    // you can't select over the last line
    if (self.cursor_x > self.win_width) {
        self.cursor_x = self.win_width;
    }
}

pub fn moveCursorY(self: *EditorView, offset: usize, isUp: bool) void {
    if (isUp) {
        self.cursor_y -|= offset;
    } else {
        self.cursor_y +|= offset;
    }

    // you can't select over the last line
    if (self.buffer) |buffer| {
        if (self.cursor_y > buffer.line_count) {
            self.cursor_y = buffer.line_count;
        }
    }
}

test {
    _ = number;
}
