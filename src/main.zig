const std = @import("std");
const vaxis = @import("vaxis");
const EditorView = @import("./editor_view.zig");
const Renderer = @import("./renderer.zig");

const max_fps = 30;
const frame_time_ms = @divFloor(1000, max_fps);
const max_file_buffer_size = 50000;

const App = struct {
    allocator: std.mem.Allocator,
    renderer: Renderer,

    is_running: bool,

    editor_view: EditorView,
};

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
        .is_running = false,

        .editor_view = .{
            .allocator = alloc,
            .file_data = null,
            .selected_row = 0,
            .selected_col = 0,
            .show_line_numbers = true,
            .is_line_number_relative = true,
        },
    };
    defer app.renderer.deinit();

    // read the file into lines
    // TODO: should inform of error
    const open_file_path = try std.fs.path.join(alloc, &[_][]const u8{
        try std.fs.cwd().realpathAlloc(alloc, "."),
        "src/main.zig",
    });
    const open_file_lines = try readFile(alloc, open_file_path);
    // TODO: should inform of error reading the file
    try app.editor_view.setFileData(open_file_lines);

    // go through the main app loop
    try startLoop(&app);
}

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

fn startLoop(app: *App) !void {
    app.is_running = true;
    try app.renderer.startLoop();

    var last_time = std.time.milliTimestamp();

    while (app.is_running) {
        var shouldBreak = try update(app);
        if (shouldBreak) {
            app.is_running = false;
            return;
        }

        // we want to limit the rendering to the maximum frames per second
        const current_time = std.time.milliTimestamp();
        const elapsed = (current_time - last_time);
        if (elapsed >= frame_time_ms) {
            shouldBreak = try render(app);
            if (shouldBreak) {
                app.is_running = false;
                return;
            }

            // cache time for next step
            last_time = current_time;
        }
    }
}

fn update(app: *App) !bool {
    // handle event if we have one
    const eventFound = try app.renderer.tryEvent();
    if (eventFound) |event| {
        switch (event) {
            .key_press => |key| {
                if (key.matches('c', .{ .ctrl = true })) {
                    return true;
                }

                // TODO: handle actions
            },
            else => {},
        }
    }

    app.editor_view.update();

    return false;
}

fn render(app: *App) !bool {
    const win = app.renderer.prepareRender();

    try app.editor_view.render(win);

    // render the actual screen
    try app.renderer.render();

    return false;
}
