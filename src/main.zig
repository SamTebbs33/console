const std = @import("std");
const os = std.os;
const assert = std.debug.assert;
const sdl = @cImport({ @cInclude("SDL2/SDL.h"); });
const z80 = @cImport({ @cInclude("z80.h"); });
const types = @import("types.zig");

pub extern fn SDL_PollEvent(event: *sdl.SDL_Event) c_int;
const SDL_WINDOWPOS_UNDEFINED = @bitCast(c_int, sdl.SDL_WINDOWPOS_UNDEFINED_MASK);

const ConsoleError = error {
    SdlInit
};

pub const Button = enum {
    up,
    down,
    left,
    right,
    a,
    b,
    c,
    start
};
var buttons = [_]bool{false} ** @memberCount(Button);

// Memory
// General purpose RAM
const CPU_RAM_SIZE = 64 * 1024 - CPU_ROM_SIZE;
var cpu_ram = [_]u8{0} ** CPU_RAM_SIZE;
// Sprite ROM
const SPR_ROM_SIZE = 8 * 1024;
var spr_rom = @embedFile("../sprites.bin");
// VRAM
const VRAM_SIZE = 8 * 1024;
var vram = [_]u8{0} ** VRAM_SIZE;
// CPU firmware ROM
const CPU_ROM_SIZE = 32 * 1024;
var cpu_rom = @embedFile("../zig-cache/cpu.bin");
// PPU firmware ROM
const PPU_ROM_SIZE = 8 * 1024;
var ppu_rom = @embedFile("../zig-cache/ppu.bin");
// Bytes used by controller
const CONTROLLER_SIZE = 1;
var controller_byte: u8 = 0;

// CPU mem and io map
const CPU_ROM_ADDR = 0;
const CPU_RAM_ADDR = CPU_ROM_SIZE;
const CPU_IO_VRAM_ADDR = 0;
const CPU_IO_CONTROLLER_ADDR = CPU_IO_VRAM_ADDR + VRAM_SIZE;

// PPU mem and io map
const PPU_ROM_ADDR = 0;
const PPU_VRAM_ADDR = PPU_ROM_SIZE;
const PPU_SPROM_ADDR = PPU_VRAM_ADDR + VRAM_SIZE;

// VRAM offsets after VRAM address
const VRAM_ATTR_OFFSET = 0;
const VRAM_PALETTE_OFFSET = VRAM_ATTR_OFFSET + types.NUM_ATTRIBUTES * @sizeOf(types.SpriteAttribute);
const VRAM_TILE_TABLE_OFFSET = VRAM_PALETTE_OFFSET + types.NUM_PALETTES * @sizeOf(types.ColourPalette);
const VRAM_SPRITE_TABLE_OFFSET = VRAM_TILE_TABLE_OFFSET + types.NUM_TILE_TABLES * @sizeOf(types.TileTable);

// Processors
var cpu = initZ80(memRead, memWrite, ioRead, ioWrite);

const FPS = 50;
const NANOS_PER_CPU_CYCLE = 100;
const NANOS_PER_FRAME = 1000000000 / FPS;
const MILLIS_PER_FRAME = NANOS_PER_FRAME / 1000000;
const CPU_CYCLES_PER_FRAME = NANOS_PER_FRAME / NANOS_PER_CPU_CYCLE;
var nanos: u64 = 0;

