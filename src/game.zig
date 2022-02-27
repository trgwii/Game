const std = @import("std");

pub const Window = struct {
    Width: u32,
    Height: u32,
    Buf: []u8,
};

pub const GameState = struct {
    OffsetY: i32,
    OffsetX: i32,
    Hue: u3,
    Player: struct {
        X: u32,
        Y: u32,
        Speed: u32,
    },
};

pub const KeyState = struct {
    Changed: bool,
    Pressed: bool,
};

pub const Controls = struct {
    Left: KeyState,
    Up: KeyState,
    Right: KeyState,
    Down: KeyState,
    Space: KeyState,
    Q: KeyState,
    Mouse: struct { X: u32, Y: u32, Moved: bool },
};

pub const Result = enum {
    Ok,
    Exit,
};

var rand = std.rand.DefaultPrng.init(0xFFFFFFFFFFFFFFFF);

fn vary(variance: u8, middle: u8) u8 {
    return @floatToInt(u8, rand.random().float(f32) * @intToFloat(f32, variance) * 2) + middle;
}

fn box(x: u32, y: u32, w: u32, h: u32, edges: bool, width: u32, bufSize: u32, buf: []u8, hue: u3) void {
    var row = y;
    while (row < y + h) {
        var col = x;
        while (col < x + w) {
            if (edges and col > x and col < x + w - 1 and row > y and row < y + h - 1) {
                col += 1;
                continue;
            }
            const offset = (col + row * width) * 4;
            if (offset + 3 < bufSize) {
                buf[offset + hue] = @floatToInt(u8, @intToFloat(f32, buf[offset + hue]) * 0.9);
                buf[offset + (hue + 1) % 3] = vary(16, 128);
            }
            col += 1;
        }
        row += 1;
    }
}

const pi = 3.141592653589793;

fn circle(x: u32, y: u32, r: f32, edges: bool, width: u32, bufSize: u32, buf: []u8, hue: u3) void {
    var i: f32 = 0;
    while (i < 360) {
        const angle = i;
        const row = @fabs(@floor(r * @sin(angle * pi / 180)));
        const col = @fabs(@floor(r * @cos(angle * pi / 180)));
        // std.log.crit("{}, {}", .{ row, col });
        const offset = ((@floatToInt(u32, col) + x) + (@floatToInt(u32, row) + y) * width) * 4;
        if (offset + 3 < bufSize) {
            buf[offset + hue] = @floatToInt(u8, @floor(@intToFloat(f32, buf[offset + hue]) * 0.9));
            buf[offset + (hue + 1) % 3] = vary(16, 128);
        }
        i += 0.1;
    }
    if (!edges) {
        var r2 = r - 1;
        while (r2 > 0) {
            circle(x, y, r2, true, width, bufSize, buf, hue);
            r2 -= 1;
        }
    }
}

pub fn loop(w: *Window, c: *Controls, s: *GameState) Result {
    { // controls
        if (c.Q.Pressed) {
            return Result.Exit;
        }

        const diagonalUpDown: f32 = if (c.Left.Pressed or c.Right.Pressed) 1.4142 else 1.0;
        const diagonalLeftRight: f32 = if (c.Up.Pressed or c.Down.Pressed) 1.4142 else 1.0;
        if (c.Left.Pressed) {
            s.Player.X -= @floatToInt(u32, @intToFloat(f32, s.Player.Speed) / diagonalLeftRight);
        }
        if (c.Up.Pressed) {
            s.Player.Y -= @floatToInt(u32, @intToFloat(f32, s.Player.Speed) / diagonalUpDown);
        }
        if (c.Right.Pressed) {
            s.Player.X += @floatToInt(u32, @intToFloat(f32, s.Player.Speed) / diagonalLeftRight);
        }
        if (c.Down.Pressed) {
            s.Player.Y += @floatToInt(u32, @intToFloat(f32, s.Player.Speed) / diagonalUpDown);
        }
        if (c.Space.Changed and c.Space.Pressed) {
            s.Hue = (s.Hue + 1) % 3;
        }
        if (c.Mouse.Moved) {
            s.Player.X = c.Mouse.X;
            s.Player.Y = c.Mouse.Y;
        }
    }
    { // paint
        const Height = w.Height;
        const Width = w.Width;
        const Buf = w.Buf;
        // const X = @intCast(u32, @mod(s.OffsetX, 255));
        // const Y = @intCast(u32, @mod(s.OffsetY, 255));
        var i: u32 = 0;
        var row: u32 = 0;
        while (row < Height) {
            var col: u32 = 0;
            while (col < Width) {
                if (rand.random().int(u32) < @floatToInt(u32, (4294967295 * 0.7))) {
                    col += 1;
                    continue;
                }
                i = (row * Width + col) * 4;

                // Clear RGBA quad (TODO: how to do this as a single u32 assignment? (check if asm already does that))
                for (Buf[i .. i + 3]) |*d|
                    d.* = 0;

                if (row % 2 != 0 or col % 2 != 0 or row % 3 != 0) {
                    col += 1;
                    continue;
                }
                Buf[i + s.Hue] = vary(16, 64);
                col += 1;
            }
            row += 1;
        }

        const eight = @floatToInt(u32, @floor(0.125 * @intToFloat(f32, Width)));
        const fourth = eight * 2;
        const threeEights = @floatToInt(u32, @floor(0.375 * @intToFloat(f32, Width)));
        const half = @floatToInt(u32, @floor(0.5 * @intToFloat(f32, Width)));
        const tiny = 0.0625 * @intToFloat(f32, Width);
        box(eight, eight, eight, eight, false, Width, @intCast(u32, w.Buf.len), w.Buf, s.Hue);
        box(fourth, fourth, eight, eight, true, Width, @intCast(u32, w.Buf.len), w.Buf, s.Hue);
        box(threeEights, threeEights, eight, eight, false, Width, @intCast(u32, w.Buf.len), w.Buf, s.Hue);

        circle(half + @floatToInt(u32, tiny), half + @floatToInt(u32, tiny), tiny, false, Width, @intCast(u32, w.Buf.len), w.Buf, s.Hue);
        circle(half + @floatToInt(u32, tiny) * 2, half + @floatToInt(u32, tiny) * 2, tiny, true, Width, @intCast(u32, w.Buf.len), w.Buf, s.Hue);
        circle(s.Player.X, s.Player.Y, 4.9, false, w.Width, @intCast(u32, w.Buf.len), w.Buf, s.Hue);
    }
    return Result.Ok;
}
