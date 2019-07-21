pub fn Ram(comptime size: u16) type {
    return struct {
        mem: [size]u8
    };
}
