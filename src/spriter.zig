const types = @import("types.zig");
const std = @import("std");
const sprite_chars = @embedFile("../sprites.spr");
const File = std.fs.File;

const SpriteErr = error {
    InvalidChar
};

pub fn main() !void {
    const file = try File.openWrite("sprites.bin");
    defer file.close();

    var skip = false;
    for (sprite_chars) |char| {
         if (char == '#')
             skip = !skip;
        if (!skip) {
            const byte = charToByte(char) catch |e| {
                continue;
            };
            const arr: [1]u8 = [_]u8{byte};
            try file.write(arr);
        }
    } 
}

fn charToByte(byte: u8) SpriteErr!u8 {
    if (byte >= '0' and byte <= '9') {
        return byte - '0';
    } else if (byte >= 'A' and byte <= 'F') {
        return byte - 'A' + 10;
    } else if (byte >= 'a' and byte <= 'f') {
        return byte - 'a' + 10;
    } else {
        return SpriteErr.InvalidChar;
    }
}
