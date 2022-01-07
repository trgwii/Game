const std = @import("std");
const Game = @import("./game.zig");
const c = @cImport({
    @cInclude("stdlib.h");
    @cInclude("X11/Xlib.h");
    @cInclude("X11/Xutil.h");
    @cInclude("time.h");
    @cInclude("unistd.h");
});

pub fn screenOfDisplay(d: ?*c.Display, s: i32) [*c]c.Screen {
    return &std.zig.c_translation.cast(c._XPrivDisplay, d).*.screens[@intCast(usize, s)];
}

const Screen = struct {
    Width: u32,
    Height: u32,
};

var screen = Screen{
    .Width = 0,
    .Height = 0,
};

var GWin = Game.Window{
    .Width = 800,
    .Height = 600,
    .BufSize = 0,
    .Buf = undefined,
};

var Controls = Game.Controls{
    .Left = Game.KeyState{ .Changed = false, .Pressed = false },
    .Up = Game.KeyState{ .Changed = false, .Pressed = false },
    .Right = Game.KeyState{ .Changed = false, .Pressed = false },
    .Down = Game.KeyState{ .Changed = false, .Pressed = false },
    .Space = Game.KeyState{ .Changed = false, .Pressed = false },
    .Q = Game.KeyState{ .Changed = false, .Pressed = false },
    .Mouse = .{ .X = 0, .Y = 0, .Moved = false },
};

var State = Game.GameState{
    .OffsetX = 0,
    .OffsetY = 0,
    .Hue = 0,
    .Player = .{
        .X = 0,
        .Y = 0,
        .Speed = 3,
    },
};

pub fn xErrorHandler(d: ?*c.Display, e: [*c]c.XErrorEvent) callconv(.C) c_int {
    var text: [100]u8 = undefined;
    _ = c.XGetErrorText(d, e.*.error_code, &text, 100);
    std.log.err("{s}", .{text});
    return 0;
}

fn resize() void {
    const size = @intCast(u32, GWin.Width * GWin.Height * 4);
    if (GWin.BufSize > 0) {
        std.log.info("free {}", .{GWin.BufSize});
        c.free(GWin.Buf);
        GWin.BufSize = 0;
    }
    std.log.info("malloc {}", .{size});
    const mem = c.malloc(size);
    if (mem) |m| {
        std.log.info("malloc ok: {}", .{size});
        GWin.Buf = @ptrCast([*]u8, m);
        GWin.BufSize = size;
    }
}

