# Shädows

Shädows is a dynamic lighting and shadow library for LÖVE. It supports height-aware polygon and circle occluders, textured shadows, ambient-darkening rooms, and normal- and height-map effects.

Soft shadows use contact-hardening penumbras: edges stay sharp near the casting
shape and soften with distance from its silhouette. A minimum softness keeps
penumbras visible for positive source sizes even when the light is far from the
caster; larger sources can add more softness. The filter uses 90% of its
estimated radius for a slightly tighter transition, while 4x MSAA continues to
antialias diagonal silhouettes. Set `light.SizeRadius` (default `10`, in world
units) to control softness; `light.Blur = false` or
`light.SizeRadius = 0` preserves hard shadows.
The filter searches toward the light for a relevant blocker to avoid abrupt
softness changes where an unrelated nearby wall becomes the nearest silhouette,
including bright streaks along walls adjacent to a penumbra. It blends
candidate footprints and smooths the estimated blur radius to reduce bright
lines when the search crosses surfaces.
This applies to local lights and full-scene stars. See [Penumbras](docs/Penumbras.md)
for the filtering approximation, graphics requirements, and comparison demo.
Projected shadow render targets and occluder-mask canvases request 4x MSAA to smooth diagonal
edges, including when soft-shadow filtering is disabled.

## Color API migration

All light, star, ambient, and room color channels now use LÖVE's **0-1 range**.
This is a breaking change: divide legacy 0-255 arguments by 255 when updating
callers, including alpha (`255` becomes `1`). No legacy-range detection is
performed. For example, use `light:SetColor(1, 0.5, 0, 1)` for an orange light.
Radial lights apply RGB tint and opacity with premultiplied distance falloff.

## Source and setup

The editable library is in [`src/shadows`](src/shadows); its require name remains `shadows`. Add the source directory to LÖVE's require path before loading the library:

```lua
love.filesystem.setRequirePath(
    "src/?.lua;src/?/init.lua;" .. love.filesystem.getRequirePath()
)

local LightWorld = require("shadows.LightWorld")
local Light = require("shadows.Light")
local Body = require("shadows.Body")
local PolygonShadow = require("shadows.ShadowShapes.PolygonShadow")

local world
local light

function love.load()
    world = LightWorld:new()
    light = Light:new(world, 320)
    light:SetColor(1, 240 / 255, 200 / 255, 1)
    light:SetPosition(400, 300, 1.2)

    local body = Body:new(world)
    body:SetPosition(400, 300, 0.4)
    PolygonShadow:new(body, -32, -24, 32, -24, 32, 24, -32, 24)
end

function love.update(dt)
    world:Update(dt)
end

function love.draw()
    world:Draw()
end
```

The repository launcher and source demos configure the path for you. See the [API guide](docs/README.md) for all supported objects and methods.

## Demos

In VS Code, choose **Terminal > Run Task > Run LÖVE demo** and select a scene. Demos under `DEMOS/` load the shared library from `src/shadows`; they do not contain copies of the package.

The high-DPI regression scene can also be run from the repository root:

```powershell
love . HighDPI
love . HighDPI --capture
love . Penumbra --capture --verify
```

Capture mode renders the scene to offscreen canvases at DPI scale 2, saves a screenshot using `love.graphics.captureScreenshot`, and exits. Press `F12` to capture an image interactively; press `Escape` to close the demo.

The `Penumbra` demo compares hard and soft polygon/circle shadows side by side;
use `+` and `-` to adjust the source radius and the arrow keys to move the light.
`--verify` checks measured contact and distant transition widths, minimum softness
at different source sizes and light distances, brightness preservation,
hard-shadow behavior, and DPI scales 1 and 2. Capture failures print a traceback and exit with a
nonzero status instead of opening an interactive error screen.

In the `Standard` demo, press `F9` to save a matching screenshot and scene
settings (`standard-scene.png` and `standard-scene.txt`) for reproducing
lighting issues. See [Standard demonstration](docs/Standard-Demonstration.md)
for the save location and controls.

## Tests

Install Busted with LuaRocks, then run the unit tests from the repository root:

```powershell
luarocks install busted --local
busted
busted spec/DPI_spec.lua spec/PenumbraSettings_spec.lua
```

On Windows, LuaRocks may need the MSVC C++ build tools to compile Busted's `luasystem` dependency.

## Documentation

Start with the [API and usage guide](docs/README.md), which indexes the class references and demonstrations in `docs/`.

## Project links

- [Issues](https://github.com/matiasah/shadows/issues)
- [LÖVE forum thread](https://love2d.org/forums/viewtopic.php?f=5&p=200615)
