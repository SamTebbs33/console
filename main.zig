const std = @import("std");
const assert = std.debug.assert;
const sdl = @cImport({ @cInclude("SDL2/SDL.h"); });
const z80 = @cImport({ @cInclude("z80.h"); });

pub extern fn SDL_PollEvent(event: *sdl.SDL_Event) c_int;
const SDL_WINDOWPOS_UNDEFINED = @bitCast(c_int, sdl.SDL_WINDOWPOS_UNDEFINED_MASK);

const ConsoleError = error {
    SdlInit
};

const Pixel = u8;
const SpriteDef = [SPRITE_HEIGHT][SPRITE_WIDTH]Pixel;
const Colour = packed struct {
    red: u3,
    green: u3,
    blue: u2
};
const ColourPalette = [16]Colour;
const SpriteEntry = packed struct {
    x: u8,
    y: u8,
    sprite: u8,
    sprite_inc: u2,
    x_inc: u2,
    y_inc: u2,
    palette: u2,
    attribute: u8
};
const SpriteAttribute = packed struct {
    sprite_max_inc: u2,
    x_max_inc: u2,
    y_max_inc: u2,
    fourth_frame_too: bool,
    enabled: bool
};
const SpriteTable = [NUM_SPRITE_ENTRIES]SpriteEntry;
const TileEntry = packed struct {
    palette: u2,
    enabled: bool,
    unused: u5,
    sprite: u8
};
const TileTable = [NUM_TILES_Y][NUM_TILES_X]TileEntry;

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

const NUM_TILE_TABLES = 2;
const NUM_PALETTES = 4;
const NUM_ATTRIBUTES = 256;
const NUM_SPRITE_ENTRIES = 64;

// CPU mem and io map
const CPU_ROM_ADDR = 0;
const CPU_RAM_ADDR = CPU_ROM_SIZE;
const CPU_IO_VRAM_ADDR = 0;

// PPU mem and io map
const PPU_ROM_ADDR = 0;
const PPU_VRAM_ADDR = PPU_ROM_SIZE;
const PPU_SPROM_ADDR = PPU_VRAM_ADDR + VRAM_SIZE;

// VRAM offsets after VRAM address
const VRAM_ATTR_OFFSET = 0;
const VRAM_PALETTE_OFFSET = VRAM_ATTR_OFFSET + NUM_ATTRIBUTES * @sizeOf(SpriteAttribute);
const VRAM_TILE_TABLE_OFFSET = VRAM_PALETTE_OFFSET + NUM_PALETTES * @sizeOf(ColourPalette);
const VRAM_SPRITE_TABLE_OFFSET = VRAM_TILE_TABLE_OFFSET + NUM_TILE_TABLES * @sizeOf(TileTable);

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

comptime {
    assert(cpu_rom.len <= CPU_ROM_SIZE);
    assert(ppu_rom.len <= PPU_ROM_SIZE);

    assert(@sizeOf(Pixel) == 1);
    assert(@sizeOf(Colour) == 1);
    assert(@sizeOf(ColourPalette) == 16);
    assert(@sizeOf(SpriteTable) == 320);
    assert(@sizeOf(SpriteEntry) == 5);
    assert(@sizeOf(SpriteAttribute) == 1);
    assert(@sizeOf(TileTable) == 1800);
    assert(@sizeOf(TileEntry) == 2);
    assert(@sizeOf(SpriteDef) == 64);
}

fn memAddrToType(comptime t: type, addr: u16, is_cpu: bool) *t {
    return @ptrCast(*t, getMappedMem(is_cpu, addr));
}

fn ioAddrToType(comptime t: type, addr: u16, is_cpu: bool) *t {
    return @ptrCast(*t, getMappedIo(is_cpu, addr));
}

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
            PPU_ROM_SIZE ... PPU_ROM_SIZE + VRAM_SIZE - 1 => &vram[address - PPU_ROM_SIZE],
            PPU_ROM_SIZE + VRAM_SIZE ... PPU_ROM_SIZE + VRAM_SIZE + SPR_ROM_SIZE - 1 => &spr_rom[address - PPU_ROM_SIZE - SPR_ROM_SIZE],
            else => unreachable
        };
    }
}

