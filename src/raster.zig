const std = @import("std");
const c = @import("derg_clock_popup").c;

pub fn renderFillOuterQCircle(rndr: ?*c.SDL_Renderer, p: c.SDL_Point, r: i32, q: i8, color: c.SDL_Color) void {
    var x = r - 1;
    var y: i32 = 0;
    var dx: i32 = 1;
    var dy: i32 = 1;
    var err = dx - r * 2;

    const xq: i32 = switch (q) {
        4, 1 => 1,
        2, 3 => -1,
        else => unreachable,
    };

    const yq: i32 = switch (q) {
        3, 4 => 1,
        1, 2 => -1,
        else => unreachable,
    };

    _ = c.SDL_SetRenderDrawColor(rndr, color.r, color.g, color.b, color.a);

    while (x >= y) {
        _ = c.SDL_RenderLine(rndr, @floatFromInt(p.x + xq * r), @floatFromInt(p.y + yq * y), @floatFromInt(p.x + xq * (x + 1)), @floatFromInt(p.y + yq * y));
        _ = c.SDL_RenderLine(rndr, @floatFromInt(p.x + xq * r), @floatFromInt(p.y + yq * x), @floatFromInt(p.x + xq * (y + 1)), @floatFromInt(p.y + yq * x));

        if (err <= 0) {
            y += 1;
            err += dy;
            dy += 2;
        }

        if (err > 0) {
            x -= 1;
            dx += 2;
            err += dx - 2 * r;
        }
    }
}
