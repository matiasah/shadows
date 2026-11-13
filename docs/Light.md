# Light and Star

`Light` renders a localized light with radius-sized canvases. `Star` is a full-scene light whose canvases match the world view. Both types cast shadows from registered bodies and support custom shadow/sprite callbacks through [`LightWorld`](LightWorld.md).

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
| `light:GetWorld()` / `light:SetWorld(world)` | Gets or sets the owning world. `SetWorld` is used by world registration. |
| `light:GetTransform()` | Returns the light's [`Transform`](Transform.md). |
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

## Star methods

`Star` inherits the `Light` methods and overrides its canvas behavior. Its additional method is:

| Method | Description |
|---|---|
| `star:Resize(width, height)` | Recreates the full-scene canvases when the requested dimensions differ. `LightWorld:Resize` calls this for registered stars. |

Stars have public `Width` and `Height` fields. Their position, radius, color, texture, and blur settings follow the `Light` API.

## Rendering notes

- Local-light canvas dimensions are twice the radius. Soft shadows additionally use an occluder mask, two floating-point distance-field buffers, a floating-point radius buffer, and shadow-mask mipmaps.
- Star canvas dimensions follow the world canvas and are independent of radius.
- Projected shadow geometry is cached per shape and height layer, including empty shadow lists. Editing a shape preserves unchanged siblings' geometry; moving its body invalidates all its shapes.
- Local shadow canvases rebuild only for shapes intersecting the light's range at their previous or current bounds. Movement, radius changes, removal, and texture replacement are tracked on the next world update. Stars conservatively redraw for any scene geometry change.
- Affected shadow canvases are cleared and fully redrawn, rather than painting only changed shapes, so overlaps and height layers remain correct.
- Color, direct `Arc` changes, and light rotation only recompose illumination. Source-size changes update the penumbra radius field without rebuilding shadow pixels or occluder-distance fields. Disabling filtering releases its buffers; enabling it rebuilds them.
- Light position and radius changes rebuild shadow geometry. Radius changes also recreate local-light canvases at the new size. Star camera changes rebuild view-dependent geometry and rendering.
- `LightWorld:DrawShadows(lightOrStar)` and `LightWorld:DrawSprites(lightOrStar)` run during shadow-buffer rebuilds, not appearance-only recomposition. Call `world:ForceUpdate()` if their output depends on changed light appearance or external state, or if texture pixels are edited in place.
- When penumbras are enabled, `DrawSprites` is also invoked for the occluder mask. Keep this callback limited to drawing; do not update simulation state inside it.

See the [standard demonstration](Standard-Demonstration.md) for a complete interactive scene.