comptime {
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
            CPU_ROM_SIZE ... CPU_ROM_SIZE + CPU_RAM_SIZE - 1 => &cpu_ram[address - CPU_ROM_SIZE],
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
            VRAM_SIZE ... VRAM_SIZE + CONTROLLER_SIZE => &controller_byte,
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

fn getSpriteTable(comptime is_cpu: bool, table: u16) *types.SpriteTable {
    const offset = VRAM_SPRITE_TABLE_OFFSET + @sizeOf(types.SpriteTable) * table;
    if (is_cpu) {
        return ioAddrToType(types.SpriteTable, CPU_IO_VRAM_ADDR + offset, true);
    } else {
        return memAddrToType(types.SpriteTable, PPU_VRAM_ADDR + offset, false);
    }
}

fn getTileTable(comptime is_cpu: bool, table: u16) *types.TileTable {
    const offset = VRAM_TILE_TABLE_OFFSET + @sizeOf(types.TileTable) * table;
    if (is_cpu) {
        return ioAddrToType(types.TileTable, CPU_IO_VRAM_ADDR + offset, true);
    } else {
        return memAddrToType(types.TileTable, PPU_VRAM_ADDR + offset, false);
    }
}

fn getSprite(comptime is_cpu: bool, sprite: u16) *types.SpriteDef {
    const offset = @sizeOf(types.SpriteDef) * sprite;
    if (is_cpu) {
        unreachable;
    } else {
        return memAddrToType(types.SpriteDef, PPU_SPROM_ADDR + offset, false);
    }
}

fn getPalette(comptime is_cpu: bool, palette: u16) *types.ColourPalette {
    const offset = VRAM_PALETTE_OFFSET + @sizeOf(types.ColourPalette) * palette;
    if (is_cpu) {
        return ioAddrToType(types.ColourPalette, CPU_VRAM_ADDR + offset, true);
    } else {
        return memAddrToType(types.ColourPalette, PPU_VRAM_ADDR + offset, false);
    }
}

fn getAttribute(comptime is_cpu: bool, attribute: u16) *types.SpriteAttribute {
    const offset: u16 = VRAM_ATTR_OFFSET + @sizeOf(types.SpriteAttribute) * attribute;
    if (is_cpu) {
        return ioAddrToType(types.SpriteAttribute, CPU_VRAM_ADDR + offset, true);
    } else {
        return memAddrToType(types.SpriteAttribute, PPU_VRAM_ADDR + offset, false);
    }
}

fn drawSprite2(renderer: *sdl.SDL_Renderer, sprite: *types.SpriteDef, palette: *types.ColourPalette, x: u32, y: u32) void {
    var sprite_x: u8 = 0;
    while (sprite_x < types.SPRITE_WIDTH) : (sprite_x += 1) {
        var sprite_y: u8 = 0;
        while (sprite_y < types.SPRITE_HEIGHT) : (sprite_y += 1) {
            const pixel = sprite[sprite_y][sprite_x];
            const colour = palette[pixel];
            const red = @intCast(u8, colour.red) * (255 / 7);
            const green = @intCast(u8, colour.green) * (255 / 7);
            const blue = @intCast(u8, colour.blue) * (255 / 3);
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
    while (tile_x < types.NUM_TILES_X) : (tile_x += 1) {
        var tile_y: u32 = 0;
        while (tile_y < types.NUM_TILES_Y) : (tile_y += 1) {
            const tile_entry = tile_table[tile_y][tile_x];
            if (tile_entry.enabled) {
                const palette = tile_entry.palette;
                const sprite = tile_entry.sprite;
                drawSprite2(renderer, getSprite(false, sprite), getPalette(false, palette), tile_x * types.SPRITE_WIDTH, tile_y * types.SPRITE_HEIGHT);
            }
        }
    }

    // Draw the sprites
    var i: u32 = 0;
    const sprite_table = getSpriteTable(false, 0);
    while (i < types.NUM_SPRITE_ENTRIES) : (i += 1) {
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

fn getControllerState() u8 {
    var result: u8 = 0;
    for (buttons) |pressed, i| {
        if (!pressed) result |= u8(1) << @intCast(u3, i);
    }
    return result;
}

fn scancodeToButton(scancode: c_int) ?Button {
    return switch (scancode) {
        sdl.SDL_SCANCODE_LEFT => Button.left,
        sdl.SDL_SCANCODE_RIGHT => Button.right,
        sdl.SDL_SCANCODE_UP => Button.up,
        sdl.SDL_SCANCODE_DOWN => Button.down,
        sdl.SDL_SCANCODE_A => Button.a,
        sdl.SDL_SCANCODE_S => Button.b,
        sdl.SDL_SCANCODE_D => Button.c,
        sdl.SDL_SCANCODE_ESCAPE => Button.start,
        else => null
    };
}

fn updateControllerState(event: *sdl.SDL_Event) void {
    if (scancodeToButton(@enumToInt(event.key.keysym.scancode))) |button| {
        switch (event.@"type") {
            sdl.SDL_KEYUP => buttons[@enumToInt(button)] = false,
            sdl.SDL_KEYDOWN => buttons[@enumToInt(button)] = true,
            else => unreachable
        }
    }
}

pub fn main() !void {
    if (cpu_rom.len > CPU_ROM_SIZE)
        std.debug.warn("CPU ROM size is greater than {}\n", u32(CPU_ROM_SIZE));
    if (ppu_rom.len > PPU_ROM_SIZE)
        std.debug.warn("PPU ROM size is greater than {}\n", u32(PPU_ROM_SIZE));
    if (spr_rom.len > SPR_ROM_SIZE)
        std.debug.warn("SPR ROM size is greater than {}\n", u32(SPR_ROM_SIZE));
    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO) != 0) {
        return ConsoleError.SdlInit;
    }

    cpu.memParam = 1;
    cpu.ioParam = 1;
    z80.Z80RESET(&cpu);

    if (!(sdl.SDL_SetHintWithPriority(sdl.SDL_HINT_NO_SIGNAL_HANDLERS, c"1", sdl.SDL_HintPriority.SDL_HINT_OVERRIDE) != sdl.SDL_bool.SDL_FALSE)) {
        return ConsoleError.SdlInit;
    }
    const scale_factor = 3;
    const screen = sdl.SDL_CreateWindow(c"Console", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, types.RES_X * scale_factor, types.RES_Y * scale_factor, sdl.SDL_WINDOW_RESIZABLE);
    const renderer = sdl.SDL_CreateRenderer(screen, -1, 0) orelse return ConsoleError.SdlInit;
    var ignored = sdl.SDL_RenderSetScale(renderer, f32(scale_factor), f32(scale_factor));

    ignored = sdl.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0);
    ignored = sdl.SDL_RenderClear(renderer);
    sdl.SDL_RenderPresent(renderer);

    var frames: u32 = 0;

    if (os.argv.len > 1) {
        const stdin = try std.io.getStdIn();
        while (true) {
            var instr_buff = [_]u8{0} ** 64;
            z80.Z80Debug(&cpu, null, &instr_buff);
            // Wait for input
            var buff: [1]u8 = undefined;
            _ = try stdin.read(buff[0..]);
            if (buff[0] == 'q')
                return;
            // Execute
            z80.Z80Execute(&cpu);
            // Show regs and instr
            std.debug.warn("{} (", instr_buff);
            var regs = cpu.R1;
            std.debug.warn("A={},", regs.br.A);
            std.debug.warn("B={},", regs.br.B);
            std.debug.warn("C={},", regs.br.C);
            std.debug.warn("D={},", regs.br.D);
            std.debug.warn("E={},", regs.br.E);
            std.debug.warn("H={},", regs.br.H);
            std.debug.warn("L={},", regs.br.L);
            std.debug.warn("IXl={},", regs.br.IXl);
            std.debug.warn("IXh={},", regs.br.IXh);
            std.debug.warn("IYl={},", regs.br.IYl);
            std.debug.warn("IYh={},", regs.br.IYh);
            std.debug.warn("F={},", regs.br.F);
            std.debug.warn("AF={},", regs.wr.AF);
            std.debug.warn("BC={},", regs.wr.BC);
            std.debug.warn("DE={},", regs.wr.DE);
            std.debug.warn("HL={},", regs.wr.HL);
            std.debug.warn("IX={},", regs.wr.IX);
            std.debug.warn("IY={},", regs.wr.IY);
            std.debug.warn("SP={})", regs.wr.SP);
            // Draw
            draw(renderer, frames);
        }
    }

    var last_update = std.time.milliTimestamp();
    var last_frame: u64 = std.time.milliTimestamp();

    while (true) {
        buttons = [_]bool{false} ** @memberCount(Button);
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
        var nanos_since_last_frame = (time - last_frame) * 1000000;
        last_frame = time;
        while (nanos_since_last_frame < NANOS_PER_FRAME) {
            var event: sdl.SDL_Event = undefined;
            if (SDL_PollEvent(&event) != 0) {
                if (event.@"type" == sdl.SDL_QUIT) {
                    return;
                } else {
                    updateControllerState(&event);
                    controller_byte = getControllerState();
                    if (controller_byte != 255) std.debug.warn("{}\n", controller_byte);
                }
            }
            // Sleep a millisecond
            std.time.sleep(1000);
            nanos_since_last_frame = (std.time.milliTimestamp() - last_frame) * 1000000;
        }
    }
}
