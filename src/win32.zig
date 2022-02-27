const std = @import("std");
const Game = @import("./game.zig");
const c = @cImport({
    @cInclude("windows.h");
});

fn fail(code: u32, comptime size: u32, msg: *[size]u8) noreturn {
    const fmt = c.FormatMessageA(c.FORMAT_MESSAGE_FROM_SYSTEM, c.NULL, code, 0, msg, size, 0);
    if (fmt == 0) {
        std.log.err("FormatMessageA fault (Lookup code {} at https://docs.microsoft.com/en-us/windows/win32/debug/system-error-codes)", .{c.GetLastError()});
    } else if (fmt != 0) {
        const prefix = if (code == 0) "(Could not get error) " else "";
        std.log.err("{s}{}: {s}", .{ prefix, code, msg });
    }
    std.os.exit(0);
}

const targetFps = 60.0;

var Window: c.HWND = 0;
const ErrorSize = 65535;
var ErrorMessage: [ErrorSize]u8 = undefined;

var GWin = Game.Window{
    .Width = 800,
    .Height = 600,
    .Buf = undefined,
};

const Screen = struct {
    Width: u32,
    Height: u32,
};

var screen = Screen{
    .Width = 0,
    .Height = 0,
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

fn resize(w: c.HWND, gw: *Game.Window, s: *Screen) void {
    var rect = c.RECT{
        .left = 0,
        .top = 0,
        .right = 0,
        .bottom = 0,
    };
    if (w != 0 and c.GetClientRect(w, &rect) == 0) {
        return fail(c.GetLastError(), ErrorSize, &ErrorMessage);
    }
    s.Width = @intCast(u32, rect.right - rect.left);
    s.Height = @intCast(u32, rect.bottom - rect.top);

    // Uncomment to use real width / height
    gw.Width = s.Width;
    gw.Height = s.Height;

    const size = @intCast(u32, gw.Width * gw.Height * 4);
    if (size == 0) {
        return;
    }

    if (gw.Buf.len != 0 and c.VirtualFree(gw.Buf.ptr, 0, c.MEM_RELEASE) == 0) {
        return fail(c.GetLastError(), ErrorSize, &ErrorMessage);
    }

    const mem = c.VirtualAlloc(c.NULL, size, c.MEM_RESERVE | c.MEM_COMMIT, c.PAGE_READWRITE);
    if (mem) |m| {
        gw.Buf.ptr = @ptrCast([*]u8, m);
        gw.Buf.len = size;
    } else {
        return fail(c.GetLastError(), ErrorSize, &ErrorMessage);
    }
}

var freq: struct { QuadPart: i64 } = .{ .QuadPart = 0 };
var time: struct { QuadPart: i64 } = .{ .QuadPart = 0 };

var frame: u64 = 0;

fn paint() void {
    if (GWin.Buf.len == 0) {
        return;
    }
    const result = Game.loop(&GWin, &Controls, &State);
    Controls.Q.Changed = false;
    Controls.Left.Changed = false;
    Controls.Up.Changed = false;
    Controls.Down.Changed = false;
    Controls.Space.Changed = false;
    Controls.Mouse.Moved = false;
    const start = time.QuadPart;
    if (c.QueryPerformanceCounter(@ptrCast([*c]c.LARGE_INTEGER, &time)) == 0) {
        return fail(c.GetLastError(), ErrorSize, &ErrorMessage);
    }
    const loopTime = @intToFloat(f32, @divTrunc((time.QuadPart - start) *% 1000000, freq.QuadPart)) / 1000.0;
    // std.log.err("ms/f: {d:.3}, fps: {d:.3}", .{ loopTime, 1000 / loopTime });
    if (loopTime > 0 and loopTime < (1000.0 / targetFps)) {
        c.Sleep(@floatToInt(u32, 1000.0 / targetFps - loopTime));
    }
    if (result == Game.Result.Exit) {
        std.os.exit(0);
    }
    var info = c.BITMAPINFO{
        .bmiHeader = c.BITMAPINFOHEADER{
            .biSize = @sizeOf(c.BITMAPINFOHEADER),
            .biWidth = @intCast(c_long, GWin.Width),
            .biHeight = -@intCast(c_long, GWin.Height),
            .biPlanes = 1,
            .biBitCount = 32,
            .biCompression = 0,
            .biSizeImage = 0,
            .biXPelsPerMeter = 0,
            .biYPelsPerMeter = 0,
            .biClrUsed = 0,
            .biClrImportant = 0,
        },
        .bmiColors = [1]c.RGBQUAD{
            c.RGBQUAD{
                .rgbBlue = 0,
                .rgbGreen = 0,
                .rgbRed = 0,
                .rgbReserved = 0,
            },
        },
    };
    const gameWidth = @intCast(c_int, GWin.Width);
    const gameHeight = @intCast(c_int, GWin.Height);
    const screenWidth = @intCast(c_int, screen.Width);
    const screenHeight = @intCast(c_int, screen.Height);
    const dc: c.HDC = c.GetDC(Window);
    const res = c.StretchDIBits(
        dc,
        0,
        0,
        screenWidth,
        screenHeight,
        0,
        0,
        gameWidth,
        gameHeight,
        GWin.Buf.ptr,
        &info,
        c.DIB_RGB_COLORS,
        c.SRCCOPY,
    );
    var str: []u8 = undefined;
    str.ptr = @ptrCast([*]u8, c.VirtualAlloc(c.NULL, 40, c.MEM_RESERVE | c.MEM_COMMIT, c.PAGE_READWRITE).?);
    str.len = 40;
    str = std.fmt.bufPrint(str, "f {d}; ms/f {d:.3}; fps {d:.3}", .{ frame, loopTime, 1000 / loopTime }) catch undefined;
    frame += 1;
    _ = c.SetBkMode(dc, c.TRANSPARENT);
    _ = c.SetTextColor(dc, 0x00FFFFFF);
    _ = c.TextOutA(dc, 0, 0, str.ptr, @intCast(c_int, str.len));
    if (res == 0) {
        return fail(c.GetLastError(), ErrorSize, &ErrorMessage);
    }
}

fn windowCallback(hWnd: c.HWND, Msg: c.UINT, wParam: c.WPARAM, lParam: c.LPARAM) callconv(.C) c.LRESULT {
    return switch (Msg) {
        c.WM_SIZE => {
            resize(Window, &GWin, &screen);
            return 0;
        },
        c.WM_PAINT => {
            paint();
            return 0;
        },
        c.WM_KEYDOWN,
        c.WM_KEYUP,
        c.WM_SYSKEYDOWN,
        c.WM_SYSKEYUP,
        c.WM_LBUTTONDOWN,
        c.WM_LBUTTONUP,
        c.WM_RBUTTONDOWN,
        c.WM_RBUTTONUP,
        => {
            const Control = switch (wParam) {
                81 => &Controls.Q,
                37, 65 => &Controls.Left,
                38, 87 => &Controls.Up,
                39, 68 => &Controls.Right,
                40, 83 => &Controls.Down,
                32 => &Controls.Space,
                else => null, // else => std.log.info("key pressed: {}", .{wParam}),
            };
            if (Control) |ctrl| {
                const Pressed = Msg == c.WM_KEYDOWN;
                ctrl.Changed = Pressed != ctrl.Pressed;
                ctrl.Pressed = Pressed;
            }
            return 0;
        },
        c.WM_MOUSEMOVE => {
            Controls.Mouse.X = @intCast(u32, lParam & 0xFFFF);
            Controls.Mouse.Y = @intCast(u32, lParam >> 16);
            Controls.Mouse.Moved = true;
            return 0;
        },
        c.WM_CLOSE,
        c.WM_QUIT,
        => std.os.exit(0),
        else => c.DefWindowProcA(hWnd, Msg, wParam, lParam),
    };
}

pub fn main() void {
    if (@import("builtin").mode != std.builtin.Mode.Debug) {
        _ = c.FreeConsole();
    }
    const Instance = c.GetModuleHandleA(0);
    if (Instance == 0) {
        return fail(c.GetLastError(), ErrorSize, &ErrorMessage);
    }
    const WindowClass = c.WNDCLASSA{
        .style = c.CS_HREDRAW | c.CS_VREDRAW | c.CS_OWNDC,
        .lpfnWndProc = windowCallback,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = Instance,
        .hIcon = 0,
        .hCursor = c.LoadCursorA(0, 32512),
        .hbrBackground = 0,
        .lpszMenuName = 0,
        .lpszClassName = "ThomasGameWindowClass",
    };
    if (c.RegisterClassA(&WindowClass) == 0) {
        return fail(c.GetLastError(), ErrorSize, &ErrorMessage);
    }
    Window = c.CreateWindowA(WindowClass.lpszClassName, // lpClassName
        "Thomas Game", // lpWindowName
        0x10CF0000, // dwStyle
        c.CW_USEDEFAULT, // X
        c.CW_USEDEFAULT, // Y
        c.CW_USEDEFAULT, // nWidth
        c.CW_USEDEFAULT, // nHeight
        0, // hWndParent
        0, // hMenu
        Instance, // hInstance
        c.NULL // lpParam
    );
    if (Window == 0) {
        return fail(c.GetLastError(), ErrorSize, &ErrorMessage);
    }

    if (c.QueryPerformanceFrequency(@ptrCast([*c]c.LARGE_INTEGER, &freq)) == 0) {
        return fail(c.GetLastError(), ErrorSize, &ErrorMessage);
    }

    var tagMsg = c.tagMSG{
        .hwnd = 0,
        .message = 0,
        .wParam = 0,
        .lParam = 0,
        .time = 0,
        .pt = c.POINT{ .x = 0, .y = 0 },
    };
    const lpMsg: c.LPMSG = &tagMsg;

    resize(Window, &GWin, &screen);
    while (true) {
        paint();
        while (c.PeekMessageA(lpMsg, Window, 0, 0, c.PM_REMOVE) != 0) {
            _ = c.TranslateMessage(lpMsg);
            _ = c.DispatchMessageA(lpMsg);
        }
    }
}
