const std = @import("std");
const vaxis = @import("vaxis");

pub var should_debug: bool = false;
var alloc: std.mem.Allocator = undefined;
var data: std.ArrayList([]const u8) = undefined;

pub fn init(allocator: std.mem.Allocator, set_debug: bool) void {
    should_debug = set_debug;
    if (!should_debug) {
        return;
    }

    alloc = allocator;
    data = std.ArrayList([]const u8).init(alloc);
}

pub fn clear() void {
    if (!should_debug or data.items.len == 0) {
        return;
    }

    data.clearAndFree();
}

pub fn add(new_data: []const u8) !void {
    if (!should_debug) {
        return;
    }

    const copied = try alloc.dupe(u8, new_data);
    try data.append(copied);
}

pub fn render(win: vaxis.Window) !void {
    if (!should_debug or data.items.len == 0) {
        return;
    }

    // std.debug.print("ITEMS TO DEBUG {d} {s}\n", .{ data.items.len, data.items[0] });

    for (data.items, 0..) |line, row| {
        win.writeCell(win.width - line.len, row, .{
            .char = .{ .grapheme = line, .width = line.len },
            .wrapped = false,
            .style = .{
                .fg = .{ .rgb = [_]u8{ 255, 0, 0 } },
                .bg = .{ .rgb = [_]u8{ 50, 50, 50 } },
            },
        });
    }
}
