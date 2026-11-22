# LightWorld

`LightWorld` owns the objects that participate in a scene and composites their lights, rooms, and shadows into a canvas. Create it from a LÖVE callback after graphics initialization.

## Import and construction

```lua
local LightWorld = require("shadows.LightWorld")
local world = LightWorld:new()
```

The default [`LightCamera`](LightCamera.md) and its initial canvas match
`love.graphics.getDimensions()`. `world:GetCamera()` returns this viewport.
Register additional cameras to display different locations of the same scene.

## Scene lifecycle

| Method | Description and return values |
|---|---|
| `world:Update(dt?)` | Updates shared scene objects once and refreshes all registered cameras. Call once per frame from `love.update`, not once per camera. When supplied, `dt` advances particle-light emitters in seconds; omit it for external particle simulation. |
| `world:Draw()` | Draws the composed canvas at the origin. Call from `love.draw`. |
| `world:Resize(width, height)` | Resizes the default camera and its star buffers. Additional cameras are unchanged; resize them explicitly for your layout. |
| `world:ForceUpdate()` | Forces every light and star to rebuild shadow geometry and rendering on its next visible update. |
| `world:InitFromPhysics(physicsWorld)` | Imports supported bodies and fixtures from a LÖVE physics world once. |

## Rendering quality

Each world owns one `Settings` object, shared by its lights and stars. Access it
with `world.Settings` or `world:GetSettings()`, then use
`settings:SetQuality(preset, overrides?)` to select a rendering preset and
optional per-world overrides. `world:SetQuality(...)` remains a shorthand for
the same shared object. The default is `high`, which preserves full canvas
resolution, 4x shadow-edge MSAA, and full-resolution penumbra buffers.

| Preset | Shadow scale | Shadow MSAA | Penumbra scale |
|---|---:|---:|---:|
| `low` | 0.5 | 0 | 0.5 |
| `medium` | 0.75 | 2 | 0.75 |
| `high` | 1 | 4 | 1 |

Scales are fractions of the normal canvas resolution. For example, a shadow
scale of `0.5` uses half the pixel width and height. MSAA must be a
nonnegative integer; the graphics device must support the requested sample
count.

```lua
world.Settings:SetQuality("medium")
world:GetSettings():SetQuality("high", {
    ShadowScale = 0.8,
    ShadowMSAA = 2,
    PenumbraScale = 0.5,
})
```

Changing the effective settings recreates affected canvases and cached shadow
buffers. Local lights rebuild lazily when next visible; stars rebuild on the
next update. Invalid presets or overrides raise an error. Values are per-world,
so different worlds can use different quality settings. `light.Settings` and
`star.Settings` reference the exact same object as their owning world's
`Settings`; changes made through it affect all lights and stars in that world.
Use `settings:GetQuality()` to retrieve the preset name and effective settings.

## Scene objects

| Method | Description and return values |
|---|---|
| `world:AddBody(body)` | Registers a body. Normally called by `Body:new(world)`. |
| `world:AddLight(light)` | Registers a local light and returns it. Normally called by `Light:new(world, radius)`. |
| `world:AddStar(star)` | Registers a star and returns it. Normally called by `Star:new(world, radius)`. |
| `world:AddRoom(room)` | Registers a room and returns it. Normally called by a room constructor. |
| `world:TrackBody(physicsBody)` | Creates and returns a [`BodyTransform`](BodyTransform.md) that follows a LÖVE physics body. |

[`ParticleLight`](ParticleLight.md) also registers as a local light. Its emitter
advances even while offscreen; animation recomposes illumination without
invalidating stationary shadow geometry.

## Camera and ambient color

| Method | Description and return values |
|---|---|
| `world:GetCamera()` | Returns the default `LightCamera` backing the world viewport API. |
| `world:SetPosition(x, y, scale?)` | Sets the default camera position and positive scale. The scale defaults to its current value. |
| `world:GetPosition()` | Returns camera `x`, `y`, and scale. |
| `world:SetColor(r, g, b, a)` | Sets ambient RGBA channels in the 0–1 range; defaults to opaque black (`0, 0, 0, 1`). |
| `world:GetColor()` | Returns the channels in the current implementation's order: `r, g, a, b`. |
| `world:GetWidth()` / `world:GetHeight()` | Return the default camera's canvas dimensions. |
| `world:GetBorderRadius()` | Returns half the canvas diagonal. |

## Extension callbacks

Override these methods on a world instance to draw custom content per light or star:

```lua
function world:DrawShadows(lightOrStar)
    -- Draw custom occluders while the shadow canvas is active.
end

function world:DrawSprites(lightOrStar)
    -- Draw custom foreground sprites over the shadow geometry.
end
```

Both callbacks run during light updates while an offscreen canvas is active. The argument may be a `Light` or a `Star`; follow LÖVE's graphics-state conventions and avoid changing the active canvas without restoring it.

With [penumbras](Penumbras.md) enabled, `DrawSprites` also runs while building
the occluder silhouette mask. Keep these callbacks drawing-only, without
simulation side effects. Custom shadow geometry needs a corresponding body or
sprite silhouette for contact-aware filtering.

The world tracks each shape's previous and current centroid, bounding radius,
height, rotation, and geometry-dirty flag. Only intersecting local lights are
invalidated; stars conservatively redraw for all scene geometry changes.
Tracked parent transforms are synchronized before bodies and lights so changes
take effect in the same frame.

Callbacks are skipped when only light color, arc, rotation, or source size
changes. Call `world:ForceUpdate()` when callback output changes independently
of registered shapes, depends on those light settings, or uses textures edited
in place. Replacing a shape texture through `SetTexture` is tracked automatically.

## Example

```lua
function love.update(dt)
    world:Update(dt)
end

function love.draw()
    world:Draw()
end
```

See [Light](Light.md) for light configuration and the [API guide](README.md) for other scene objects.
