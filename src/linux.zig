const std = @import("std");
const Game = @import("./game.zig");
const c = @cImport({
    @cInclude("stdlib.h");
    @cInclude("X11/Xlib.h");
});

pub fn screenOfDisplay(d: ?*c.Display, s: i32) [*c]c.Screen {
    return &std.zig.c_translation.cast(c._XPrivDisplay, d).*.screens[@intCast(usize, s)];
}

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

pub fn main() void {
    const d: ?*c.Display = c.XOpenDisplay(0);
    if (d == null) {
        std.log.crit("Cannot open display\n", .{});
        return std.os.exit(1);
    }
    const s: i32 = std.zig.c_translation.cast(c._XPrivDisplay, d).*.default_screen;
    const w: c.Window = c.XCreateSimpleWindow(d, screenOfDisplay(d, s).*.root, 10, 10, GWin.Width, GWin.Height, 1, screenOfDisplay(d, s).*.black_pixel, screenOfDisplay(d, s).*.white_pixel);
    _ = c.XSelectInput(d, w, c.ExposureMask | c.KeyPressMask | c.KeyReleaseMask);
    _ = c.XMapWindow(d, w);
    const msg = "Hello, World!";
    var e: c.XEvent = undefined;
    const size = @intCast(u32, GWin.Width * GWin.Height * 4);
    const mem = c.malloc(size);
    if (mem) |m| {
        std.log.info("malloc: {}", .{size});
        GWin.Buf = @ptrCast([*]u8, m);
        GWin.BufSize = size;
    }
    while (true) {
        while (c.XPending(d) > 0) {
            _ = c.XNextEvent(d, &e);
            if (e.type == c.Expose) {
                _ = c.XFillRectangle(d, w, screenOfDisplay(d, s).*.default_gc, @intCast(c_int, State.Player.X), @intCast(c_int, State.Player.Y), 10, 10);
                _ = c.XDrawString(d, w, screenOfDisplay(d, s).*.default_gc, 10, 50, msg, 13);
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
        }
        {
            const result = Game.loop(&GWin, &Controls, &State);
            Controls.Q.Changed = false;
            Controls.Left.Changed = false;
            Controls.Up.Changed = false;
            Controls.Down.Changed = false;
            Controls.Space.Changed = false;

            if (result == Game.Result.Exit) {
                break;
            }
        }
        _ = c.XFillRectangle(d, w, screenOfDisplay(d, s).*.default_gc, @intCast(c_int, State.Player.X), @intCast(c_int, State.Player.Y), 10, 10);
    }
    _ = c.XCloseDisplay(d);
}
