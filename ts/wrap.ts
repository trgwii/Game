import { readLines } from "https://deno.land/std@0.97.0/io/bufio.ts";

const proc = Deno.run({
  env: {
    // PLUGIN_URL: "pane.dll",
  },
  cmd: ["deno", "run", "-A", "--unstable", "pane.ts"],
  stderr: "piped",
});
for await (const line of readLines(proc.stderr)) {
  console.error(line);
  if (line === "exit") {
    proc.kill(Deno.Signal.SIGKILL);
  }
}
