const std = @import("std");
const sdl = @cImport({ @cInclude("SDL2/SDL.h"); });
const z80 = @cImport({ @cInclude("z80.h"); });

pub extern fn SDL_PollEvent(event: *sdl.SDL_Event) c_int;
const SDL_WINDOWPOS_UNDEFINED = @bitCast(c_int, sdl.SDL_WINDOWPOS_UNDEFINED_MASK);

const ConsoleError = error {
    SdlInit
};

// Memory
// General purpose RAM
const GPR_RAM_SIZE = 64 * 1024 - CPU_ROM_SIZE;
var gpr_ram = [_]u8{0} ** GPR_RAM_SIZE;
// Sprite ROM
const SPR_ROM_SIZE = 8 * 1024;
var spr_rom = [_]u8{0} ** SPR_ROM_SIZE;
// VRAM
const VRAM_SIZE = 8 * 1024;
var vram = [_]u8{0} ** VRAM_SIZE;
// Duplicate of VRAM
var vram2 = [_]u8{0} ** VRAM_SIZE;
// CPU firmware ROM
const CPU_ROM_SIZE = 32 * 1024;
var cpu_rom = @embedFile("cpu.bin");
// PPU firmware ROM
const PPU_ROM_SIZE = 8 * 1024;
var ppu_rom = @embedFile("ppu.bin");

comptime {
    std.debug.assert(cpu_rom.len <= CPU_ROM_SIZE);
    std.debug.assert(ppu_rom.len <= PPU_ROM_SIZE);
}

// Processors
var cpu = initZ80(memRead, memWrite, ioRead, ioWrite);
var ppu = initZ80(memRead, memWrite, ioRead, ioWrite);

// The nano seconds per CPU clock
const CPU_NANOS = 100;
// The nano seconds per PPU clock
const PPU_NANOS = 100;
// The nano seconds per tick
const TICK_NANOS = 100;
// The nano seconds taken to draw a scanline
const SCANLINE_DRAW_NANOS = 75000;
// The nano seconds per hblank period
const HBLANK_NANOS = 25000;
// The nano seconds for the drawing each scanline and each hblank period
const DRAW_NANOS = 25000000;
// The nano seconds taken by vblank
const VBLANK_NANOS = 15000000;
const FRAME_NANOS = DRAW_NANOS + VBLANK_NANOS;
var cpu_nanos: u32 = 0;
var ppu_nanos: u32 = 0;
var draw_nanos: u32 = 0;
var scanline: u32 = 0;
const RES_X = 250;
const RES_Y = 240;
const FINAL_SCANLINE = RES_Y;
const PIXELS_IO_ADDR = 0;

fn initZ80(mem_read: z80.Z80DataIn, mem_write: z80.Z80DataOut, io_read: z80.Z80DataIn, io_write: z80.Z80DataOut) z80.Z80Context {
    var ctx: z80.Z80Context = undefined;
    ctx.memRead = mem_read;
    ctx.memWrite = mem_write;
    ctx.ioRead = io_read;
    ctx.ioWrite = io_write;
    return ctx;
}

fn getMappedMem(is_cpu: bool, address: u16) *u8 {
    if (is_cpu) {
        return switch (address) {
            0 ... CPU_ROM_SIZE - 1 => &cpu_rom[address],
            CPU_ROM_SIZE ... CPU_ROM_SIZE + GPR_RAM_SIZE - 1 => &gpr_ram[address - CPU_ROM_SIZE],
            else => unreachable
        };
    } else {
        //std.debug.warn("PPU addr: {}, {}\n", address, ppu.nmi_req);
        return switch (address) {
            0 ... PPU_ROM_SIZE - 1 => &ppu_rom[address],
            PPU_ROM_SIZE ... PPU_ROM_SIZE + SPR_ROM_SIZE - 1 => &spr_rom[address - PPU_ROM_SIZE],
            PPU_ROM_SIZE + SPR_ROM_SIZE ... PPU_ROM_SIZE + SPR_ROM_SIZE + VRAM_SIZE - 1 => &vram[address - PPU_ROM_SIZE - SPR_ROM_SIZE],
            else => unreachable
        };
    }
}

