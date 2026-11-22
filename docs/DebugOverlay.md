# DebugOverlay

`DebugOverlay` draws diagnostics over an already-lit scene without regenerating
shadows or allocating light/star buffers.

```lua
local DebugOverlay = require("shadows.DebugOverlay")
local debug = DebugOverlay:new(world)

function love.draw()
    drawScene()
    world:Draw()
    debug:Draw() -- default camera, destination (0, 0)
end
```

For another viewport, call `debug:Draw(camera, screenX, screenY)` after drawing
the matching scene and `camera:Draw(screenX, screenY)`. The camera must belong
to the overlay's world and still be attached. Drawing preserves graphics
state and intersects the viewport with the caller's scissor rectangle.
Use it on your scene render target, not on a library lighting cache.

## Categories

All four boolean fields default to `true`; change them independently:

| Field | Overlay |
|---|---|
| `LightBounds` | Orange/magenta source markers, radius bounds, headings, identifiers, and local-light cone edges. Includes particle lights and stars. |
| `ShadowGeometry` | Green occluder outlines and red wireframes of cached projected shadow draw calls. |
| `CameraViewports` | Cyan world-space bounds and identifiers for all registered cameras, accounting for their zoom. |
| `CacheCounters` | Completed per-frame camera CPU/work/allocation metrics, a separate shared-local-light section, and current cache counts. |

```lua
debug.ShadowGeometry = false
debug.CacheCounters = true
```

Polygon and circle projections use the existing cached geometry rather than
recomputing an approximation. These wireframes represent all cached draw calls,
not the final composited visibility or per-layer shader filtering.
Textured occluders and texture draw calls show
transformed rectangle bounds, **not** alpha contours or shader-generated
per-pixel visibility. Upright image casters show their projected sprite bounds;
their shader-based ground shadows show the cached draw rectangle. Custom
world callbacks have no cached wireframe unless represented by registered
shape draw calls. Supported cached operations are `polygon`, `circle`,
`rectangle`, and texture `draw`; unsupported operations raise an explicit error.
Occluders without a built-in outline use their bounding circle.

## Per-frame performance

`debug:GetFrameStats(camera?)` returns `{ Camera = ..., Shared = ... }`.
The overlay displays these metrics by default. `Camera` is specific to the
selected view; `Shared` is one world-level bucket for local lights, including
particle lights. Do **not** add the shared bucket once for every camera.

Both records expose:

| Field | Meaning |
|---|---|
| `Frame` | Completed `world:Update` sequence number; initially `0` before the first update. |
| `ShadowRedraws` | Shadow canvases redrawn during this update. |
| `GeometryRebuilds` | Shape/layer geometry generations during this update, including empty results. |
| `ShadowDrawCalls` | Cached deferred shadow draws executed during this update, respecting their layer filters. |
| `CanvasAllocations` | Successful lighting-canvas allocations since the previous completed update. |

`Camera` additionally exposes `StarUpdateMs`, `CompositionMs`, and
`LightsComposited`. Star timing includes that view's cache checks, allocation,
shadow/penumbra rendering, and illumination updates. Composition timing covers
combining star/local-light canvases and rooms into the view's lighting canvas.
`LightsComposited` counts actual light-canvas draw submissions, including
offscreen caches retained for another camera; it is not a visible-light count.

`Shared.SharedUpdateMs` measures local-light updates, including particle
simulation when `dt` is provided. It excludes body/physics synchronization,
room updates, and all camera/star work.

Timings are **CPU elapsed milliseconds**, not GPU timings. They include graphics
submission and possible driver waits but do not force a GPU synchronization.
Scene drawing, `camera:Draw`, debug drawing, and statistics sampling are not
timed. No scene-wide draw-call count is inferred from LÖVE's global statistics.

Camera allocations include its composition canvas and its star buffers;
shared allocations include local-light buffers. Both include penumbra masks
and distance/radius canvases. Resize/quality allocations made between updates
are charged to the **next** completed update. Unrelated scene textures, meshes,
sprite-shading buffers, and application canvases are excluded.

Snapshots are published only when a world update completes. Queries and
repeated drawing do not reset or accumulate them; retained snapshots remain
stable across later updates. Treat the returned records as read-only.
They are also available as `camera.FrameMetrics` and `world.FrameMetrics`.

Stationary frames show zero redraws, geometry/draw work, allocations, and
composition submissions when the cached view is reused. Star CPU time can
remain nonzero for cache checks. Tint-only updates can recompose illumination
without rebuilding shadows. A change in another view may also trigger
composition of this view under the world's existing shared dirty flag; metrics
report the actual work performed rather than hiding it.

## Lifetime counters and cache sizes

`debug:GetStats(camera?)` returns:

| Field | Meaning |
|---|---|
| `LocalLights` | Registered local lights, including particle lights. |
| `LocalCanvases` | Shared local lights whose canvases currently exist. |
| `Stars` | Registered stars. |
| `ShadowRedraws` | Completed shadow-canvas redraws across local lights and this camera's existing star renderers. |
| `GeometryRebuilds` | Completed shape/layer geometry generations across those renderers, including empty results. |
| `CachedDrawCalls` | Currently cached deferred shadow draw calls across those renderers. |

Work counters are **cumulative**, not frame counts or timings. Stationary and
tint-only updates leave them unchanged. Geometry edits, forced updates, and
cache recreation increase them when actual work completes. Local counters are
shared across cameras; star counters are view-specific. Removed renderers no
longer contribute, so aggregate totals can decrease after removal.
Querying statistics does not create missing star views.

`light:GetDebugCounts()` returns the renderer's lifetime shadow-redraw and
geometry-rebuild counts. Stars inherit it; calling it on a source star reports
the default camera's renderer.

Lifetime redraw/rebuild totals are secondary and hidden in the panel by default.
Set `debug.CumulativeTotals = true` to append them without replacing frame
metrics. `debug:GetStats(camera?)` retains its existing cumulative semantics.

## Demo

```powershell
love . DebugOverlay
love . DebugOverlay --capture --verify
```

The main view and overview show three geometric casters, a local spotlight,
a point light, and a star. Keys `1`-`4` toggle individual categories; `D` hides
all overlays, `T` appends/hides lifetime totals, `Space` pauses caster motion,
`C` changes tint without rebuilding shadows, `B` switches hard/soft shadows,
`R` forces a rebuild, and arrows pan
the main camera. `F12` captures and `Escape` exits. The demo is also available
as **Love: DebugOverlay** in VS Code's launch configurations.

Verification checks camera-specific work, stationary zeros, stable completed
snapshots, shared ownership, visible camera wireframes, non-mutating debug
drawing, and category/totals controls. Capture mode forces one rebuild so the
saved frame shows actual per-view work.
