pub const c = @cImport({
    @cInclude("time.h");
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3_ttf/SDL_ttf.h");
    @cInclude("SDL3_image/SDL_image.h");
});

pub const build_options = @import("build_options");
