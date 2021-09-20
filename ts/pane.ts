import { PaneEventLoop, PaneWindow } from "https://deno.land/x/pane@0.2.1/mod.ts";

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
  tick() {
    const diagonalUpDown = this.keys.A || this.keys.D ? 1.4142 : 1;
    const diagonalLeftRight = this.keys.W || this.keys.S ? 1.4142 : 1;
    if (this.keys.W) {
      this.y = clamp(5, height - 5, this.y - this.speed / diagonalUpDown);
    }
    if (this.keys.A) {
      this.x = clamp(5, width - 5, this.x - this.speed / diagonalLeftRight);
    }
    if (this.keys.S) {
      this.y = clamp(5, height - 5, this.y + this.speed / diagonalUpDown);
    }
    if (this.keys.D) {
      this.x = clamp(5, width - 5, this.x + this.speed / diagonalLeftRight);
    }
  },
};

const eventLoop = new PaneEventLoop();
const pane = new PaneWindow(eventLoop);
pane.setTitle("Game");
pane.setMaximized(true);

const exit = () => {
  console.error("exit");
  clearInterval(loopInterval);
  clearInterval(fpsAdjustInterval);
  clearInterval(gameInterval);
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
  console.log({ speed: dude.speed, x: dude.x, y: dude.y });
}, 5_000);

const gameInterval = setInterval(() => {
  dude.tick();
}, 20);

const loop = () => {
  const start = performance.now();

  const events = eventLoop.step().filter(({ type }) =>
    type === "redrawRequested" ||
    type === "windowEvent" ||
    type === "deviceEvent"
  );
  /**.filter((e, i, arr) =>
    e.type === "redrawRequested"
      ? !arr.slice(i + 1).find((e) => e.type === "redrawRequested")
      : true
  ); */
  let drawIndex = -1;
  for (let i = 0; i < events.length; i++) {
    if (events[i].type === 'redrawRequested') {
      drawIndex = i;
    }
  }

  for (let i = 0; i < events.length; i++) {
    const event = events[i];
    if (event.type === "windowEvent") {
      const windowEvent = event.value.event;
      if (windowEvent.type === "destroyed" ||
        windowEvent.type === "closeRequested") {
        return exit();
      }
      else if (windowEvent.type === "resized") {
        // width = windowEvent.value.width;
        // height = windowEvent.value.height;
        // frame = new Uint8Array(width * height * bytesPerPixel);
        // pane.resizeFrame(
        //   windowEvent.value.width,
        //   windowEvent.value.height,
        // );
      }
    } else if (event.type === "redrawRequested" && i === drawIndex) {
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
      break;
    } else if (event.type === "deviceEvent") {
      const deviceEvent = event.value.event;
      if (deviceEvent.type === "key") {
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
  // pane.drawFrame(frame);
  // pane.renderFrame();
  pane.requestRedraw();
  time += performance.now() - start;
  runs++;
};

loopInterval = setInterval(loop, 30);

loop();
