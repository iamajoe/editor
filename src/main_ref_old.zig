const std = @import("std");
const vaxis = @import("vaxis");

const TextInput = vaxis.widgets.TextInput;
const TextView = vaxis.widgets.TextView;

// REF: might want to check https://github.com/rockorager/libvaxis-starter/blob/main/src/main.zig

// This can contain internal events as well as Vaxis events.
// Internal events can be posted into the same queue as vaxis events to allow
// for a single event loop with exhaustive switching. Booya
const Event = union(enum) {
    key_press: vaxis.Key,
    winsize: vaxis.Winsize,
    focus_in,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) {
            std.log.err("memory leak", .{});
        }
    }
    const alloc = gpa.allocator();

    var tty = try vaxis.Tty.init();
    defer tty.deinit();

    var vx = try vaxis.init(alloc, .{});
    // deinit takes an optional allocator. If your program is exiting, you can
    // choose to pass a null allocator to save some exit time.
    defer vx.deinit(alloc, tty.anyWriter());

    // The event loop requires an intrusive init. We create an instance with
    // stable pointers to Vaxis and our TTY, then init the instance. Doing so
    // installs a signal handler for SIGWINCH on posix TTYs
    //
    // This event loop is thread safe. It reads the tty in a separate thread
    var loop: vaxis.Loop(Event) = .{
        .tty = &tty,
        .vaxis = &vx,
    };
    try loop.init();

    // Start the read loop. This puts the terminal in raw mode and begins
    // reading user input
    try loop.start();
    defer loop.stop();

    // clear the screen and set it up
    try vx.enterAltScreen(tty.anyWriter());

    // Sends queries to terminal to detect certain features. This should always
    // be called after entering the alt screen, if you are using the alt screen
    try vx.queryTerminal(tty.anyWriter(), 1 * std.time.ns_per_s);

    var text_input = TextInput.init(alloc, &vx.unicode);
    defer text_input.deinit();

    // read a file
    var dir = try std.fs.cwd().openDir(".", .{
        .iterate = true,
    });
    var dirIterator = dir.iterate();
    defer dir.close();
    while (try dirIterator.next()) |entry| {
        try text_input.insertSliceAtCursor(entry.name);
        try text_input.insertSliceAtCursor("\n\rNew line");
    }

    while (true) {
        // nextEvent blocks until an event is in the queue
        const event = loop.nextEvent();

        // exhaustive switching ftw. Vaxis will send events if your Event enum
        // has the fields for those events (ie "key_press", "winsize")
        switch (event) {
            .winsize => |ws| try vx.resize(alloc, tty.anyWriter(), ws),

            // handle key presses
            .key_press => |key| {
                if (key.matches('c', .{ .ctrl = true })) {
                    break;
                } else if (key.matches('l', .{ .ctrl = true })) {
                    // TODO: maybe we dont need this
                    vx.queueRefresh();
                } else {
                    try text_input.update(.{ .key_press = key });
                }
            },

            else => {},
        }

        const win = vx.window();
        win.clear();

        const child = win.child(.{
            .x_off = 4,
            .y_off = 2,
        });
        text_input.draw(child);

        _ = try child.printSegment(.{
            .text = "Foo!!",
            .link = .{
                .uri = "zed.com",
            },
        }, .{
            .row_offset = child.height - child.y_off,
            .col_offset = child.width - "Foo!!".len - child.x_off,
        });

        // render the screen
        try vx.render(tty.anyWriter());
    }
}
