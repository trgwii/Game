import { Pane } from "https://deno.land/x/pane@0.1.1/mod.ts";

const enum Pixel {
  R = 0,
  G = 1,
  B = 2,
  A = 3,
}

const width = 400;
const height = 300;
const bytesPerPixel = 4;
const frame = new Uint8Array(width * height * bytesPerPixel);
let hue = 0;

const dude = {
  x: 50,
  y: height - 50,
  keys: {
    W: false,
    A: false,
    S: false,
    D: false,
  },
  speed: 3,
};

const pane = new Pane(width, height);
pane.setTitle("Game");
pane.setMaximized(true);

const exit = () => {
  console.error("exit");
  clearInterval(loopInterval);
  clearInterval(fpsAdjustInterval);
};

const vary = (variance: number, middle: number) =>
  Math.floor(Math.random() * variance * 2) + middle;

const clamp = (min: number, max: number, x: number) =>
  min > x ? min : max < x ? max : x;

const box = (
  x: number,
  y: number,
  w: number,
  h: number,
  edges = false,
) => {
  return (frame: Uint8Array) => {
    for (let row = y; row < y + h; row++) {
      for (let col = x; col < x + w; col++) {
        if (edges && col > x && col < x + w - 1 && row > y && row < y + h - 1) {
          continue;
        }
        const offset = (col + row * width) * bytesPerPixel;
        const pixel = frame.subarray(offset, offset + bytesPerPixel);
        pixel[hue] = Math.floor(pixel[hue] * 0.9);
        pixel[(hue + 1) % 3] = vary(16, 128);
      }
    }
  };
};

const circle = (x: number, y: number, r: number, edges = true) =>
  (frame: Uint8Array) => {
    for (let i = 0; i < 360; i += 0.1) {
      const angle = i;
      const row = Math.floor(r * Math.sin(angle * Math.PI / 180));
      const col = Math.floor(r * Math.cos(angle * Math.PI / 180));
      const offset = ((col + x) + (row + y) * width) * bytesPerPixel;
      const pixel = frame.subarray(offset, offset + bytesPerPixel);
      pixel[hue] = Math.floor(pixel[hue] * 0.9);
      pixel[(hue + 1) % 3] = vary(16, 128);
    }
    if (!edges) {
      for (let r2 = r - 1; r2 > 0; r2--) {
        circle(x, y, r2)(frame);
      }
    }
  };

let loopInterval: number | undefined;

let time = 0;
let runs = 0;

const fpsAdjustInterval = setInterval(() => {
  const t = time / runs;
  const nextInterval = Math.floor(t) + 5;
  clearInterval(loopInterval);
  loopInterval = setInterval(loop, nextInterval);
  console.log("New fps: " + Math.floor(1000 / nextInterval));
  time = 0;
  runs = 0;
  loop();
}, 5_000);

const loop = () => {
  const start = performance.now();
  for (const event of Pane.Step()) {
    switch (event.type) {
      case "windowEvent": {
        const windowEvent = event.value.event;
        switch (windowEvent.type) {
          case "destroyed":
          case "closeRequested": {
            return exit();
          }
          case "resized": {
            // width = windowEvent.value.width;
            // height = windowEvent.value.height;
            // frame = new Uint8Array(width * height * bytesPerPixel);
            pane.resizeFrame(
              windowEvent.value.width,
              windowEvent.value.height,
            );
            break;
          }
        }
        break;
      }
      case "redrawRequested": {
        for (let row = 0; row < height; row++) {
          for (let col = 0; col < width; col++) {
            if (Math.random() < 0.7) {
              continue;
            }
            const pixelOffset = col + row * width;
            const offset = pixelOffset * bytesPerPixel;
            const pixel = frame.subarray(offset, offset + bytesPerPixel);
            pixel[Pixel.R] = 0;
            pixel[Pixel.B] = 0;
            pixel[Pixel.G] = 0;
            if (row % 2 || col % 2 || row % 3) {
              continue;
            }
            pixel[hue] = vary(16, 64);
          }
        }
        const eight = Math.floor(0.125 * width);
        const fourth = Math.floor(eight * 2);
        const threeEights = Math.floor(0.375 * width);
        const half = Math.floor(0.5 * width);
        const tiny = Math.floor(0.0625 * width);
        box(eight, eight, eight, eight)(frame);
        box(fourth, fourth, eight, eight, true)(frame);
        box(threeEights, threeEights, eight, eight)(frame);
        circle(half + tiny, half + tiny, tiny, false)(frame);
        circle(half + tiny * 2, half + tiny * 2, tiny)(frame);

        circle(Math.floor(dude.x), Math.floor(dude.y), 4.9)(frame);
        const diagonalUpDown = dude.keys.A || dude.keys.D ? 1.4142 : 1;
        const diagonalLeftRight = dude.keys.W || dude.keys.S ? 1.4142 : 1;
        if (dude.keys.W) {
          dude.y = clamp(5, height - 5, dude.y - dude.speed / diagonalUpDown);
        }
        if (dude.keys.A) {
          dude.x = clamp(5, width - 5, dude.x - dude.speed / diagonalLeftRight);
        }
        if (dude.keys.S) {
          dude.y = clamp(5, height - 5, dude.y + dude.speed / diagonalUpDown);
        }
        if (dude.keys.D) {
          dude.x = clamp(5, width - 5, dude.x + dude.speed / diagonalLeftRight);
        }
        break;
      }
      case "deviceEvent": {
        const deviceEvent = event.value.event;
        switch (deviceEvent.type) {
          case "key": {
            const key = deviceEvent.value;
            if (key.state === "pressed") {
              if (key.virtualKeycode === "Q") {
                return exit();
              }
              if (key.virtualKeycode === "Space") {
                hue = (hue + 1) % 3;
                break;
              }
              if (key.virtualKeycode === "W") {
                dude.keys.W = true;
                break;
              }
              if (key.virtualKeycode === "A") {
                dude.keys.A = true;
                break;
              }
              if (key.virtualKeycode === "S") {
                dude.keys.S = true;
                break;
              }
              if (key.virtualKeycode === "D") {
                dude.keys.D = true;
                break;
              }
            }
            if (key.state === "released") {
              if (key.virtualKeycode === "W") {
                dude.keys.W = false;
                break;
              }
              if (key.virtualKeycode === "A") {
                dude.keys.A = false;
                break;
              }
              if (key.virtualKeycode === "S") {
                dude.keys.S = false;
                break;
              }
              if (key.virtualKeycode === "D") {
                dude.keys.D = false;
                break;
              }
            }
          }
        }
      }
    }
  }
  pane.drawFrame(frame);
  pane.renderFrame();
  pane.requestRedraw();
  time += performance.now() - start;
  runs++;
};

loopInterval = setInterval(loop, 30);

loop();
