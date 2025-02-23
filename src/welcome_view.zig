const std = @import("std");
const vaxis = @import("vaxis");

const initial_offset_y = 4;
const sub_pad = 1;

// REF: http://patorjk.com/software/taag/#p=testall&f=Acrobatic&t=ABE

// Font: BlurVision ASCII
// const ascii_width = 42;
// const ascii_height = 7;
// const ascii: [ascii_height][]const u8 = .{
//     " ░▒▓██████▓▒░░▒▓███████▓▒░░▒▓████████▓▒░  ",
//     " ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░        ",
//     " ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░        ",
//     " ░▒▓████████▓▒░▒▓███████▓▒░░▒▓██████▓▒░   ",
//     " ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░        ",
//     " ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░        ",
//     " ░▒▓█▓▒░░▒▓█▓▒░▒▓███████▓▒░░▒▓████████▓▒░ ",
// };

// Font: Peaks Slant (modified)
// const ascii_width = 47;
// const ascii_height = 6;
// const ascii: [ascii_height][]const u8 = .{
//     "     _____/a/a______/a/a/a/a/a____/a/a/a/a/a/a_",
//     "    ___/a/a/a/a____/a/a____/a/a__/a___________ ",
//     "   _/a/a____/a/a__/a/a/a/a/a____/a/a/a/a/a___  ",
//     "  _/a/a/a/a/a/a__/a/a____/a/a__/a/a_________   ",
//     " _/a/a____/a/a__/a/a/a/a/a____/a/a/a/a/a/a_    ",
//     "__________________________________________     ",
// };

// Font: Peaks Slant
// const ascii_width = 47;
// const ascii_height = 6;
// const ascii: [ascii_height][]const u8 = .{
//     "     _____/\\/\\______/\\/\\/\\/\\/\\____/\\/\\/\\/\\/\\/\\_",
//     "    ___/\\/\\/\\/\\____/\\/\\____/\\/\\__/\\___________ ",
//     "   _/\\/\\____/\\/\\__/\\/\\/\\/\\/\\____/\\/\\/\\/\\/\\___  ",
//     "  _/\\/\\/\\/\\/\\/\\__/\\/\\____/\\/\\__/\\/\\_________   ",
//     " _/\\/\\____/\\/\\__/\\/\\/\\/\\/\\____/\\/\\/\\/\\/\\/\\_    ",
//     "__________________________________________     ",
// };

// Font: ANSI Regular
const ascii_width = 24;
const ascii_height = 6;
const ascii: [ascii_height][]const u8 = .{
    " █████╗ ██████╗ ███████╗",
    "██╔══██╗██╔══██╗██╔════╝",
    "███████║██████╔╝█████╗  ",
    "██╔══██║██╔══██╗██╔══╝  ",
    "██║  ██║██████╔╝███████╗",
    "╚═╝  ╚═╝╚═════╝ ╚══════╝",
};

// Font: Binary
const ascii_sub_width = 26;
const ascii_sub_height = 1;
const ascii_sub: [ascii_sub_height][]const u8 = .{
    "01000001 01000010 01000101",
};

pub fn render(win: vaxis.Window) void {
    // make sure we have a window
    if (win.height <= 0 or win.width <= 0) {
        return;
    }

    const offset_y = win.height / 2 - ascii_height / 2 - initial_offset_y;

    // render the title
    var offset_x = win.width / 2 - ascii_width / 2;
    var curr_row = offset_y;
    for (ascii) |line| {
        win.writeCell(offset_x, curr_row, .{
            .char = .{
                .grapheme = line,
                .width = ascii_width,
            },
            .wrapped = false,
        });
        curr_row += 1;
    }

    // render the sub title
    offset_x = win.width / 2 - ascii_sub_width / 2;
    curr_row += sub_pad;
    for (ascii_sub) |line| {
        win.writeCell(offset_x, curr_row, .{
            .char = .{
                .grapheme = line,
                .width = ascii_sub_width,
            },
            .wrapped = false,
        });

        curr_row += 1;
    }
}
