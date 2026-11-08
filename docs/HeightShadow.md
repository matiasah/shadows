# HeightShadow

`HeightShadow` uses a texture's red channel as a height map when rendering shadows from a [`Body`](Body.md). Unlike a normal map, the height map can occlude light along the projected path, but its shader work can be more expensive.

## Import and construction

```lua
local HeightShadow = require("shadows.ShadowShapes.HeightShadow")
local Body = require("shadows.Body")
local LightWorld = require("shadows.LightWorld")

local world = LightWorld:new()
local heightMap = love.graphics.newImage("height.png")
local body = Body:new(world)
local shadow = HeightShadow:new(body, heightMap)
```

The map is drawn at its intrinsic dimensions and positioned relative to the body.

## Methods

| Method | Description and return values |
|---|---|
| `HeightShadow:new(body, texture)` | Creates and attaches a height-map occluder. |
| `shadow:SetTexture(texture)` / `shadow:GetTexture()` | Replaces or returns the height texture. Replacing it marks the shape changed. |
| `shadow:GetWidth()` / `shadow:GetHeight()` | Return the texture dimensions. |
| `shadow:GetVertices()` | Returns the map rectangle's world-space corners as a flat x/y array. |
| `shadow:SetPosition(x, y)` / `shadow:GetPosition()` | Inherited from the shared shadow shape API; sets local position or returns world position and height. |
| `shadow:Remove()` | Inherited removal; detaches the shape from its body. |

The implementation provides `GetSqrRadius` for renderer culling. `GenerateShadows` is an internal rendering hook that constructs geometry and shader uniforms.

See [NormalShadow](NormalShadow.md) when a normal map provides the desired effect with less per-pixel height tracing.
