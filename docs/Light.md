# Light and Star

`Light` renders a localized light with radius-sized canvases shared by all
registered cameras. `Star` is a full-scene light with separate buffers for each
[`LightCamera`](LightCamera.md). Both types cast shadows from registered bodies
and support custom shadow/sprite callbacks through [`LightWorld`](LightWorld.md).

For dynamic illumination drawn by a native LÖVE particle system, use
[`ParticleLight`](ParticleLight.md), a local-light subclass that inherits
position, tint, radius, and shadow settings.

## Import and construction

```lua
local Light = require("shadows.Light")
local Star = require("shadows.Star")
local LightWorld = require("shadows.LightWorld")

local world = LightWorld:new()
local light = Light:new(world, 300)
local star = Star:new(world, 5000)
```

Constructors register their result with the world and return `nil` if required arguments are omitted. `Star` cannot illuminate rooms.

## Light methods

| Method | Description and return values |
|---|---|
| `light:SetPosition(x, y, z?)` | Sets world position and optional height; returns the light. |
| `light:GetPosition()` | Returns world `x`, `y`, and `z`. |
| `light:SetAngle(angle)` / `light:GetAngle()` | Sets or returns rotation in degrees; setter returns the light. |
| `light:SetColor(r, g, b, a?)` | Sets RGBA channels in the 0–1 range. Omitted alpha keeps the current value; returns the light. |
| `light:GetColor()` | Returns `r`, `g`, `b`, and `a`. |
| `light:SetRadius(radius)` / `light:GetRadius()` | Sets or returns the radius in world units. Setting a radius invalidates the cached light. |
| `light:SetImage(texture)` / `light:GetImage()` | Sets or returns a custom light texture. Setting one derives the radius from its dimensions. |
| `light:SetCookie(texture?)` / `light:GetCookie()` | Sets, clears, or returns a 2D illumination mask without changing radius; setter returns the light. |
| `light:SetCookieTransform(x?, y?, angle?, scaleX?, scaleY?)` | Sets light-local offsets, relative rotation, and positive scale multipliers; returns the light. Defaults: `0, 0, 0, 1, scaleX`. |
| `light:GetCookieTransform()` | Returns `x, y, angle, scaleX, scaleY`. |
| `light:GetWorld()` / `light:SetWorld(world)` | Gets or sets the owning world. `SetWorld` is used by world registration. |
| `light:GetTransform()` | Returns the light's [`Transform`](Transform.md). |
| `light:GetDebugCounts()` | Returns cumulative completed shadow redraws and shape/layer geometry rebuilds for this renderer. |
| `light:Remove()` | Removes the light from its world and detaches its transform. |

`Blur`, `SizeRadius`, and `Arc` are public fields rather than methods.
`Blur` enables contact-hardening penumbras by default. `SizeRadius` is the
effective source radius in world units (default `10`); larger values can soften
distant shadows more. Positive sizes retain a minimum penumbra even for distant
lights. Set `light.Blur = false` or `light.SizeRadius = 0` for
hard shadows. Direct changes to either penumbra setting invalidate cached
rendering on the next update. `SizeRadius` must be finite and nonnegative.
`Arc` controls angular coverage in degrees. Color channels use LÖVE's 0–1 range,
with opaque white (`1, 1, 1, 1`) as the default. Divide legacy 0–255 inputs by
255 before calling `SetColor`; the library no longer converts them.
Radial lights apply the RGB tint and alpha with distance falloff using premultiplied output.
See [Penumbras](Penumbras.md) for examples and approximation limits.

## Light cookies

Cookies multiply existing illumination rather than replacing it. Use them for
window panes, patterned cones/gobos, or colored moving projections:

```lua
light:SetCookie(love.graphics.newImage("window-mask.png"))
light:SetCookieTransform(12, -8, 20, 0.8, 1.2)
light:SetCookie(nil) -- restore unmasked illumination
```

An opaque white texel leaves illumination unchanged; RGB modulates color and
alpha attenuates intensity once. Transparent or black texels block light.
Cookies preserve the existing falloff, cone, tint, and hard/soft shadows.
The texture is centered on the light and fitted, preserving aspect ratio, so
its longest side spans the light diameter. Scale multipliers stretch that
footprint; offsets are in world units along the light's rotated local axes,
and the cookie angle is relative to the light's world rotation.
Outside the transformed texture footprint, illumination is black even if the
texture uses repeat wrapping. Cookies do not enlarge a local light's canvas or
shadow influence radius.

Use the setters to change cookie appearance; these changes recompose lighting
without regenerating shadow geometry or allocating additional canvases.
The optional texture must be a two-dimensional LÖVE texture; Canvas cookies
use the premultiplied RGB produced by normal LÖVE rendering, while Image cookies
use straight RGB and alpha. A light's own illumination canvas cannot be its
cookie because that would read from the active render target.
The texture's filtering is retained. Editing texture
pixels in place requires `world:ForceUpdate()`, as with legacy light images.

