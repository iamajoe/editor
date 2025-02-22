const std = @import("std");
const vaxis = @import("vaxis");

const EditorView = @This();
const line_number_padding = 8;
const line_number_filler = "{d: >6}  "; // needs to be -1
const line_blank = " ";

allocator: std.mem.Allocator,
selected_row: usize,
selected_col: usize,
show_line_numbers: bool,
is_line_number_relative: bool,
file_data: ?std.ArrayList([]const u8),

pub fn setFileData(self: *EditorView, file_data: std.ArrayList([]const u8)) !void {
    self.selected_row = 24; // TODO: uncomment: 0;
    self.selected_col = 0;
    self.file_data = file_data;

    // TODO: is there a better way to set this value?
    // var lines_temp_buf: [1000000]u8 = undefined;
    // const last_line = try std.fmt.bufPrintZ(&lines_temp_buf, "{d}", .{file_data.items.len});
    // self.lines_len = last_line.len;
}

pub fn update(self: *EditorView) void {
    _ = self;

    // nothing to do for now on update
}

pub fn render(self: *EditorView, win: vaxis.Window) !void {
    // iterate over each line on the file
    var last_row: usize = 0;
    for (self.file_data.?.items) |line| {
        // no point in render anything outside of scope
        // TODO: wrapped will make this not work that well
        //       need to figure how wrapped works
        if (last_row > win.height) {
            break;
        }

        // TODO: how can we make this one dynamic?
        var padding_left: usize = 0;
        if (self.show_line_numbers) {
            padding_left = line_number_padding;
        }

        const is_selected_row = last_row == self.selected_row;
        var curr_pos: usize = 0;
        var curr_num = last_row + 1;

        // handle relative numbers
        if (self.is_line_number_relative and !is_selected_row) {
            if (curr_num > self.selected_row) {
                curr_num = curr_num -| self.selected_row -| 1;
            } else {
                curr_num = self.selected_row -| curr_num +| 1;
            }
        }

        // construct styles
        var line_style = vaxis.Style{};
        var number_style = vaxis.Style{
            .dim = true,
        };

        // handle selected row styles
        if (is_selected_row) {
            const color = [_]u8{ 50, 50, 50 };

            // TODO: how to do bg the whole line
            line_style.bg = .{
                .rgb = color,
            };

            number_style.dim = false;
            number_style.bg = .{
                .rgb = color,
            };
        }

        // render number
        if (self.show_line_numbers) {
            // get the right number template
            const num = try self.allocator.create([line_number_padding]u8);
            _ = try std.fmt.bufPrint(num, line_number_filler, .{curr_num});

            win.writeCell(curr_pos, last_row, .{
                .char = .{ .grapheme = num, .width = padding_left },
                .style = number_style,
            });
            curr_pos += padding_left;
        }

        // render line
        win.writeCell(curr_pos, last_row, .{
            .char = .{
                .grapheme = line,
                .width = line.len,
            },
            .wrapped = true,
            .style = line_style,
        });
        curr_pos += line.len;

        // render the remaining of the selected row line
        if (is_selected_row) {
            while (curr_pos < win.width) {
                win.writeCell(curr_pos, last_row, .{
                    .char = .{
                        .grapheme = line_blank,
                        .width = 1,
                    },
                    .style = line_style,
                });
                curr_pos += 1;
            }
        }

        last_row += 1;
    }

    // you can't select over the last line
    if (self.selected_row > last_row) {
        self.selected_row = last_row;
    }
}