pub fn main() void {
    _ = c.XSetErrorHandler(xErrorHandler);
    const d: ?*c.Display = c.XOpenDisplay(0);
    if (d == null) {
        std.log.err("Cannot open display\n", .{});
        return std.os.exit(1);
    }
    var frame: u64 = 0;
    const s: i32 = std.zig.c_translation.cast(c._XPrivDisplay, d).*.default_screen;
    const w: c.Window = c.XCreateSimpleWindow(
        d,
        screenOfDisplay(d, s).*.root,
        10,
        10,
        GWin.Width,
        GWin.Height,
        0,
        screenOfDisplay(d, s).*.black_pixel,
        screenOfDisplay(d, s).*.white_pixel,
    );
    _ = c.XSelectInput(d, w, c.ExposureMask | c.KeyPressMask | c.KeyReleaseMask | c.StructureNotifyMask | c.PointerMotionMask);
    _ = c.XMapWindow(d, w);
    var e: c.XEvent = undefined;
    var v: c.XVisualInfo = c.XVisualInfo{
        .visual = null,
        .visualid = 0,
        .screen = c.XDefaultScreen(d),
        .depth = 32,
        .class = 0,
        .red_mask = 0,
        .green_mask = 0,
        .blue_mask = 0,
        .colormap_size = 0,
        .bits_per_rgb = 32,
    };
    var nxvisuals: c_int = 0;
    _ = c.XGetVisualInfo(d, c.VisualScreenMask, &v, &nxvisuals);
    if (c.XMatchVisualInfo(d, c.XDefaultScreen(d), 32, c.TrueColor, &v) == 0) {
        std.os.exit(1);
    }
    resize();
    const i: [*c]c.XImage = c.XCreateImage(
        d, // Display *display
        v.visual, // Visual *visual
        24, // unsigned int depth
        c.ZPixmap, // int format
        0, // int offset
        GWin.Buf, // char *data
        GWin.Width, // unsigned int width
        GWin.Height, // unsigned int height
        8, // int bitmap_pad
        @intCast(c_int, GWin.Width * 4), // int bytes_per_line
    );
    var timespec = c.struct_timespec{ .tv_sec = 0, .tv_nsec = 0 };
    while (true) {
        while (c.XPending(d) > 0) {
            _ = c.XNextEvent(d, &e);
            if (e.type == c.Expose) {
                // if (GWin.BufSize > 0) {
                //     _ = c.XPutImage(d, w, screenOfDisplay(d, s).*.default_gc, i, 0, 0, 0, 0, GWin.Width, GWin.Height);
                // }
            }
            if (e.type == c.ConfigureNotify) {
                if (e.xconfigure.width != screen.Width or e.xconfigure.height != screen.Height) {
                    std.log.info("{}", .{e.xconfigure});
                    GWin.Width = @intCast(u32, e.xconfigure.width);
                    GWin.Height = @intCast(u32, e.xconfigure.height);
                    resize();
                    i.*.data = GWin.Buf;
                    i.*.width = @intCast(c_int, GWin.Width);
                    i.*.height = @intCast(c_int, GWin.Height);
                    i.*.bytes_per_line = @intCast(c_int, GWin.Width * 4);
                }
            }
            if (e.type == c.KeyPress or e.type == c.KeyRelease) {
                const Control = switch (e.xkey.keycode) {
                    24 => &Controls.Q,
                    38, 113 => &Controls.Left,
                    25, 111 => &Controls.Up,
                    40, 114 => &Controls.Right,
                    39, 116 => &Controls.Down,
                    65 => &Controls.Space,
                    else => null, // else => std.log.info("key pressed: {}", .{wParam}),
                };
                if (Control) |ctrl| {
                    const Pressed = e.type == c.KeyPress;
                    ctrl.Changed = Pressed != ctrl.Pressed;
                    ctrl.Pressed = Pressed;
                }
            }
            if (e.type == c.MotionNotify) {
                Controls.Mouse.X = @intCast(u32, e.xmotion.x);
                Controls.Mouse.Y = @intCast(u32, e.xmotion.y);
                Controls.Mouse.Moved = true;
            }
        }
        {
            const result = Game.loop(&GWin, &Controls, &State);
            Controls.Q.Changed = false;
            Controls.Left.Changed = false;
            Controls.Up.Changed = false;
            Controls.Down.Changed = false;
            Controls.Space.Changed = false;
            Controls.Mouse.Moved = false;

            if (result == Game.Result.Exit) {
                break;
            }
        }
        if (GWin.BufSize > 0) {
            _ = c.XPutImage(
                d, // Display *display
                w, // Drawable d
                screenOfDisplay(d, s).*.default_gc, // GC gc
                i, // XImage *image
                0, // int src_x
                0, // int src_y
                0, // int dest_x
                0, // int dest_y
                GWin.Width, // unsigned int width
                GWin.Height, // unsigned int height
            );
            var prev: f64 = @intToFloat(f64, timespec.tv_sec);
            prev += @intToFloat(f64, timespec.tv_nsec) / 1e+9;
            _ = c.clock_gettime(0, &timespec);
            var cur: f64 = @intToFloat(f64, timespec.tv_sec);
            cur += @intToFloat(f64, timespec.tv_nsec) / 1e+9;
            const loopTime = (cur - prev) * 1000.0;
            var str: []u8 = undefined;
            str.ptr = @ptrCast([*]u8, c.malloc(40).?);
            str.len = 40;
            frame += 1;

            str = std.fmt.bufPrint(str, "f {d}; ms/f {d:.3}; fps {d:.3}", .{ frame, loopTime, 1000 / loopTime }) catch undefined;
            _ = c.XSetForeground(d, screenOfDisplay(d, s).*.default_gc, 0xFFFFFFFF);
            _ = c.XDrawString(d, w, screenOfDisplay(d, s).*.default_gc, 0, 10, str.ptr, @intCast(c_int, str.len));
        }
    }

    _ = c.XCloseDisplay(d);
}
