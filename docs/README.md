# Shädows API guide

Shädows is a LÖVE library for compositing lights, projected shadows, ambient-darkening rooms, and height-aware scene objects. The library source lives in [`../src/shadows`](../src/shadows); add `src` to LÖVE's require path as shown in the [project README](../README.md) before importing modules.

## Quick start

```lua
local LightWorld = require("shadows.LightWorld")
local Light = require("shadows.Light")
local Body = require("shadows.Body")
local CircleShadow = require("shadows.ShadowShapes.CircleShadow")

local world = LightWorld:new()
local light = Light:new(world, 300)
light:SetPosition(400, 300, 1)

local body = Body:new(world)
body:SetPosition(400, 300, 0.4)
CircleShadow:new(body, 0, 0, 24)

function love.update(dt)
    world:Update(dt)
end

function love.draw()
    world:Draw()
end
```

Coordinates and dimensions are in LÖVE's logical pixel units. Rotations use degrees unless a method explicitly says radians. Light, room, and ambient color channels use LÖVE's 0–1 range. This breaks legacy 0–255 callers: divide their channel values by 255, including alpha. Call `LightWorld:Update` during the update callback and `LightWorld:Draw` during drawing.

## API reference

| API | Description |
|---|---|
| [LightWorld](LightWorld.md) | Scene lifecycle, camera, ambient color, and extension callbacks. |
| [Light](Light.md) | Local lights and full-scene stars. |
| [Penumbras](Penumbras.md) | Contact-hardening shadow filtering, source size, and rendering limits. |
| [Body](Body.md) | Height-aware groups of shadow shapes and physics integration. |
| [Shadow shapes](Shadow.md) | Circle and polygon occluders, plus shared shape behavior. |
| [ImageShadow](ImageShadow.md) | Texture-based shadow occluders. |
| [NormalShadow](NormalShadow.md) | Normal-map lighting and shadow occluders. |
| [HeightShadow](HeightShadow.md) | Height-map shadow occluders. |
| [Rooms](Room.md) | Circle, rectangle, and polygon ambient-darkening regions. |
| [Transform](Transform.md) | Hierarchical position, height, and rotation transforms. |
| [BodyTransform](BodyTransform.md) | A transform synchronized with a LÖVE physics body. |

## Examples

- [Standard interactive demonstration](Standard-Demonstration.md)
- [High-DPI regression scene](../DEMOS/HighDPI/main.lua)
- [Hard-shadow and penumbra comparison](../DEMOS/Penumbra/main.lua)

## Notes

- `LightWorld` allocates its main canvas using the current graphics dimensions. Call `Resize(width, height)` after a window-size change.
- A `Light` allocates per-light canvases based on its radius. `Star` uses full-scene canvases instead and cannot illuminate rooms.
- Physics fixture import supports circle and polygon fixtures. For ongoing physics synchronization, use `Body:TrackPhysics` or `LightWorld:TrackBody`.
- The package uses LÖVE graphics canvases and shaders and must be created after the graphics context is available.
