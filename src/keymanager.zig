const vaxis = @import("vaxis");
const main = @import("./main.zig");

pub fn handleKey(app: *main.App, key: vaxis.Key) !bool {
    if (key.matches('c', .{ .ctrl = true })) {
        return true;
    }

    if (key.matches('o', .{ .ctrl = true })) {
        try main.openFile(app);
        return false;
    }

    // if we have an editor view, it means we have a file active
    // if (app.editor_view) |editor_view| {
    //     _ = editor_view;
    //
    //     // TODO: what about modes?!
    //     if (key.matches('j', .{})) {
    //         // editor_view.moveCursorY(1);
    //     } else if (key.matches('k', .{})) {
    //         // editor_view.moveCursorY(-1);
    //     } else if (key.matches('h', .{})) {
    //         // editor_view.moveCursorX(-1);
    //     } else if (key.matches('l', .{})) {
    //         // editor_view.moveCursorY(1);
    //     }
    // }

    return false;
}
