const std = @import("std");
const vaxis = @import("vaxis");
const number = @import("./number.zig");

const EditorView = @This();

// configs
line_blank: []const u8,
line_number_pad_to_code: usize,
show_line_numbers: bool,
is_line_number_relative: bool,

// to be used internally
allocator: std.mem.Allocator,
selected_row: usize,
selected_col: usize,
line_number_cols: usize,
file_data: ?std.ArrayList([]const u8),

pub fn setFileData(self: *EditorView, file_data: std.ArrayList([]const u8)) !void {
    self.selected_row = 24; // TODO: uncomment: 0;
    self.selected_col = 0;
    self.file_data = file_data;

    // find how many lines we have in the file so we can figure
    self.line_number_cols = number.countDigits(file_data.items.len);
}

pub fn update(self: *EditorView) void {
    _ = self;

    // nothing to do for now on update
}

fn renderLineNumbers(
    self: *EditorView,
    win: vaxis.Window,
    row: usize,
    offset_x: usize,
) usize {
    const is_selected_row = row == self.selected_row;
    var curr_pos = offset_x;

    // handle selected row styles
    var number_style = vaxis.Style{ .dim = true };
    if (is_selected_row) {
        const color = [_]u8{ 50, 50, 50 };
        number_style.dim = false;
        number_style.bg = .{
            .rgb = color,
        };
    }

    // handle relative numbers
    // we want +1 because we show the current line number
    // from 1 not 0 as the index is
    var curr_num = row + 1;
    if (self.is_line_number_relative and !is_selected_row) {
        if (curr_num > self.selected_row) {
            curr_num = row -| self.selected_row;
        } else {
            curr_num = self.selected_row -| row;
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
    for (0..self.line_number_pad_to_code) |i| {
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
    const is_selected_row = row == self.selected_row;
    var curr_pos = offset_x;

    var line_style = vaxis.Style{};
    if (is_selected_row) {
        const color = [_]u8{ 50, 50, 50 };

        // TODO: how to do bg the whole line
        line_style.bg = .{
            .rgb = color,
        };
    }

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
    // iterate over each line on the file
    var row: usize = 0;
    for (self.file_data.?.items) |line| {
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
        curr_pos = self.renderLine(win, row, curr_pos, line);

        // advance the row
        row += 1;
    }

    // you can't select over the last line
    if (self.selected_row > row) {
        self.selected_row = row;
    }
}

test {
    _ = number;
}
