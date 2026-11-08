# Standard demonstration

The standard demo combines a tile map, physics-imported occluders, several shadow-map types, and an interactive local light. It uses the library from `src/shadows`.

## Run

In VS Code, choose **Terminal > Run Task > Run LÖVE demo** and select **Standard**. The repository's `main.lua` launcher also supports:

```powershell
love . Standard
```

Run commands from the repository root with LÖVE installed.

## Controls

- **W/A/S/D** — move the camera.
- **Mouse wheel** — zoom in or out.
- **Left mouse button** — add a randomly colored local light at the current light position.
- **Other mouse buttons** — remove the first sample body.
- **F9** — save `standard-scene.png` and `standard-scene.txt` together in the
  LÖVE save directory without closing the demo. These files are overwritten by
  the next F9 snapshot. Share both files to reproduce lighting issues; the text
  records camera, mouse, light settings, window and canvas DPI, and whether the
  removable circle is present. The save path is also printed to the console.
- **F12** — save a screenshot through the shared capture helper and exit.
- **Escape** — close the demo.

## What it demonstrates

- Importing supported fixtures from a LÖVE physics world using `LightWorld:InitFromPhysics`.
- Circle, normal-map, height-map, and image shadow shapes.
- Updating the world camera and local light as the scene is navigated.
- Loading the sample tile map through the demo's bundled STI dependency.

The demo source is [`../DEMOS/Standard/main.lua`](../DEMOS/Standard/main.lua). Use the [High-DPI regression scene](../DEMOS/HighDPI/main.lua) to inspect rendering across logical and pixel canvas dimensions.

Run `love . Standard --verify` to check the snapshot capture and file round-trip;
it uses temporary snapshot names and exits automatically.
Run `love . Standard --shadow-verify` (and again with `--capture` for DPI 2) to
check penumbra continuity in the recorded wall-and-crate arrangement. It saves
`standard-shadow-verify.png` in the LÖVE save directory, replacing any previous
regression screenshot.
Run `love . Standard --stain-verify` (or add `--capture` for DPI 2) to check a
second recorded wall-and-floor corner. It saves `standard-stain-verify.png`,
replacing any previous screenshot by that name.
Run `love . Standard --line-verify` (or add `--capture` for DPI 2) to check a
zoomed crate penumbra for internal bright lines. It saves
`standard-line-verify.png`, replacing any previous screenshot by that name.
Run `love . Standard --wall-line-verify` (or add `--capture` for DPI 2) to
check the captured wall-edge penumbra. It saves `standard-wall-line-verify.png`,
replacing any previous screenshot by that name.