`Star` shares cookies and their transforms across its independent camera views,
accounting for each camera's position and zoom. `ParticleLight` inherits cookie
masking for its particle illumination. Legacy `SetImage` remains unchanged:
it replaces procedural illumination and derives the radius, whereas `SetCookie`
only masks whichever illumination renderer is already active.

Run the [LightCookies demo](../DEMOS/LightCookies/main.lua) with
`love . LightCookies --capture --verify` for window, cone/gobo, and ripple masks.

## Star methods

`Star` inherits the `Light` methods and overrides its canvas behavior. Its additional method is:

| Method | Description |
|---|---|
| `star:Resize(width, height)` | Recreates the default view's full-scene buffers when dimensions differ. Prefer `camera:Resize` to keep the viewport and its star buffers aligned. |

Stars' public `Canvas`, `Width`, and `Height` fields describe their default
camera buffers. Their position, radius, color, texture, and blur settings follow
the `Light` API and are shared across views. During a world rendering callback,
the star argument's `Camera` identifies the view being rendered.
Textured stars draw their image at the star's world position, translated and
scaled by each camera, rather than at a fixed viewport offset.

## Rendering notes

- Local-light canvas dimensions are twice the radius. Soft shadows additionally use an occluder mask, two floating-point distance-field buffers, a floating-point radius buffer, and shadow-mask mipmaps.
- Star canvas dimensions follow their camera and are independent of radius. Camera movement and resizing do not rebuild other views' shadow caches.
- Local lights retain their shared canvases while their influence intersects any registered camera; zoomed viewports are culled in world coordinates.
- Rendering resolution, shadow-edge MSAA, and penumbra-buffer resolution are controlled per world with `LightWorld:SetQuality`; changing settings reallocates the relevant caches.
- Projected shadow geometry is cached per shape and height layer, including empty shadow lists. Editing a shape preserves unchanged siblings' geometry; moving its body invalidates all its shapes.
- Local shadow canvases rebuild only for shapes intersecting the light's range at their previous or current bounds. Movement, radius changes, removal, and texture replacement are tracked on the next world update. Stars conservatively redraw for any scene geometry change.
- Affected shadow canvases are cleared and fully redrawn, rather than painting only changed shapes, so overlaps and height layers remain correct.
- Color, direct `Arc` changes, and light rotation only recompose illumination. Source-size changes update the penumbra radius field without rebuilding shadow pixels or occluder-distance fields. Disabling filtering releases its buffers; enabling it rebuilds them.
- Light position and radius changes rebuild shadow geometry. Radius changes also recreate local-light canvases at the new size. Star camera changes rebuild view-dependent geometry and rendering.
- `LightWorld:DrawShadows(lightOrStar)` and `LightWorld:DrawSprites(lightOrStar)` run during shadow-buffer rebuilds, not appearance-only recomposition. Call `world:ForceUpdate()` if their output depends on changed light appearance or external state, or if texture pixels are edited in place.
- When penumbras are enabled, `DrawSprites` is also invoked for the occluder mask. Keep this callback limited to drawing; do not update simulation state inside it.

### Projected shadow culling

Before submitting each cached `OutputShadow`, the renderer tests its projected
draw bounds against the actual shadow target. This applies to shared local-light
canvases and each camera's separate star buffers. Filled polygons (flat or nested
coordinate arrays), circles, rectangles, and ordinary 2D texture draws are
supported, including texture rotation, negative/nonuniform scale, origin, and shear.
The active world-to-canvas transform and a two-physical-pixel raster margin
account for camera position, zoom, DPI, and antialiasing.

This skips only draw submissions; geometry generation, cache contents, height
layer selection, caster restoration, custom world callbacks, and penumbra masks
are unchanged. A caster outside the viewport can still project a visible shadow.
Off-target draws that were already clipped by the GPU cannot contribute to the
shadow pixels or subsequent filtering.

Unknown operations, stroke modes, Quad/Transform draw overloads, and custom
shaders with untrusted vertex bounds are retained rather than guessed.
Built-in height/normal-map shaders and upright-image ground projections are
eligible for culling. Custom fragment-only shaders can opt in with
`output:SetShader(shader, true)`; do not opt in if vertices can move outside
the ordinary draw bounds. The existing one-argument setter remains conservative
for custom shaders.

`output:GetBounds()` returns world-space `minX, minY, maxX, maxY`, or nil when
safe bounds are unavailable. `output:IsVisible(canvas)` tests those bounds under
the current graphics transform. Bounds are read from the current packed arguments
so direct argument edits cannot leave stale cached bounds.
Per-frame `ShadowDrawCalls` counts only submitted, layer-matching outputs;
debug wireframes and `CachedDrawCalls` still represent every cached output.

See the [standard demonstration](Standard-Demonstration.md) for a complete interactive scene.

Use [DebugOverlay](DebugOverlay.md) to inspect light bounds, existing shadow
geometry, viewports, and cache work without changing lighting caches. Source
star counters describe the default view; overlay statistics select the
requested camera's existing star renderers.
