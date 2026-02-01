const std = @import("std");
const time = std.time;
const derg_clock_popup = @import("derg_clock_popup");
const c = derg_clock_popup.c;
const build_options = derg_clock_popup.build_options;
const anim = @import("anim.zig");
const raster = @import("raster.zig");

const time_buf_size = 8;

const title = "derg clock popup";
const font_path = build_options.assets_path ++ "/fonts/PressStart-Regular.ttf";
const derg_frame_path = build_options.assets_path ++ "/derg-frames/";

const font_size: f32 = 120;

const bg_color: c.SDL_Color = .{
    .r = 0x22,
    .g = 0x22,
    .b = 0x22,
    .a = 0x88,
};

const fg_color: c.SDL_Color = .{
    .r = 0xdd,
    .g = 0xdd,
    .b = 0xdd,
    .a = 0xff,
};

const trans_color: c.SDL_Color = .{
    .r = 0,
    .g = 0,
    .b = 0,
    .a = 0,
};

const text_padding = 64;

const neg_top_offset_rel: f32 = 0;
const neg_left_offset_rel: f32 = 0;
const neg_bottom_offset_rel: f32 = @as(f32, 1) / 8.0;
const neg_right_offset_rel: f32 = @as(f32, 1) / 8.0;

const neg_top_offset: f32 = font_size * neg_top_offset_rel;
const neg_left_offset: f32 = font_size * neg_left_offset_rel;
const neg_bottom_offset: f32 = font_size * neg_bottom_offset_rel;
const neg_right_offset: f32 = font_size * neg_right_offset_rel;

const derg_floor_y_offset = 41;
const derg_upper_clip_offset = 5;
const derg_w = 120;
const derg_scale = 4;
const window_anim_y_offset = 300;
const window_y_offset = (derg_floor_y_offset - derg_upper_clip_offset) * derg_scale;

const border_radius = 20;

const anim_pause_ms: u64 = 2000;

var rndr: ?*c.SDL_Renderer = null;
var win: ?*c.SDL_Window = null;