fn getMappedIo(is_cpu: bool, address: u16) *u8 {
    if (is_cpu) {
        return switch (address) {
            0 ... VRAM_SIZE - 1 => &vram[address],
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

fn getSpriteTable(comptime is_cpu: bool, table: u16) *SpriteTable {
    const offset = VRAM_SPRITE_TABLE_OFFSET + @sizeOf(SpriteTable) * table;
    if (is_cpu) {
        return ioAddrToType(SpriteTable, CPU_IO_VRAM_ADDR + offset, true);
    } else {
        return memAddrToType(SpriteTable, PPU_VRAM_ADDR + offset, false);
    }
}

fn getTileTable(comptime is_cpu: bool, table: u16) *TileTable {
    const offset = VRAM_TILE_TABLE_OFFSET + @sizeOf(TileTable) * table;
    if (is_cpu) {
        return ioAddrToType(TileTable, CPU_IO_VRAM_ADDR + offset, true);
    } else {
        return memAddrToType(TileTable, PPU_VRAM_ADDR + offset, false);
    }
}

fn getSprite(comptime is_cpu: bool, sprite: u16) *SpriteDef {
    const offset = @sizeOf(SpriteDef) * sprite;
    if (is_cpu) {
        unreachable;
    } else {
        return memAddrToType(SpriteDef, PPU_SPROM_ADDR + offset, false);
    }
}

fn getPalette(comptime is_cpu: bool, palette: u16) *ColourPalette {
    const offset = VRAM_PALETTE_OFFSET + @sizeOf(ColourPalette) * palette;
    if (is_cpu) {
        return ioAddrToType(ColourPalette, CPU_VRAM_ADDR + offset, true);
    } else {
        return memAddrToType(ColourPalette, PPU_VRAM_ADDR + offset, false);
    }
}

fn getAttribute(comptime is_cpu: bool, attribute: u16) *SpriteAttribute {
    const offset: u16 = VRAM_ATTR_OFFSET + @sizeOf(SpriteAttribute) * attribute;
    if (is_cpu) {
        return ioAddrToType(SpriteAttribute, CPU_VRAM_ADDR + offset, true);
    } else {
        return memAddrToType(SpriteAttribute, PPU_VRAM_ADDR + offset, false);
    }
}

fn drawSprite2(renderer: *sdl.SDL_Renderer, sprite: *SpriteDef, palette: *ColourPalette, x: u32, y: u32) void {
    var sprite_x: u8 = 0;
    while (sprite_x < SPRITE_WIDTH) : (sprite_x += 1) {
        var sprite_y: u8 = 0;
        while (sprite_y < SPRITE_HEIGHT) : (sprite_y += 1) {
            const pixel = sprite[sprite_y][sprite_x];
            const colour = palette[pixel];
            const red = if (colour.red == 0b111) u8(255) else 0;
            const green = if (colour.green == 0b111) u8(255) else 0;
            const blue = if (colour.blue == 0b11) u8(255) else 0;
            var ignored = sdl.SDL_SetRenderDrawColor(renderer, red, green, blue, 255);
            ignored = sdl.SDL_RenderDrawPoint(renderer, @intCast(c_int, x + sprite_x), @intCast(c_int, y  + sprite_y));
        }
    }
}

fn draw(renderer: *sdl.SDL_Renderer, frames: u32) void {
    // Clear the screen first
    var ignored = sdl.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0);
    ignored = sdl.SDL_RenderClear(renderer);

    // Draw the tiles
    const tile_table = getTileTable(false, 0);
    var tile_x: u32 = 0;
    while (tile_x < NUM_TILES_X) : (tile_x += 1) {
        var tile_y: u32 = 0;
        while (tile_y < NUM_TILES_Y) : (tile_y += 1) {
            const tile_entry = tile_table[tile_y][tile_x];
            if (tile_entry.enabled) {
                const palette = tile_entry.palette;
                const sprite = tile_entry.sprite;
                drawSprite2(renderer, getSprite(false, sprite), getPalette(false, palette), tile_x * SPRITE_WIDTH, tile_y * SPRITE_HEIGHT);
            }
        }
    }

    // Draw the sprites
    var i: u32 = 0;
    const sprite_table = getSpriteTable(false, 0);
    while (i < NUM_SPRITE_ENTRIES) : (i += 1) {
        var entry = &sprite_table[i];
        const attr = getAttribute(false, entry.attribute);
        if (attr.enabled) {
            drawSprite2(renderer, getSprite(false, entry.sprite + entry.sprite_inc), getPalette(false, entry.palette), entry.x + entry.x_inc, entry.y + entry.y_inc);
            if ((attr.fourth_frame_too and frames % 4 == 0) or frames % 8 == 0) {
                entry.x_inc = if (std.math.add(u2, entry.x_inc, 1)) |res| res else |err| 0;
                entry.y_inc = if (std.math.add(u2, entry.y_inc, 1)) |res| res else |err| 0;
                entry.sprite_inc = if (std.math.add(u2, entry.sprite_inc, 1)) |res| res else |err| 0;
                if (entry.x_inc > attr.x_max_inc)
                    entry.x_inc = 0;
                if (entry.y_inc > attr.y_max_inc)
                    entry.y_inc = 0;
                if (entry.sprite_inc > attr.sprite_max_inc)
                    entry.sprite_inc = 0;
            }
        }
    }
    sdl.SDL_RenderPresent(renderer);
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
        frames += 1;
        if (time - last_update >= 1000) {
            std.debug.warn("FPS: {}\n", frames);
            frames = 0;
            last_update = time;
        }
        const nanos_since_last_frame = (time - last_frame) * 1000000;
        last_frame = time;
        if (nanos_since_last_frame < NANOS_PER_FRAME) {
            std.time.sleep((NANOS_PER_FRAME - nanos_since_last_frame) * 2);
        }
    }
}
