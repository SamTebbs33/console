const std = @import("std");
const sdl = @cImport({ @cInclude("SDL2/SDL.h"); });
const z80 = @cImport({ @cInclude("z80.h"); });

pub extern fn SDL_PollEvent(event: *sdl.SDL_Event) c_int;

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

// Processor frequencies
const CPU_NANOS = 100;
const PPU_NANOS = 100;
const TICK_NANOS = 100;
const DRAW_NANOS = 25000000;
const VBLANK_NANOS = DRAW_NANOS + 15000000;
// How many times a second we should check to see if we should cycle the CPU/PPU
var cpu_nanos: u32 = 0;
var ppu_nanos: u32 = 0;
var draw_nanos: u32 = 0;

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
        std.debug.warn("CPU addr: {}\n", address);
        return switch (address) {
            0 ... CPU_ROM_SIZE - 1 => &cpu_rom[address],
            CPU_ROM_SIZE ... CPU_ROM_SIZE + GPR_RAM_SIZE - 1 => &gpr_ram[address - CPU_ROM_SIZE],
            else => unreachable
        };
    } else {
        std.debug.warn("PPU addr: {}\n", address);
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

pub fn main() void {
    cpu.memParam = 1;
    cpu.ioParam = 1;
    z80.Z80RESET(&cpu);
    ppu.memParam = 0;
    ppu.ioParam = 0;
    z80.Z80RESET(&ppu);

    while (true) {
        tick_processor(&cpu, &cpu_nanos, CPU_NANOS);
        tick_processor(&ppu, &ppu_nanos, PPU_NANOS);
        if (draw_nanos == DRAW_NANOS) {
            // draw    
            z80.Z80NMI(&ppu);
        } else if (draw_nanos >= VBLANK_NANOS) {
            draw_nanos = 0;
        } else {
            draw_nanos += TICK_NANOS;
        }
        std.time.sleep(TICK_NANOS);
    }
}
