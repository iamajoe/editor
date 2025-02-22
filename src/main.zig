const std = @import("std");
const vaxis = @import("vaxis");
const Renderer = @import("./renderer.zig");

const max_file_buffer_size = 50000;

const App = struct {
    allocator: std.mem.Allocator,
    renderer: Renderer,

    open_file_path: ?[]u8,
    open_file_lines: ?std.ArrayList([]const u8),
};

fn readFile(
    allocator: std.mem.Allocator,
    absolute_path: []u8,
) !std.ArrayList([]const u8) {
    const file = try std.fs.openFileAbsolute(absolute_path, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();
    var file_data = std.ArrayList([]const u8).init(allocator);

    // go line by line on the file caching it
    var buf: [max_file_buffer_size]u8 = undefined;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        const duped = try allocator.dupe(u8, line);
        try file_data.append(duped);
    }

    return file_data;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        _ = gpa.detectLeaks();
        _ = gpa.deinit();
    }
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const alloc = arena.allocator();

    // create the app
    var app: App = .{
        .allocator = alloc,
        .renderer = try Renderer.init(alloc),

        .open_file_path = null,
        .open_file_lines = null,
    };
    defer app.renderer.deinit();

    // read the file into lines
    // TODO: should inform of error
    app.open_file_path = try std.fs.path.join(alloc, &[_][]const u8{
        try std.fs.cwd().realpathAlloc(alloc, "."),
        "src/main.zig",
    });
    if (app.open_file_path) |file_path| {
        app.open_file_lines = try readFile(alloc, file_path);
        // TODO: should inform of error
    }

    // go through the main app loop
    try app.renderer.startLoop();
    while (true) {
        const eventFound = try app.renderer.waitForEvent();
        switch (eventFound) {
            .key_press => |key| {
                if (key.matches('c', .{ .ctrl = true })) {
                    return;
                }

                // TODO: what else?!
            },
            else => {},
        }

        // render the screen
        try app.renderer.render();
    }
}
