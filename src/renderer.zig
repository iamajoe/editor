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

pub fn init(alloc: std.mem.Allocator) !Renderer {
    var tty = try vaxis.Tty.init();
    var vx = try vaxis.init(alloc, .{});
    var loop: vaxis.Loop(RenderEvent) = .{
        .tty = &tty,
        .vaxis = &vx,
    };
    try loop.init();

    // clear the screen and set it up
    try vx.enterAltScreen(tty.anyWriter());
    try vx.queryTerminal(tty.anyWriter(), 1 * std.time.ns_per_s);

    return .{
        .allocator = alloc,
        .tty = tty,
        .vx = vx,
        .loop = loop,
    };
}

pub fn deinit(self: *Renderer) void {
    self.loop.stop();
    self.vx.deinit(self.allocator, self.tty.anyWriter());
    self.tty.deinit();
}

pub fn startLoop(self: *Renderer) !void {
    try self.loop.start();
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
