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
// CPU firmware ROM
const CPU_ROM_SIZE = 32 * 1024;
var cpu_rom = @embedFile("cpu.bin");
// PPU firmware ROM
const PPU_ROM_SIZE = 8 * 1024;
var ppu_rom = @embedFile("ppu.bin");

const TILE_TABLE_ADDR = 0;
const TILE_TABLE_SIZE = NUM_TILES_X * NUM_TILES_Y * TILE_ENTRY_SIZE;
const NUM_TILE_TABLES = 2;
const TILE_ENTRY_SIZE = 2;
const SPRITE_ADDR = 0;
const SPRITE_SIZE = SPRITE_WIDTH * SPRITE_HEIGHT * PIXEL_SIZE;
const PIXEL_SIZE = 1;
const PALETTE_ADDR = TILE_TABLE_ADDR + TILE_TABLE_SIZE * NUM_TILE_TABLES;
const PALETTE_SIZE = 16 * COLOUR_SIZE;
const NUM_PALETTES = 4;
const ATTRIBUTE_ADDR = PALETTE_ADDR + NUM_PALETTES * PALETTE_SIZE;
const ATTRIBUTE_SIZE = 1;
const NUM_ATTRIBUTES = 256;
const COLOUR_SIZE = 1;
const SPRITE_TABLE_ADDR = ATTRIBUTE_ADDR + NUM_ATTRIBUTES * ATTRIBUTE_SIZE;
const NUM_SPRITE_ENTRIES = 64;
const SPRITE_ENTRY_SIZE = 5;
const SPRITE_TABLE_SIZE = NUM_SPRITE_ENTRIES * SPRITE_ENTRY_SIZE;

comptime {
    std.debug.assert(cpu_rom.len <= CPU_ROM_SIZE);
    std.debug.assert(ppu_rom.len <= PPU_ROM_SIZE);
}

// Processors
var cpu = initZ80(memRead, memWrite, ioRead, ioWrite);

const RES_X = 240;
const RES_Y = 240;
const SPRITE_WIDTH = 8;
const SPRITE_HEIGHT = 8;
const NUM_TILES_X = RES_X / SPRITE_WIDTH;
const NUM_TILES_Y = RES_Y / SPRITE_HEIGHT;
const FPS = 50;
const NANOS_PER_CPU_CYCLE = 100;
const NANOS_PER_FRAME = 1000000000 / FPS;
const MILLIS_PER_FRAME = NANOS_PER_FRAME / 1000000;
const CPU_CYCLES_PER_FRAME = NANOS_PER_FRAME / NANOS_PER_CPU_CYCLE;
var nanos: u64 = 0;

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

fn drawSprite(renderer: *sdl.SDL_Renderer, sprite_addr: u16, palette_addr: u16, x: u32, y: u32) void {
    var sprite_x: u8 = 0;
    while (sprite_x < SPRITE_WIDTH) : (sprite_x += 1) {
        var sprite_y: u8 = 0;
        while (sprite_y < SPRITE_HEIGHT) : (sprite_y += 1) {
            const pixel_num = sprite_x * SPRITE_HEIGHT + sprite_y;
            const pixel_addr = sprite_addr + pixel_num / 2;
            const pixel: u8 = spr_rom[pixel_addr];
            const colour: u8 = vram[palette_addr + pixel];
            const red = if ((colour & 0b111) == 0b111) u8(255) else 0;
            const green = if ((colour & 0b111000) == 0b111000) u8(255) else 0;
            const blue = if ((colour & 0b11000000) == 0b11000000) u8(255) else 0;
            var ignored = sdl.SDL_SetRenderDrawColor(renderer, red, green, blue, 255);
            ignored = sdl.SDL_RenderDrawPoint(renderer, @intCast(c_int, x + sprite_x), @intCast(c_int, y  + sprite_y));
        }
    }
}

