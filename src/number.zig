const std = @import("std");

const digits = "0123456789";

pub fn countDigits(v: usize) u8 {
    return switch (v) {
        0...9 => 1,
        10...99 => 2,
        100...999 => 3,
        1000...9999 => 4,
        10000...99999 => 5,
        100000...999999 => 6,
        1000000...9999999 => 7,
        10000000...99999999 => 8,
        else => 0,
    };
}

test "countDigits" {
    const cases: [5]std.meta.Tuple(&.{ usize, usize }) = .{
        .{ 12345, 5 },
        .{ 1, 1 },
        .{ 10, 2 },
        .{ 0, 1 },
        .{ 13412345, 8 },
    };

    for (cases) |item| {
        const res = countDigits(item[0]);
        try std.testing.expectEqual(item[1], res);
    }
}

pub fn extractDigitFromRight(number: usize, pos: usize) usize {
    return (number / std.math.pow(usize, 10, pos)) % 10;
}

pub fn extractDigitFromLeft(number: usize, pos: usize) usize {
    const total_digits = countDigits(number);
    const right_pos = total_digits -| pos -| 1;
    return extractDigitFromRight(number, right_pos);
}

test "extractDigitFromLeft" {
    const cases: [5]std.meta.Tuple(&.{ usize, usize, usize }) = .{
        .{ 12345, 1, 2 },
        .{ 12345, 2, 3 },
        .{ 12, 0, 1 },
        .{ 434, 0, 4 },
        .{ 40989, 4, 9 },
    };

    for (cases) |item| {
        const res = extractDigitFromLeft(item[0], item[1]);
        try std.testing.expectEqual(item[2], res);
    }
}

pub fn digitToStr(v: usize) []const u8 {
    // protected against non digits
    if (v > 9) {
        return "0";
    }

    return digits[v .. v + 1];
}

test "digitToStr" {
    const cases: [11]std.meta.Tuple(&.{ usize, []const u8 }) = .{
        .{ 0, "0" },
        .{ 1, "1" },
        .{ 2, "2" },
        .{ 3, "3" },
        .{ 4, "4" },
        .{ 5, "5" },
        .{ 6, "6" },
        .{ 7, "7" },
        .{ 8, "8" },
        .{ 9, "9" },
        .{ 123, "0" },
    };

    for (cases) |item| {
        const res = digitToStr(item[0]);
        const ok = std.mem.eql(u8, item[1], res);
        try std.testing.expect(ok);
    }
}
