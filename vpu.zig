const sdl = @cImport({ @cInclude("SDL2/SDL.h"); });
const std = @import("std");
const ppu = @import("ppu.zig");

const SDL_WINDOWPOS_UNDEFINED = @bitCast(c_int, sdl.SDL_WINDOWPOS_UNDEFINED_MASK);

const ConsoleError = error {
    SdlInit
};
var renderer: *sdl.SDL_Renderer = undefined;

pub fn init() !void {
    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO) != 0) {
        return ConsoleError.SdlInit;
    }
    if (!(sdl.SDL_SetHintWithPriority(sdl.SDL_HINT_NO_SIGNAL_HANDLERS, c"1", sdl.SDL_HintPriority.SDL_HINT_OVERRIDE) != sdl.SDL_bool.SDL_FALSE)) {
        return ConsoleError.SdlInit;
    }
    const screen = sdl.SDL_CreateWindow(c"Console", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, ppu.RES_X, ppu.RES_Y, sdl.SDL_WINDOW_RESIZABLE);
    renderer = sdl.SDL_CreateRenderer(screen, -1, 0) orelse return ConsoleError.SdlInit;

    var ignored = sdl.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0);
    ignored = sdl.SDL_RenderClear(renderer);
    sdl.SDL_RenderPresent(renderer);
}

pub fn draw() void {
    for (ppu.pixels) |pixel_column, x| {
        for (pixel_column) |pixel, y| {
            var ignored = sdl.SDL_SetRenderDrawColor(renderer, u8(pixel.red), u8(pixel.green), u8(pixel.blue), 255);
            ignored = sdl.SDL_RenderDrawPoint(renderer, @intCast(c_int, x), @intCast(c_int, y));
        }
    }
    sdl.SDL_RenderPresent(renderer);
}