fn draw(renderer: *sdl.SDL_Renderer, frames: u32) void {
    // Clear the screen first
    var ignored = sdl.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0);
    ignored = sdl.SDL_RenderClear(renderer);
    // Draw the background tiles
    var tile_x: u32 = 0;
    const tile_table = 0;
    const tile_table_addr = TILE_TABLE_ADDR + tile_table * TILE_TABLE_SIZE;
    while (tile_x < NUM_TILES_X) : (tile_x += 1) {
        var tile_y: u32 = 0;
        while (tile_y < NUM_TILES_Y) : (tile_y += 1) {
            const tile_entry_num: u32 = tile_x * NUM_TILES_Y + tile_y;
            const tile_entry_addr: u32 = tile_table_addr + (tile_entry_num * TILE_ENTRY_SIZE);
            const tile_entry_addr_high: u32 = tile_entry_addr + 1;
            const tile_entry: u16 = vram[tile_entry_addr] | u16(vram[tile_entry_addr_high]) << 8;
            const enabled = ((tile_entry >> 2) & 0b1) == 1;
            if (enabled) {
                const palette = tile_entry & 0b11;
                const sprite_num = vram[tile_entry_addr + 1];
                const sprite_addr = SPRITE_ADDR + sprite_num * SPRITE_SIZE;
                const palette_addr = PALETTE_ADDR + palette * PALETTE_SIZE;
                drawSprite(renderer, sprite_addr, palette_addr, tile_x * SPRITE_WIDTH, tile_y * SPRITE_HEIGHT);
            }
        }
    }

    // Draw the sprites
    var i: u32 = 0;
    const table_addr = SPRITE_TABLE_ADDR + 0 * SPRITE_TABLE_SIZE;
    while (i < NUM_SPRITE_ENTRIES) : (i += 1) {
        const entry_addr = table_addr + i * SPRITE_ENTRY_SIZE;
        const x: u8 = vram[entry_addr];
        const y: u8 = vram[entry_addr + 1];
        const sprite_num: u8 = vram[entry_addr + 2];
        const sprite_num_inc: u8 = vram[entry_addr + 3] & 0b11;
        const x_inc: u8 = (vram[entry_addr + 3] & 0b1100) >> 2;
        const y_inc: u8 = (vram[entry_addr + 3] & 0b110000) >> 4;
        const palette = (vram[entry_addr + 3] & 0b11000000) >> 6;
        const attr = vram[entry_addr + 4];
        const attr_addr = u32(ATTRIBUTE_ADDR) + attr * ATTRIBUTE_SIZE;
        const attr_enabled: bool = (vram[attr_addr] & 0b10000000) != 0;
        if (attr_enabled) {
            const palette_addr = u16(PALETTE_ADDR) + palette * PALETTE_SIZE;
            drawSprite(renderer, SPRITE_ADDR + (sprite_num + sprite_num_inc) * SPRITE_SIZE, palette_addr, x + x_inc, y + y_inc);
            const attr_fourth_too = vram[attr_addr] & 0b01000000 != 0;
            if ((attr_fourth_too and frames % 4 == 0) or frames % 8 == 0) {
                var new_x_inc: u2 = @truncate(u2, ((vram[entry_addr + 3] & 0b1100) >> 2) + 1);
                const max_x_inc: u2 = @truncate(u2, (vram[attr_addr] & 0b1100) >> 2);
                if (new_x_inc > max_x_inc) {
                    new_x_inc = 0;
                }
                vram[entry_addr + 3] = (vram[entry_addr + 3] & 0b11110011) | (@intCast(u8, new_x_inc) << 2);
            }
        }
    }
    sdl.SDL_RenderPresent(renderer);
}

fn initGraphics() void {
    // Set sprites
    var i: u32 = 0;
    const sprite_num = 0;
    while (i < SPRITE_SIZE) : (i += 1) {
        spr_rom[SPRITE_ADDR + sprite_num * SPRITE_SIZE + i] = 0;
    }
    // Set palettes
    vram[PALETTE_ADDR] = 0b00011111;
    vram[PALETTE_ADDR + PALETTE_SIZE] = 0b11111111;
    // Set tile table
    vram[TILE_TABLE_ADDR] = 0b00 | 0b1 << 2;
    vram[TILE_TABLE_ADDR + 1] = 0b00000000;
    vram[TILE_TABLE_ADDR + NUM_TILES_Y * TILE_ENTRY_SIZE] = 0b01 | 0b1 << 2;
    vram[TILE_TABLE_ADDR + NUM_TILES_Y * TILE_ENTRY_SIZE + 1] = 0b00000000;

    // Set other sprites
    while (i < SPRITE_SIZE) : (i += 1) {
        spr_rom[SPRITE_ADDR + 1 * SPRITE_SIZE + i] = 1;
    }
    vram[SPRITE_TABLE_ADDR] = 9;
    vram[SPRITE_TABLE_ADDR + 1] = 9;
    vram[SPRITE_TABLE_ADDR + 2] = 0;
    vram[SPRITE_TABLE_ADDR + 3] = 0;
    vram[SPRITE_TABLE_ADDR + 4] = 0;

    // Set atributes
    vram[ATTRIBUTE_ADDR] = 0b11111100;
}

pub fn main() !void {
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

    initGraphics();

    var last_update = std.time.milliTimestamp();
    var last_frame: u64 = std.time.milliTimestamp();
    var frames: u32 = 0;
    while (true) {
        var event: sdl.SDL_Event = undefined;
        if (SDL_PollEvent(&event) != 0) {
            if (event.@"type" == sdl.SDL_QUIT)
                return;
        }

        const ignored2 = z80.Z80ExecuteTStates(&cpu, CPU_CYCLES_PER_FRAME);
        draw(renderer, frames);
        z80.Z80NMI(&cpu);

        var time = std.time.milliTimestamp();
        const nanos_since_last_frame = (time - last_frame) * 1000000;
        last_frame = time;
        if (nanos_since_last_frame < NANOS_PER_FRAME) {
            std.time.sleep(NANOS_PER_FRAME - nanos_since_last_frame);
        }
        frames += 1;
        time = std.time.milliTimestamp();
        if (time - last_update >= 1000) {
            frames = 0;
            last_update = time;
        }
    }
}
