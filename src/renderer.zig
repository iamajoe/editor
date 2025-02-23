const std = @import("std");
const vaxis = @import("vaxis");

const Renderer = @This();
const RenderEvent = union(enum) {
    key_press: vaxis.Key,
    winsize: vaxis.Winsize,
};

allocator: std.mem.Allocator,
tty: vaxis.Tty,
vx: vaxis.Vaxis,
loop: vaxis.Loop(RenderEvent),

// REF: https://github.com/rockorager/libvaxis/blob/main/src/vxfw/App.zig
pub fn init(alloc: std.mem.Allocator) !Renderer {
    var tty = try vaxis.Tty.init();
    var vx = try vaxis.init(alloc, .{});

    return .{
        .allocator = alloc,
        .tty = tty,
        .vx = vx,
        .loop = .{
            .tty = &tty,
            .vaxis = &vx,
        },
    };
}

pub fn deinit(self: *Renderer) void {
    self.loop.stop();
    self.vx.deinit(self.allocator, self.tty.anyWriter());
    self.tty.deinit();
}

pub fn startLoop(self: *Renderer) !void {
    // clear the screen and set it up
    try self.vx.enterAltScreen(self.tty.anyWriter());
    try self.vx.queryTerminal(self.tty.anyWriter(), 1 * std.time.ns_per_s);

    {
        // loop.init installs a signal handler for the tty. We wait to
        // init the loop until we know if we need this handler.
        // We don't need it if the terminal supports in-band-resize
        if (!self.vx.state.in_band_resize) {
            try self.loop.init();
        }
    }

    // TODO: getting out, is not setting the terminal as it was before
    try self.loop.start();

    // try vx.setMouseMode(tty.anyWriter(), true);
}

pub fn tryEvent(self: *Renderer) !?RenderEvent {
    // handle the events
    const eventFound = self.loop.tryEvent();
    if (eventFound) |event| {
        switch (event) {
            .winsize => |ws| {
                try self.vx.resize(self.allocator, self.tty.anyWriter(), ws);
                return event;
            },
            else => {},
        }

        return event;
    }

    return null;
}

pub fn prepareRender(self: *Renderer) vaxis.Window {
    // prepare the window for rendering
    const win = self.vx.window();
    win.clear();

    return win;
}

pub fn render(self: *Renderer) !void {
    try self.vx.render(self.tty.anyWriter());
}
