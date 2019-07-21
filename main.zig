const std = @import("std");
const sdl = @cImport({ @cInclude("SDL2/SDL.h"); });
const Thread = std.Thread;
const ppu = @import("ppu.zig");
const cpu = @import("cpu.zig");
const vpu = @import("vpu.zig");

pub extern fn SDL_PollEvent(event: *sdl.SDL_Event) c_int;

pub fn main() !void {
    try vpu.init();
    cpu.init();
    var event: sdl.SDL_Event = undefined;
    var last_update = std.time.milliTimestamp();
    while (true) {
        if (SDL_PollEvent(&event) != 0) {
            if (event.@"type" == sdl.SDL_QUIT)
                return;
        }
        ppu.clock();
        cpu.clock();
        if (std.time.milliTimestamp() - last_update >= ppu.FRAME_TIME) {
            vpu.draw();
            last_update = std.time.milliTimestamp();
        }
        std.time.sleep(1000);
    }
}
