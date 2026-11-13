# LightWorld

`LightWorld` owns the objects that participate in a scene and composites their lights, rooms, and shadows into a canvas. Create it from a LÖVE callback after graphics initialization.

## Import and construction

```lua
local LightWorld = require("shadows.LightWorld")
local world = LightWorld:new()
```

The initial canvas matches `love.graphics.getDimensions()`.

## Scene lifecycle

| Method | Description and return values |
|---|---|
| `world:Update(dt?)` | Updates bodies, tracked physics transforms, lights, stars, rooms, and the composed canvas. Call from `love.update`. `dt` is currently unused. |
| `world:Draw()` | Draws the composed canvas at the origin. Call from `love.draw`. |
| `world:Resize(width, height)` | Recreates the world canvas and resizes registered stars. Call after resizing the LÖVE window. |
| `world:ForceUpdate()` | Forces every light and star to rebuild shadow geometry and rendering on its next visible update. |
| `world:InitFromPhysics(physicsWorld)` | Imports supported bodies and fixtures from a LÖVE physics world once. |

## Scene objects

| Method | Description and return values |
|---|---|
| `world:AddBody(body)` | Registers a body. Normally called by `Body:new(world)`. |
| `world:AddLight(light)` | Registers a local light and returns it. Normally called by `Light:new(world, radius)`. |
| `world:AddStar(star)` | Registers a star and returns it. Normally called by `Star:new(world, radius)`. |
| `world:AddRoom(room)` | Registers a room and returns it. Normally called by a room constructor. |
| `world:TrackBody(physicsBody)` | Creates and returns a [`BodyTransform`](BodyTransform.md) that follows a LÖVE physics body. |

## Camera and ambient color

| Method | Description and return values |
|---|---|
| `world:SetPosition(x, y, scale?)` | Sets the camera position and scale. The scale defaults to its current value. |
| `world:GetPosition()` | Returns camera `x`, `y`, and scale. |
| `world:SetColor(r, g, b, a)` | Sets ambient RGBA channels in the 0–1 range; defaults to opaque black (`0, 0, 0, 1`). |
| `world:GetColor()` | Returns the channels in the current implementation's order: `r, g, a, b`. |
| `world:GetWidth()` / `world:GetHeight()` | Return the world canvas dimensions. |
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
