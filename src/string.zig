// TODO: this shouldnt exist but it is a way for me to understand
//       how to do it
pub fn u8ToConstU8(str: []u8) []const u8 {
    const newStr: []const u8 = str;
    return newStr;
}
