const std = @import("std");
const c = @import("derg_clock_popup").c;

pub fn FrameIterator(comptime EasingT: type) type {
    if (!std.meta.hasMethod(EasingT, "countSteps") or !std.meta.hasMethod(EasingT, "calcFrame"))
        @compileError("easing struct type must have countSteps and calcFrame methods");

    return struct {
        easing: EasingT,
        step: u32 = 0,
        total_steps: u32,

        pub fn init(easing: EasingT) @This() {
            return .{
                .easing = easing,
                .step = 0,
                .total_steps = easing.countSteps(),
            };
        }

        pub fn next(self: *@This()) ?f32 {
            if (self.step >= self.total_steps)
                return null;

            const frame = self.easing.calcFrame(self.step);
            self.step += 1;
            return frame;
        }
    };
}

pub const ExpoEasing = struct {
    anim_frame_rate: f32 = 36,
    anim_dur_s: f32,
    scale_px: f32,
    exp_base: f32 = 10,
    graph_width: f32 = 5,

    pub fn countSteps(self: ExpoEasing) u32 {
        return @as(u32, @intFromFloat(self.anim_frame_rate * self.anim_dur_s)) + 1;
    }

    pub fn calcFrame(self: ExpoEasing, step: u32) f32 {
        const steps = self.anim_frame_rate * self.anim_dur_s;
        if (step > @as(u32, @intFromFloat(steps)))
            return 0;

        return self.scale_px * std.math.pow(f32, 1 / self.exp_base, self.graph_width / (steps - 1) * @as(f32, @floatFromInt(step)));
    }
};

pub fn ImgAnimIterator(
    comptime num_frames: u32,
    comptime frame_dir: []const u8,
    comptime name_idx_len: ?u8,
    comptime ext: []const u8,
) type {
    return struct {
        const name_index_len = name_idx_len orelse getNameIndexLen(num_frames - 1);
        const format: [7]u8 = ("{d:0>" ++ .{getDigitChar(name_index_len)} ++ "}").*;
        const path_len = frame_dir.len + name_index_len + ext.len;

        frame_count: u32 = num_frames,
        cur_frame: u32 = 0,
        rndr: ?*c.SDL_Renderer,

        frame_textures: [num_frames]?*c.SDL_Texture = undefined,

        fn getNameIndexLen(max_index: u32) u8 {
            return @intCast(std.math.log10_int(max_index) + 1);
        }

        fn getDigitChar(d: u8) u8 {
            return '0' + d % 10;
        }

        fn getFramePath(frame_idx: u32, buffer: *[path_len]u8) error{NoSpaceLeft}!void {
            @memcpy(buffer[0..frame_dir.len], frame_dir);
            _ = try std.fmt.bufPrint(buffer[frame_dir.len .. frame_dir.len + name_index_len], &format, .{frame_idx});
            @memcpy(buffer[frame_dir.len + name_index_len ..], ext);
        }

        pub fn init(rndr: ?*c.SDL_Renderer) @This() {
            var iter: @This() = .{ .rndr = rndr };
            for (&iter.frame_textures) |*t| {
                t.* = null;
            }

            return iter;
        }

        pub fn deinit(self: *@This()) void {
            for (&self.frame_textures) |*t| {
                if (t.* != null) {
                    c.SDL_DestroyTexture(t.*);
                    t.* = null;
                }
            }
        }

        pub fn next(self: *@This()) error{ TextureNotLoaded, NoSpaceLeft }!*c.SDL_Texture {
            if (self.frame_textures[self.cur_frame] == null) {
                var path_buf: [path_len + 1]u8 = undefined;
                try getFramePath(self.cur_frame, path_buf[0..path_len]);
                path_buf[path_len] = 0;

                self.frame_textures[self.cur_frame] = c.IMG_LoadTexture(self.rndr, &path_buf);
            }

            const idx = self.cur_frame;

            if (self.cur_frame < self.frame_count - 1) {
                self.cur_frame += 1;
            } else self.cur_frame = 0;

            return self.frame_textures[idx] orelse {
                std.log.err("failed to load texture: {s}\n", .{c.SDL_GetError()});
                return error.TextureNotLoaded;
            };
        }
    };
}

pub const FrameLimiter = struct {
    frame_rate: f64,
    last_tick: u64 = 0,

    pub fn isFrameTick(self: *@This(), tick_ms: u64) bool {
        const rel_tick = @as(u64, @intFromFloat(@as(f64, @floatFromInt(tick_ms)) * self.frame_rate / 1000)) + 1;
        if (rel_tick > self.last_tick) {
            self.last_tick = rel_tick;
            return true;
        }

        return false;
    }
};

pub const TickTimeout = struct {
    timeout_ms: u64,
    start_tick: u64 = undefined,

    pub fn start(self: *@This(), tick_ms: u64) void {
        self.start_tick = tick_ms;
    }

    pub fn isTimeoutTick(self: *@This(), tick_ms: u64) bool {
        if (tick_ms < self.start_tick)
            return false;

        if (tick_ms - self.start_tick >= self.timeout_ms) {
            self.start_tick = std.math.maxInt(@FieldType(@This(), "start_tick"));
            return true;
        }

        return false;
    }
};
