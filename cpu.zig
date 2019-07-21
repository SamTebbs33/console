const std = @import("std");
const ppu = @import("ppu.zig");

pub fn init() void {
   ppu.sprite_defs[0] = ppu.SpriteDef {
        [_]u4 {0, 1, 2, 3, 4, 5, 6, 7},   
        [_]u4 {0, 1, 2, 3, 4, 5, 6, 7},  
        [_]u4 {0, 1, 2, 3, 4, 5, 6, 7},  
        [_]u4 {0, 1, 2, 3, 4, 5, 6, 7},
        [_]u4 {0, 1, 2, 3, 4, 5, 6, 7},
        [_]u4 {0, 1, 2, 3, 4, 5, 6, 7},
        [_]u4 {0, 1, 2, 3, 4, 5, 6, 7},
        [_]u4 {0, 1, 2, 3, 4, 5, 6, 7}   
    }; 
   ppu.sprite_defs[1] = ppu.SpriteDef {
        [_]u9 {9, 9, 9, 9, 9, 9, 9, 9},   
        [_]u9 {9, 9, 9, 9, 9, 9, 9, 9},  
        [_]u9 {9, 9, 9, 9, 9, 9, 9, 9},  
        [_]u9 {9, 9, 9, 9, 9, 9, 9, 9},
        [_]u9 {9, 9, 9, 9, 9, 9, 9, 9},
        [_]u9 {9, 9, 9, 9, 9, 9, 9, 9},
        [_]u9 {9, 9, 9, 9, 9, 9, 9, 9},
        [_]u9 {9, 9, 9, 9, 9, 9, 9, 9}   
    }; 
    ppu.sprite_attrs[1] = ppu.Attribute {
        .max_num_inc = 0,
        .max_x_inc = 0,
        .max_y_inc = 0,
        .odd_updates_too = true,
        .enabled = true
    };
    ppu.palettes[0] = ppu.Palette {
        ppu.Colour { .red = 0, .green = 0, .blue = 0 },
        ppu.Colour { .red = 0, .green = 0, .blue = 255 },
        ppu.Colour { .red = 0, .green = 255, .blue = 0 },
        ppu.Colour { .red = 0, .green = 255, .blue = 255 },
        ppu.Colour { .red = 255, .green = 0, .blue = 0 },
        ppu.Colour { .red = 255, .green = 0, .blue = 255 },
        ppu.Colour { .red = 255, .green = 255, .blue = 0 },
        ppu.Colour { .red = 255, .green = 255, .blue = 255 },
        ppu.Colour { .red = 0, .green = 0, .blue = 0 },
        ppu.Colour { .red = 0, .green = 0, .blue = 255 },
        ppu.Colour { .red = 0, .green = 255, .blue = 0 },
        ppu.Colour { .red = 0, .green = 255, .blue = 255 },
        ppu.Colour { .red = 255, .green = 0, .blue = 0 },
        ppu.Colour { .red = 255, .green = 0, .blue = 255 },
        ppu.Colour { .red = 255, .green = 255, .blue = 0 },
        ppu.Colour { .red = 255, .green = 255, .blue = 255 }
    };
    var i: u8 = 0;
    while (i < ppu.NUM_TILES_Y) : (i += 1) {
        ppu.tile_tables[0][i][i] = ppu.TileEntry {
            .sprite = 0,
            .palette = 0,
            .enabled = true
        };
    }
    i = 0;
    while (i < ppu.NUM_SPRITES) : (i += 1) {
        ppu.sprite_tables[0][i] = ppu.SpriteEntry {
            .x = i / 32,
            .y = i % 32,
            .sprite = 1,
            .num_inc = 0,
            .x_inc = 0,
            .y_inc = 0,
            .palette = 0,
            .attribute = 1
        };
    }
}

pub fn clock() void {
}
