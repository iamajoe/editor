const std = @import("std");
const vaxis = @import("vaxis");
const number = @import("./number.zig");

const EditorView = @This();

// configs
line_blank: []const u8,
show_line_numbers: bool,
is_line_number_relative: bool,

// theme
theme_number_right_pad: usize,
theme_number: vaxis.Style,
theme_number_selected: vaxis.Style,
theme_code_base: vaxis.Style,
theme_code_base_selected: vaxis.Style,

// to be used internally
cursor_x: usize,
cursor_y: usize,

line_count: usize,
line_number_cols: usize,
file_data: ?std.ArrayList([]const u8),

pub fn setFileData(self: *EditorView, file_data: std.ArrayList([]const u8)) !void {
    self.cursor_x = 24; // TODO: uncomment: 0;
    self.cursor_y = 24; // TODO: uncomment: 0;
    self.file_data = file_data;

    // find how many lines we have in the file so we can figure
    self.line_count = file_data.items.len;
    self.line_number_cols = number.countDigits(file_data.items.len);
}

pub fn update(self: *EditorView) void {
    _ = self;
    // you can't select over the last line
    // if (self.cursor_y > self.line_count) {
    //     self.cursor_y = self.line_count;
    // }
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
    const diff = self.line_number_cols - num_digits;
    var digit_index: usize = 0;

    // iterate each column and add the number
    for (0..self.line_number_cols) |i| {
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

    // set extra padding for the code
    for (0..self.theme_number_right_pad) |i| {
        _ = i;
        win.writeCell(curr_pos, row, .{
            .char = .{ .grapheme = self.line_blank, .width = 1 },
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
    const is_selected_row = row == self.cursor_y;
    var curr_pos = offset_x;

    var line_style = self.theme_code_base;
    if (is_selected_row) {
        line_style = self.theme_code_base_selected;
    }

    // TODO: when actually building the syntax coloring,
    //       we will need to extend instead of assign

    win.writeCell(curr_pos, row, .{
        .char = .{ .grapheme = line, .width = line.len },
        .style = line_style,
    });
    curr_pos += line.len;

    // render the remaining of the selected row line
    if (is_selected_row) {
        while (curr_pos < win.width) {
            win.writeCell(curr_pos, row, .{
                .char = .{
                    .grapheme = self.line_blank,
                    .width = 1,
                },
                .style = line_style,
            });
            curr_pos += 1;
        }
    }

    return curr_pos;
}

pub fn render(self: *EditorView, win: vaxis.Window) !void {
    _ = self;
    _ = win;

    // iterate over each line on the file
    // for (self.file_data.?.items, 0..) |line, row| {
    //     // no point in render anything outside of scope
    //     if (row > win.height) {
    //         break;
    //     }
    //
    //     var curr_pos: usize = 0;
    //
    //     // render number
    //     if (self.show_line_numbers) {
    //         curr_pos = self.renderLineNumbers(win, row, curr_pos);
    //     }
    //
    //     // render line
    //     // TODO: what about wrapped code?
    //     curr_pos = self.renderLine(win, row, curr_pos, line);
    // }
}

pub fn moveCursorX(self: *EditorView, offset: isize) void {
    _ = self;
    _ = offset;
    // we can't do anything if already 0
    // if (offset < 0 and self.cursor_x == 0) {
    //     return;
    // }

    // std.debug.print("new cursor x: {d}\n", .{offset});
    // const icursor: isize = @intCast(self.cursor_x);
    // const new_cursor: isize = icursor +| offset;
    // self.cursor_x = @intCast(new_cursor);
}

pub fn moveCursorY(self: *EditorView, offset: isize) void {
    _ = self;
    _ = offset;
    // we can't do anything if already 0
    // if (offset < 0 and self.cursor_y == 0) {
    //     return;
    // }

    // std.debug.print("new cursor y: {d}\n", .{offset});
    // const icursor: isize = @intCast(self.cursor_y);
    // const new_cursor: isize = icursor +| offset;
    // self.cursor_y = @intCast(new_cursor);
}

test {
    _ = number;
}
