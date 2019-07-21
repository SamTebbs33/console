const std = @import("std");
const cpu = @import("cpu.zig");

pub const NUM_SPRITE_DEFS = 256;
pub const NUM_SPRITE_ATTRS = 256;
pub const NUM_SPRITES = 64;
pub const NUM_PALETTES = 4;
pub const NUM_TILE_TABLES = 2;
pub const NUM_SPRITE_TABLES = 2;
pub const NUM_TILES_X = 32;
pub const NUM_TILES_Y = 32;
pub const RES_X = NUM_TILES_X * 8;
pub const RES_Y = NUM_TILES_Y * 8;
pub var pixels: [RES_X][RES_Y]Colour = undefined;

pub var sprite_defs: [NUM_SPRITE_DEFS]SpriteDef = undefined;
pub var sprite_attrs: [NUM_SPRITE_ATTRS]Attribute = undefined;
pub var palettes: [NUM_PALETTES]Palette = undefined;
pub var tile_tables: [NUM_TILE_TABLES]TileTable = undefined;
pub var sprite_tables: [NUM_SPRITE_TABLES]SpriteTable = undefined;

pub const FPS = 30;
pub const FRAME_TIME = 1000 / FPS;
var last_update: u64 = 0;
var even_update = true;
var num_sprites: u8 = 3;

pub const Pixel = u4;
pub const SpriteDef = [8][8]Pixel;
pub const Palette = [16]Colour;
pub const Colour = struct {
    red: u8,
    green: u8,
    blue: u8,
    transparent: bool = false
};
pub const Attribute = struct {
    max_num_inc: u2,
    max_x_inc: u2,
    max_y_inc: u2,
    odd_updates_too: bool,
    enabled: bool
};
pub const SpriteTable = [NUM_SPRITES]SpriteEntry;
pub const TileTable = [NUM_TILES_X][NUM_TILES_Y]TileEntry;
pub const SpriteEntry = struct {
    x: u8,
    y: u8,
    sprite: u8,
    num_inc: u2,
    x_inc: u2,
    y_inc: u2,
    palette: u2,
    attribute: u2
};
pub const TileEntry = struct {
    sprite: u8,
    palette: u2,
    enabled: bool,
    unused: u5 = 0
};

var tile_x: u16 = 0;
var tile_y: u16 = 0;
var sprite_i: u16 = 0;
var rendering_tiles = true;

pub fn clock() void {
    // Render tiles
    if (rendering_tiles) {
        const tile_table = tile_tables[0];
        const tile = tile_table[tile_x][tile_y];
        if (tile.enabled) {
            const sprite = sprite_defs[tile.sprite];
            for (sprite) |sprite_column, sprite_x| {
                for (sprite_column) |pixel, sprite_y| {
                    const colour = palettes[tile.palette][pixel];
                    renderColour(colour, tile_x * 8 + sprite_x, tile_y * 8 + sprite_y);
                }
            }
        }
        tile_x += 1;
        tile_y += 1;
        if (tile_x >= NUM_TILES_X) {
            tile_x = 0;
            if (tile_y >= NUM_TILES_Y)
                rendering_tiles = false;
        }
        if (tile_y >= NUM_TILES_Y)
            tile_y = 0;
    } else {
        const sprite_table = sprite_tables[0];
        const entry = sprite_table[sprite_i];
        const attr = sprite_attrs[entry.attribute];
        if (attr.enabled) {
            const sprite = sprite_defs[entry.sprite];
            for (sprite) |sprite_col, pixel_y| {
                for (sprite_col) |pixel, pixel_x| {
                    const colour = palettes[entry.palette][pixel];
                    renderColour(colour, entry.x + pixel_x, entry.y + pixel_y);
                }
            }
        }
        sprite_i += 1;
        if (sprite_i >= NUM_SPRITES) {
            rendering_tiles = true;
            sprite_i = 0;
        }
    }
}

fn renderColour(colour: Colour, pixel_x: usize, pixel_y: usize) void {
    pixels[pixel_x][pixel_y] = colour;
}

fn renderPixel(pixel: u8, pixel_x: usize, pixel_y: usize) void {
    pixels[pixel_x][pixel_y] = pixel;
}
