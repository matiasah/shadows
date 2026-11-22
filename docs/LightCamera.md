# LightCamera

`LightCamera` renders a viewport into one shared [`LightWorld`](LightWorld.md).
Each camera owns its position, zoom, composition canvas, and full-scene star
buffers. Bodies, rooms, ambient color, settings, and local-light caches remain
shared. Cameras are lighting views, not general-purpose scene renderers.

## Construction and lifecycle

```lua
local LightCamera = require("shadows.LightCamera")
local left = world:GetCamera()
left:Resize(400, 300)
local right = LightCamera:new(world, 400, 300)
right:SetPosition(600, 200, 0.5)

function love.update(dt)
    world:Update(dt) -- advances simulation once and refreshes all cameras
end
```

| Method | Description |
|---|---|
| `LightCamera:new(world, width?, height?)` | Registers a view; omitted dimensions match the world's default viewport. |
| `camera:SetPosition(x, y, scale?)` | Sets the world-space top-left and positive zoom. Omitted scale is retained. |
| `camera:GetPosition()` | Returns `x`, `y`, and scale. |
| `camera:GetTransform()` | Returns the hierarchical positioning `Transform` for local coordinates or parenting. |
| `camera:Resize(width, height)` | Recreates only this camera's composition and star buffers. Dimensions must be finite positive integers. |
| `camera:GetWidth()` / `camera:GetHeight()` | Return logical viewport dimensions. |
| `camera:GetBorderRadius()` | Returns half the logical viewport diagonal. |
| `camera:Draw(screenX?, screenY?)` | Multiplies lighting onto the already-drawn scene at a screen destination; defaults to `(0, 0)`. Preserves graphics state and does not advance simulation. |
| `camera:Remove()` | Detaches an additional camera and drops its star-cache references. The default camera cannot be removed. |

Position and zoom must be finite; zoom must be greater than zero.
`camera.Canvas` exposes the composed lighting texture, and `camera.Settings`
references the world's shared settings object. Quality changes affect all
registered views. Resize views explicitly after changing your window layout.

## Transform and parenting

`camera.Transform` (also available through `GetTransform()`) controls position.
`camera:SetPosition(x, y, scale?)` sets **world** coordinates, converting them
to parent-local coordinates when attached, and preserves the transform's height.
`GetPosition()` returns the current world-space position and the separate zoom.
Direct transform edits and parent movement are synchronized before light
culling and star rendering on the next `world:Update(dt)`.

```lua
local transform = camera:GetTransform()
transform:SetParent(body:GetTransform())
transform:SetLocalPosition(-200, -150) -- camera follows with a local offset
camera:SetPosition(600, 200, 0.5) -- alternatively set world position and zoom
```

Transform `z` is height, **not zoom**. Height does not affect the viewport;
zoom remains the scale argument to the camera's existing position API.
Views remain axis-aligned: camera rotation does not rotate the viewport.
A parent's rotation can still move a camera's local offset through the normal
transform hierarchy. Removing an additional camera detaches its transform.

## Drawing matching scene views

Render your scene using the **same** position and zoom as its lighting camera.
For a viewport starting at screen `(screenX, screenY)`:

```lua
local x, y, zoom = camera:GetPosition()
love.graphics.push("all")
love.graphics.setScissor(screenX, screenY, camera:GetWidth(), camera:GetHeight())
love.graphics.translate(screenX, screenY)
love.graphics.scale(zoom, zoom)
love.graphics.translate(-x, -y)
drawScene()
love.graphics.pop()
camera:Draw(screenX, screenY)
```

Camera positions are not automatically pixel-snapped. If your scene renderer
snaps its translation (as the Standard demo's tile renderer does), use the same
effective translation for its lighting camera.

Local lights stay cached while visible to **any** registered camera, with
culling accounting for zoom. Stars render once per view using separate shadow
and penumbra buffers; additional views therefore cost composition and star
rendering memory. Draw-only world callbacks may run for each star view. The
callback's star argument exposes `Camera` for view-specific rendering.

## Compatibility

Every world creates a default camera. `world:Resize`, `world:SetPosition`, and
`world:Draw` continue to operate on that camera; `world.Canvas` and the legacy
viewport fields mirror it. Additional cameras do not move or resize the default.
Use the viewport methods rather than directly assigning camera/world fields.

See the [split-screen demo](../DEMOS/LightCameras/main.lua) for two independently
positioned and zoomed views of the same lights and animated body. Press `F` to
toggle following the body with the selected camera's transform.