fn getMappedIo(is_cpu: bool, address: u16) *u8 {
    if (is_cpu) {
        return switch (address) {
            0 ... SPR_ROM_SIZE - 1 => &spr_rom[address],
            SPR_ROM_SIZE ... SPR_ROM_SIZE + VRAM_SIZE - 1 => &vram[address - SPR_ROM_SIZE],
            else => unreachable
        };
    } else {
        unreachable;
    }
}

export fn memRead(param: c_int, address: c_ushort) u8 {
    return getMappedMem(param == 1, address).*;
}

export fn memWrite(param: c_int, address: c_ushort, byte: u8) void {
    getMappedMem(param == 1, address).* = byte;
}

export fn ioRead(param: c_int, address: c_ushort) u8 {
    return getMappedIo(param == 1, address).*;
}

export fn ioWrite(param: c_int, address: c_ushort, byte: u8) void {
    getMappedIo(param == 1, address).* = byte;
}

fn tick_processor(processor: *z80.Z80Context, curr_nanos: *u32, max_nanos: u32) void {
        if (curr_nanos.* >= max_nanos) {
            z80.Z80Execute(processor);
            curr_nanos.* = 0;
        } else {
            curr_nanos.* += TICK_NANOS;
        }
}

fn draw(renderer: *sdl.SDL_Renderer) void {
    // Draw each pixel on the current scanline
    var x: c_int = 0;
    while (x < RES_X) : (x += 1) {
        var ignored = sdl.SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);
        ignored = sdl.SDL_RenderDrawPoint(renderer, x, @intCast(c_int, scanline));
    }
    sdl.SDL_RenderPresent(renderer);
}

pub fn main() !void {
    std.debug.warn("ROM len: {}\n", ppu_rom.len);
    for (ppu_rom) |rom_byte, i| {
        std.debug.warn("Byte at {} is {}\n", i, rom_byte);
    }
    std.debug.warn("Byte at 0x66 {}\n", ppu_rom[0x66]);
    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO) != 0) {
        return ConsoleError.SdlInit;
    }
    if (!(sdl.SDL_SetHintWithPriority(sdl.SDL_HINT_NO_SIGNAL_HANDLERS, c"1", sdl.SDL_HintPriority.SDL_HINT_OVERRIDE) != sdl.SDL_bool.SDL_FALSE)) {
        return ConsoleError.SdlInit;
    }
    const screen = sdl.SDL_CreateWindow(c"Console", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, RES_X, RES_Y, sdl.SDL_WINDOW_RESIZABLE);
    const renderer = sdl.SDL_CreateRenderer(screen, -1, 0) orelse return ConsoleError.SdlInit;

    var ignored = sdl.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0);
    ignored = sdl.SDL_RenderClear(renderer);
    sdl.SDL_RenderPresent(renderer);

    cpu.memParam = 1;
    cpu.ioParam = 1;
    z80.Z80RESET(&cpu);
    ppu.memParam = 0;
    ppu.ioParam = 0;
    z80.Z80RESET(&ppu);

    while (true) {
        tick_processor(&cpu, &cpu_nanos, CPU_NANOS);
        tick_processor(&ppu, &ppu_nanos, PPU_NANOS);
        if (draw_nanos == (SCANLINE_DRAW_NANOS * (scanline + 1)) + (HBLANK_NANOS * scanline)) {
            // If we have reached the current scanline's hblank
            draw(renderer);
            scanline += 1;
            //std.debug.warn("Going NMI on ppu {}\n", ppu.PC);
            z80.Z80NMI(&ppu);
            draw_nanos += TICK_NANOS;
        } else if (draw_nanos == (SCANLINE_DRAW_NANOS * (scanline + 1)) + (HBLANK_NANOS * (scanline + 1))) {
            // We have reached the end of current scanline's hblank
            if (scanline == FINAL_SCANLINE) {
                // We've reached VBLANK
                scanline = 0;
                //std.debug.warn("Going NMI on ppu {}\n", ppu.PC);
                z80.Z80NMI(&ppu);
            }
            draw_nanos += TICK_NANOS;
        } else if (draw_nanos == FRAME_NANOS) {
            // We've reached the end of the entire frame
            scanline = 0;
            draw_nanos = 0;
        } else {
            draw_nanos += TICK_NANOS;
        }
        std.time.sleep(TICK_NANOS);
    }
}
