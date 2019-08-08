pub const RES_X = 240;
pub const RES_Y = 240;
pub const SPRITE_WIDTH = 8;
pub const SPRITE_HEIGHT = 8;
pub const NUM_TILES_X = RES_X / SPRITE_WIDTH;
pub const NUM_TILES_Y = RES_Y / SPRITE_HEIGHT;

pub const NUM_TILE_TABLES = 2;
pub const NUM_PALETTES = 4;
pub const NUM_ATTRIBUTES = 256;
pub const NUM_SPRITE_ENTRIES = 64;

pub const Pixel = u8;
pub const SpriteDef = [SPRITE_HEIGHT][SPRITE_WIDTH]Pixel;
pub const Colour = packed struct {
    red: u3,
    green: u3,
    blue: u2
};
pub const ColourPalette = [16]Colour;
pub const SpriteEntry = packed struct {
    x: u8,
    y: u8,
    sprite: u8,
    sprite_inc: u2,
    x_inc: u2,
    y_inc: u2,
    palette: u2,
    attribute: u8
};
pub const SpriteAttribute = packed struct {
    sprite_max_inc: u2,
    x_max_inc: u2,
    y_max_inc: u2,
    fourth_frame_too: bool,
    enabled: bool
};
pub const SpriteTable = [NUM_SPRITE_ENTRIES]SpriteEntry;
pub const TileEntry = packed struct {
    palette: u2,
    enabled: bool,
    unused: u5,
    sprite: u8
};
pub const TileTable = [NUM_TILES_Y][NUM_TILES_X]TileEntry;
