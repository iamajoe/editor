// TODO: this shouldnt exist but it is a way for me to understand
//       how to do it
pub fn u8ToConstU8(str: []u8) []const u8 {
    const newStr: []const u8 = str;
    return newStr;
}

pub fn charToConstU8(char: u8) []const u8 {
    const str: []const u8 = &[_]u8{char};
    return str;
}
