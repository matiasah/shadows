# Standard demonstration

The standard demo combines a tile map, physics-imported occluders, a circle shadow, and an interactive local light. It uses the library from `src/shadows`.

## Run

In VS Code, choose **Terminal > Run Task > Run LÖVE demo** and select **Standard**. The repository's `main.lua` launcher also supports:

```powershell
love . Standard
```

Run commands from the repository root with LÖVE installed.

## Controls

- **W/A/S/D** — move the camera.
  Map and lighting use the same pixel-aligned camera translation, preventing
  subpixel gaps between drawn walls and their shadows.
- **Mouse wheel** — zoom in or out.
- **Q** — cycle the shared world rendering quality through high, medium, and low.
- **Left mouse button** — add a randomly colored local light at the current light position.
- **Other mouse buttons** — remove the first sample body.
- **Snapshot scene [F9]** button or **F9** — save `standard-scene.png` and
  `standard-scene.txt` together in the LÖVE save directory without closing the
  demo. On Windows this is `%APPDATA%\LOVE\shadows`; the full path is printed to
  the console. The next snapshot overwrites both files. Share both to reproduce
  lighting issues; the text records camera, mouse, light settings, rendering
  quality, window and canvas DPI, and whether the removable circle is present.
  The light stops following the mouse while the pointer is over the button, so
  clicking it does not move the light or add another one.
  Snapshot colors use normalized 0–1 channels with full numeric precision.
- **F12** — save a screenshot through the shared capture helper and exit.
- **Escape** — close the demo.

## What it demonstrates

- Importing supported fixtures from a LÖVE physics world using `LightWorld:InitFromPhysics`.
- Circle shadows and physics-imported occluders.
- Updating the world camera and local light as the scene is navigated.
- Loading the sample tile map through the demo's bundled STI dependency.

The demo source is [`../DEMOS/Standard/main.lua`](../DEMOS/Standard/main.lua). Use the [High-DPI regression scene](../DEMOS/HighDPI/main.lua) to inspect rendering across logical and pixel canvas dimensions.

Run `lovec . Standard --verify` to check the button, F9, and the snapshot file round-trip;
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
Run `lovec . Standard --contact-verify` to check the captured square wall's
shadow contact and caster brightness at DPI scales 1 and 2, plus map/shadow
camera alignment in the composed scene. It saves `standard-contact-verify.png`
in the LÖVE save directory.