pub fn main() !void {
    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
        std.log.err("failed to initialize SDL: {s}\n", .{c.SDL_GetError()});
        return error.SDLInitFailed;
    }
    defer c.SDL_Quit();

    if (!c.TTF_Init()) {
        std.log.err("failed to initialize SDL_ttf: {s}\n", .{c.SDL_GetError()});
        return error.TTFInitFailed;
    }
    defer c.TTF_Quit();

    const cur_time = c.time(null);
    const tm = c.localtime(&cur_time);
    var time_buf: [time_buf_size]u8 = undefined;

    const w_len = c.strftime(&time_buf[0], time_buf_size, "%H:%M", tm);
    const time_str = time_buf[0..w_len];

    const font = c.TTF_OpenFont(font_path, font_size);
    if (font == null) {
        std.log.err("failed to load font: {s}\n", .{c.SDL_GetError()});
        return error.FontLoadFailed;
    }
    defer c.TTF_CloseFont(font);

    var text_surf = c.TTF_RenderText_Blended(
        font,
        time_str.ptr,
        time_str.len,
        fg_color,
    );
    if (text_surf == null) {
        std.log.err("failed to render text: {s}\n", .{c.SDL_GetError()});
        return error.TextRenderFailed;
    }

    var disp_count: c_int = undefined;
    const disps = c.SDL_GetDisplays(&disp_count);
    if (disps == null or disp_count < 1) {
        std.log.err("failed to get displays: {s}\n", .{c.SDL_GetError()});
        return error.DisplayGetFailed;
    }

    const disp_mode = c.SDL_GetCurrentDisplayMode(disps[0]);
    if (disp_mode == null) {
        std.log.err("failed to get display mode: {s}\n", .{c.SDL_GetError()});
        return error.DisplayModeGetFailed;
    }

    const win_w = text_surf.*.w + 2 * text_padding - @as(c_int, @intFromFloat(neg_left_offset + neg_right_offset));
    const floating_win_h = text_surf.*.h + 2 * text_padding - @as(c_int, @intFromFloat(neg_top_offset + neg_bottom_offset));
    const win_h = floating_win_h + window_anim_y_offset + window_y_offset;

    c.SDL_DestroySurface(text_surf);

    if (!c.SDL_CreateWindowAndRenderer(
        title,
        win_w,
        win_h,
        c.SDL_WINDOW_BORDERLESS | c.SDL_WINDOW_TRANSPARENT | c.SDL_WINDOW_NOT_FOCUSABLE | c.SDL_WINDOW_ALWAYS_ON_TOP | c.SDL_WINDOW_UTILITY,
        &win,
        &rndr,
    )) {
        std.log.err("failed to create window and renderer: {s}\n", .{c.SDL_GetError()});
        return error.WindowAndRendererCreationFailed;
    }
    defer {
        c.SDL_DestroyRenderer(rndr);
        c.SDL_DestroyWindow(win);
    }

    const center_x = @divTrunc(disp_mode.*.w - win_w, 2);
    const center_y = @divTrunc(disp_mode.*.h - floating_win_h, 2) - window_y_offset;

    _ = c.SDL_SetWindowPosition(win, center_x, center_y);

    const easing: anim.ExpoEasing = .{ .anim_dur_s = 1, .scale_px = 1 };
    var window_frame_iter: anim.FrameIterator(anim.ExpoEasing) = .init(easing);
    var anim_end = false;
    var window_anim_first_part = true;
    var window_y_frame: c_int = undefined;
    var window_frame_dir: f32 = undefined;
    var window_anim_dir: c_int = undefined;
    var window_anim_paused: bool = false;
    var window_anim_pause_timeout: anim.TickTimeout = .{ .timeout_ms = 2000 };

    var window_frame_lim: anim.FrameLimiter = .{ .frame_rate = easing.anim_frame_rate, .last_tick = 0 };

    var derg_anim_iter: anim.ImgAnimIterator(16, derg_frame_path, 3, ".png") = .init(rndr);
    defer derg_anim_iter.deinit();

    var derg_frame_lim: anim.FrameLimiter = .{ .frame_rate = 8, .last_tick = 0 };
    var derg_frame_tex: ?*c.SDL_Texture = null;
    var derg_y_frame: c_int = undefined;

    var event: c.SDL_Event = undefined;
    var running = true;

    while (running and !anim_end) {
        while (c.SDL_PollEvent(&event)) {
            switch (event.type) {
                c.SDL_EVENT_QUIT => running = false,
                else => {},
            }
        }

        var redraw = false;
        const ticks = c.SDL_GetTicks();

        if (window_anim_paused and window_anim_pause_timeout.isTimeoutTick(ticks))
            window_anim_paused = false;

        if (window_frame_lim.isFrameTick(ticks) and !window_anim_paused) {
            redraw = true;

            if (!window_anim_first_part and window_frame_iter.step > window_frame_iter.total_steps)
                anim_end = true;

            if (window_frame_iter.next()) |window_frame| {
                window_anim_dir = if (window_anim_first_part) 1 else -1;
                window_frame_dir = if (window_anim_first_part) (1 - window_frame) else window_frame;

                if (window_anim_first_part) {
                    derg_y_frame = window_anim_dir * @as(c_int, @intFromFloat(window_anim_y_offset * (1 - window_frame_dir)));
                    window_y_frame = derg_y_frame + window_y_offset;
                }
            } else if (window_anim_first_part) {
                window_anim_first_part = false;
                window_anim_paused = true;
                window_anim_pause_timeout.start(ticks);
                window_frame_iter.step = 0;
            } else anim_end = true;
        }
        if (derg_frame_lim.isFrameTick(ticks)) {
            redraw = true;

            derg_frame_tex = try derg_anim_iter.next();
            _ = c.SDL_SetTextureScaleMode(derg_frame_tex, c.SDL_SCALEMODE_NEAREST);
        }

        if (redraw) {
            _ = c.SDL_SetRenderDrawColor(rndr, 0, 0, 0, 0);
            _ = c.SDL_RenderClear(rndr);

            _ = c.SDL_SetRenderDrawColor(
                rndr,
                @intFromFloat(window_frame_dir * bg_color.r),
                @intFromFloat(window_frame_dir * bg_color.g),
                @intFromFloat(window_frame_dir * bg_color.b),
                @intFromFloat(window_frame_dir * bg_color.a),
            );

            const back_rect: c.SDL_FRect = .{
                .x = 0,
                .y = @floatFromInt(window_y_frame),
                .w = @floatFromInt(win_w),
                .h = @floatFromInt(floating_win_h),
            };
            _ = c.SDL_RenderFillRect(rndr, &back_rect);

            const fg_color_frame: c.SDL_Color = .{
                .r = @intFromFloat(window_frame_dir * fg_color.r),
                .g = @intFromFloat(window_frame_dir * fg_color.g),
                .b = @intFromFloat(window_frame_dir * fg_color.b),
                .a = @intFromFloat(window_frame_dir * fg_color.a),
            };

            text_surf = c.TTF_RenderText_Blended(
                font,
                time_str.ptr,
                time_str.len,
                fg_color_frame,
            );
            if (text_surf == null) {
                std.log.err("failed to render text: {s}\n", .{c.SDL_GetError()});
                return error.TextRenderFailed;
            }

            const details = c.SDL_GetPixelFormatDetails(text_surf.*.format);
            const key = c.SDL_MapRGBA(details, null, 0, 0, 0, 0);
            _ = c.SDL_SetSurfaceColorKey(text_surf, true, key);

            const text_tex = c.SDL_CreateTextureFromSurface(rndr, text_surf);
            if (text_tex == null) {
                std.log.err("failed to create texture from surface: {s}\n", .{c.SDL_GetError()});
                return error.TextureCreateFailed;
            }
            defer c.SDL_DestroyTexture(text_tex);
            c.SDL_DestroySurface(text_surf);

            const src_rect: c.SDL_FRect = .{
                .x = neg_left_offset,
                .y = neg_top_offset,
                .w = @as(f32, @floatFromInt(text_tex.*.w)) - (neg_left_offset + neg_right_offset),
                .h = @as(f32, @floatFromInt(text_tex.*.h)) - (neg_top_offset + neg_bottom_offset),
            };

            const dst_rect: c.SDL_FRect = .{
                .x = text_padding,
                .y = @as(f32, @floatFromInt(window_y_frame)) + text_padding,
                .w = src_rect.w,
                .h = src_rect.h,
            };

            _ = c.SDL_RenderTexture(rndr, text_tex, &src_rect, &dst_rect);

            raster.renderFillOuterQCircle(rndr, .{ .x = win_w - border_radius - 1, .y = window_y_frame + border_radius - 1 }, border_radius, 1, trans_color);
            raster.renderFillOuterQCircle(rndr, .{ .x = border_radius, .y = window_y_frame + border_radius - 1 }, border_radius, 2, trans_color);
            raster.renderFillOuterQCircle(rndr, .{ .x = border_radius, .y = window_y_frame + floating_win_h - border_radius }, border_radius, 3, trans_color);
            raster.renderFillOuterQCircle(rndr, .{ .x = win_w - border_radius - 1, .y = window_y_frame + floating_win_h - border_radius }, border_radius, 4, trans_color);

            if (derg_frame_tex) |tex| {
                _ = c.SDL_SetTextureAlphaModFloat(tex, window_frame_dir);

                const derg_dest: c.SDL_FRect = .{
                    .x = @floatFromInt(@divTrunc((win_w - derg_w * derg_scale), 2)),
                    .y = @floatFromInt(-derg_upper_clip_offset * derg_scale + derg_y_frame),
                    .w = @as(f32, @floatFromInt(tex.w)) * derg_scale,
                    .h = @as(f32, @floatFromInt(tex.h)) * derg_scale,
                };

                _ = c.SDL_RenderTexture(rndr, tex, null, &derg_dest);
            }

            _ = c.SDL_RenderPresent(rndr);
        }
    }
}
