const std = @import("std");
const vaxis = @import("vaxis");
const vfxw = @import("vaxis/vxfw");
const Buffer = @import("./buffer.zig");
const keymanager = @import("./keymanager.zig");
const welcome_view = @import("./welcome_view.zig");
const EditorView = @import("./editor_view.zig");
const Renderer = @import("./renderer.zig");

const render_frame_time_ms = @divFloor(1000, 60);
const update_frame_time_ms = @divFloor(1000, 120);

pub const App = struct {
    buffer_allocator: std.mem.Allocator,

    renderer: Renderer,
    editor_view: ?*EditorView,

    is_running: bool,
};

pub fn main() !void {
    // handle renderer
    var render_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer render_allocator.deinit();

    // handle buffer
    var buffer_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer buffer_allocator.deinit();

    // create the app view
    var app: App = .{
        .buffer_allocator = buffer_allocator.allocator(),

        // .renderer = undefined,
        .renderer = try Renderer.init(render_allocator.allocator()),
        .editor_view = null,

        .is_running = false,
    };
    defer app.renderer.deinit();

    // find the argument for the file to open
    const args = try std.process.argsAlloc(buffer_allocator.allocator());
    for (args, 0..) |arg, i| {
        if (i == 1) {
            try openFile(&app, arg);
        }
    }

    // go through the main app loop
    // try startLoop(&app);

    if (app.editor_view) |editor_view| {
        editor_view.deinit();
    }
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
            if (try update(app)) {
                app.is_running = false;
                return;
            }

            // cache time for next step
            update_last_time = current_time;
        }

        // we want to limit the rendering
        elapsed = (current_time - render_last_time);
        if (elapsed >= render_frame_time_ms) {
            if (try render(app)) {
                app.is_running = false;
                return;
            }

            // cache time for next step
            render_last_time = current_time;
        }
    }
}

pub fn openFile(app: *App, file_path: []u8) !void {
    app.editor_view = null;

    // clear the old allocator first
    // TODO: how to reset the allocator?
    // _ = app.buffer_allocator.reset(.retain_capacity);
    const alloc = app.buffer_allocator;

    // TODO: setup a file picker
    // read the file
    // TODO: should inform of error
    const open_file_path = try std.fs.cwd().realpathAlloc(
        alloc,
        // "./src/fixtures/case-md.md",
        // "./src/renderer.zig",
        file_path, // TODO: handle absolutes
    );
    const buffer = try Buffer.init(alloc);
    try buffer.read(open_file_path);

    // TODO: should catch and inform
    app.editor_view = try EditorView.init(alloc, buffer);
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
    if (app.editor_view) |editor_view| {
        editor_view.update();
    }

    return false;
}

fn render(app: *App) !bool {
    const win = app.renderer.prepareRender();

    if (app.editor_view) |editor_view| {
        _ = editor_view;
        // try editor_view.render(win);
    } else {
        welcome_view.render(win);
    }

    // render the actual screen
    try app.renderer.render();

    return false;
}

test {
    _ = Buffer;
    _ = keymanager;
    _ = welcome_view;
    _ = EditorView;
    _ = Renderer;
}
