const std = @import("std");
const vaxis = @import("vaxis");

const EditorView = @This();

selected_row: usize,
selected_col: usize,
file_data: ?std.ArrayList([]const u8),

pub fn setFileData(self: *EditorView, file_data: std.ArrayList([]const u8)) void {
    self.selected_row = 0;
    self.selected_col = 0;
    self.file_data = file_data;
}

pub fn update(self: *EditorView) void {
    _ = self;

    // nothing to do for now on update
}

pub fn render(self: *EditorView, win: vaxis.Window) void {
    // iterate over each line on the file
    var last_row: usize = 0;
    for (self.file_data.?.items) |line| {
        // render some text on the screen
        win.writeCell(0, last_row, .{
            .char = .{ .grapheme = line, .width = win.width - 4 },
            .wrapped = true,
            .style = vaxis.Style{},
        });

        last_row += 1;
    }

    // you can't select over the last line
    if (self.selected_row > last_row) {
        self.selected_row = last_row;
    }
}
