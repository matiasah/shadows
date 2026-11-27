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
| `camera:SetLightMask(mask)` / `camera:GetLightMask()` | Sets or returns selected unsigned 32-bit light groups (default `Mask.ALL`); setter returns the camera. Zero selects no lights. |
| `camera:AcceptsLight(light)` | Returns whether camera selection overlaps the light's membership, independently of bounds. |
| `camera:GetTransform()` | Returns the hierarchical positioning `Transform` for local coordinates or parenting. |
| `camera:Resize(width, height)` | Recreates only this camera's composition and star buffers. Dimensions must be finite positive integers. |
| `camera:GetWidth()` / `camera:GetHeight()` | Return logical viewport dimensions. |
| `camera:GetBorderRadius()` | Returns half the logical viewport diagonal. |
| `camera:IsVisible(x, y, radius)` | Tests a world-space circle against the viewport, accounting for zoom. |
| `camera:IsLightVisible(light)` | Tests group selection and conservatively tests a local light's existing or prospective square canvas bounds against the viewport, accounting for zoom. |
| `camera:Draw(screenX?, screenY?)` | Multiplies lighting onto the already-drawn scene at a screen destination; defaults to `(0, 0)`. Preserves graphics state and does not advance simulation. |
| `camera:DrawReceiverLayer(mask, receiverCanvas, screenX?, screenY?)` | Lights an unlit receiver canvas and alpha-composites it onto the current target. Lights must match both the receiver mask and camera selection. |
| `camera:ReleaseReceiverMask(mask)` | Releases the cached lighting pass for a receiver mask; returns the camera. |
| `camera:Remove()` | Detaches an additional camera and drops its star-cache references. The default camera cannot be removed. |

Position and zoom must be finite; zoom must be greater than zero.
`camera.Canvas` exposes the composed lighting texture, and `camera.Settings`
references the world's shared settings object. Quality changes affect all
registered views. Resize views explicitly after changing your window layout.

`camera.FrameMetrics` exposes the last completed world update's camera-specific
star/composition CPU milliseconds, shadow redraws, geometry/draw work,
light composition submissions, and canvas allocations, including requested
receiver passes. Metrics are read-only
and initially zero; queries and drawing do not reset them. Shared local-light
work is separate in `world.FrameMetrics`. See [DebugOverlay](DebugOverlay.md)
for field definitions and allocation/timing scope.

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

Local lights stay cached while selected and visible to **any** registered camera, with
culling accounting for zoom and the full square canvas, including texture and
particle corners. Each composition submits only intersecting local-light
canvases. Light appearance, movement, cache release, and removal refresh cameras
containing the light's previous composition or current bounds, so moving a light
away also clears its old contribution. Camera movement or resizing refreshes
only that camera's composition and star buffers. Ambient/room changes and shared
quality settings still invalidate all views. Offscreen casters are not discarded
merely because they lie outside a camera; their projected shadows may remain visible.
Selected stars render once per view using separate shadow
and penumbra buffers; additional selected views therefore cost composition and star
rendering memory. Draw-only world callbacks may run for each star view. The
callback's star argument exposes `Camera` for view-specific rendering.

## Light selection

```lua
local Mask = require("shadows.Mask")
local effects = Mask.group(31)
light:SetLightMask(effects)
camera:SetLightMask(effects)
camera:SetLightMask(0) -- ambient color and rooms only
camera:SetLightMask(Mask.ALL) -- default: every light group
```

Changing selection dirties only this camera's composition. Existing shadow
buffers can be reused; unselected additional star buffers are created lazily
when first needed. Existing excluded views retain changes for later selection.
Metrics never allocate missing star views, and excluded views submit no lights
or shadows. Particles still simulate even when no camera selects them.
Camera light selection alone does not filter scene objects or rooms; use
receiver passes for surface-specific lighting. See
[Light and occluder groups](Light.md#light-and-occluder-groups) for unsigned
masks, separate caster selection, inheritance, and defaults.

## Receiver layers

`DrawReceiverLayer(mask, receiverCanvas)` composites ambient color, rooms, and only the
lights whose membership overlaps both `mask` and the camera's `LightMask`.
This lets an application render separately classified receiver layers while
leaving scene-object drawing under application control:

```lua
local Mask = require("shadows.Mask")
local walls = Mask.group(0)
local actors = Mask.group(1)
local wallCanvas = love.graphics.newCanvas(camera:GetWidth(), camera:GetHeight())
local actorCanvas = love.graphics.newCanvas(camera:GetWidth(), camera:GetHeight())

-- Render each receiver layer separately to a transparent Canvas.
love.graphics.setCanvas(wallCanvas)
love.graphics.clear(0, 0, 0, 0)
drawWalls()
love.graphics.setCanvas()

love.graphics.setCanvas(actorCanvas)
love.graphics.clear(0, 0, 0, 0)
drawActors()
love.graphics.setCanvas()
camera:DrawReceiverLayer(walls, wallCanvas)
camera:DrawReceiverLayer(actors, actorCanvas)
```

Each receiver layer needs its own transparent canvas matching the camera's
viewport. `DrawReceiverLayer` preserves the receiver alpha and composites the
lit layer onto the current target, which must differ from the receiver canvas.
Ambient color and rooms are included in every pass. The ordinary `camera:Draw`
and `world:Draw` behavior remains unchanged. Receiver lighting passes are
cached by mask; call `camera:ReleaseReceiverMask(mask)` when a pass is no
longer needed.

## Compatibility

Every world creates a default camera. `world:Resize`, `world:SetPosition`, and
`world:Draw` continue to operate on that camera; `world.Canvas` and the legacy
viewport fields mirror it. Additional cameras do not move or resize the default.
Use the viewport methods rather than directly assigning camera/world fields.

See the [split-screen demo](../DEMOS/LightCameras/main.lua) for two independently
positioned and zoomed views of the same lights and animated body. Press `F` to
toggle following the body with the selected camera's transform.
