const std = @import("std");
const vaxis = @import("vaxis");
const vfxw = @import("vaxis/vxfw");
const buffer = @import("./buffer.zig");
const keymanager = @import("./keymanager.zig");
const welcome_view = @import("./welcome_view.zig");
const EditorView = @import("./editor_view.zig");
const Renderer = @import("./renderer.zig");

const render_frame_time_ms = @divFloor(1000, 30);
const update_frame_time_ms = @divFloor(1000, 60);
const max_file_buffer_size = 50000;

pub const App = struct {
    buffer_allocator: std.heap.ArenaAllocator,

    renderer: Renderer,
    editor_view: ?*EditorView,

    is_running: bool,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        _ = gpa.detectLeaks();
        _ = gpa.deinit();
    }

    // create the app view
    var app: App = .{
        .buffer_allocator = std.heap.ArenaAllocator.init(gpa.allocator()),

        .renderer = try Renderer.init(gpa.allocator()),
        .editor_view = null,

        .is_running = false,
    };
    defer app.buffer_allocator.deinit();
    defer app.renderer.deinit();

    // go through the main app loop
    try startLoop(&app);
}

fn startLoop(app: *App) !void {
    app.is_running = true;
    try app.renderer.startLoop();

    var update_last_time = std.time.milliTimestamp();
    var render_last_time = std.time.milliTimestamp();

    while (app.is_running) {
        const current_time = std.time.milliTimestamp();

        // we want to limit the updates
        var elapsed = (current_time - update_last_time);
        if (elapsed >= update_frame_time_ms) {
            const shouldBreak = try update(app);
            if (shouldBreak) {
                app.is_running = false;
                return;
            }

            // cache time for next step
            update_last_time = current_time;
        }

        // we want to limit the rendering
        elapsed = (current_time - render_last_time);
        if (elapsed >= render_frame_time_ms) {
            const shouldBreak = try render(app);
            if (shouldBreak) {
                app.is_running = false;
                return;
            }

            // cache time for next step
            render_last_time = current_time;
        }
    }
}

pub fn openFile(app: *App) !void {
    app.editor_view = null;

    // clear the old allocator first
    // _ = app.buffer_allocator.reset(.retain_capacity);
    const alloc = app.buffer_allocator.allocator();

    // TODO: setup a file picker
    // read the file into lines
    // TODO: should inform of error
    const open_file_path = try std.fs.path.join(alloc, &[_][]const u8{
        try std.fs.cwd().realpathAlloc(alloc, "."),
        "src/main.zig",
    });
    // _ = open_file_path;
    // TODO: should inform of error reading the file
    const open_file_lines = try buffer.readFile(alloc, open_file_path);
    _ = open_file_lines;

    // create the editor view
    const editor_view = try alloc.create(EditorView);
    _ = editor_view;
    // editor_view.* = EditorView{
    //     // configs
    //     .line_blank = " ",
    //     .show_line_numbers = true,
    //     .is_line_number_relative = true,
    //
    //     // theme
    //     .theme_number_right_pad = 2,
    //     .theme_number = vaxis.Style{ .dim = true },
    //     .theme_number_selected = vaxis.Style{
    //         .bg = .{ .rgb = [_]u8{ 50, 50, 50 } },
    //     },
    //     .theme_code_base = vaxis.Style{},
    //     .theme_code_base_selected = vaxis.Style{
    //         .bg = .{ .rgb = [_]u8{ 50, 50, 50 } },
    //     },
    //
    //     // to be used internally
    //     .cursor_x = undefined,
    //     .cursor_y = undefined,
    //     .line_count = undefined,
    //     .line_number_cols = undefined,
    //     .file_data = null,
    // };

    // // TODO: should catch and inform
    // try editor_view.setFileData(open_file_lines);
    // app.editor_view = editor_view;
}

fn update(app: *App) !bool {
    // handle event if we have one
    const eventFound = try app.renderer.tryEvent();
    if (eventFound) |event| {
        switch (event) {
            .key_press => |key| {
                const shouldBreak = try keymanager.handleKey(app, key);
                if (shouldBreak) {
                    return true;
                }
            },
            else => {},
        }
    }

    // update the editor
    // if (app.editor_view) |editor_view| {
    //     editor_view.update();
    // }

    return false;
}

fn render(app: *App) !bool {
    const win = app.renderer.prepareRender();

    if (app.editor_view) |editor_view| {
        try editor_view.render(win);
        // } else {
        //     welcome_view.render(win);
    }

    // render the actual screen
    try app.renderer.render();

    return false;
}

test {
    _ = buffer;
    _ = EditorView;
    _ = Renderer;
}
