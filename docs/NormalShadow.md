# NormalShadow

`NormalShadow` shades a textured occluder using a normal map. The texture's color encodes the surface direction used by the light shader.

## Import and construction

```lua
local NormalShadow = require("shadows.ShadowShapes.NormalShadow")
local Body = require("shadows.Body")
local LightWorld = require("shadows.LightWorld")

local world = LightWorld:new()
local normalMap = love.graphics.newImage("normal.png")
local body = Body:new(world)
local shadow = NormalShadow:new(body, normalMap)
```

Optional width and height arguments scale the displayed map independently. Without them, the texture's intrinsic dimensions are used.

## Methods

| Method | Description and return values |
|---|---|
| `NormalShadow:new(body, texture, width?, height?)` | Creates and attaches a normal-map occluder. |
| `shadow:SetTexture(texture)` / `shadow:GetTexture()` | Replaces or returns the normal map. |
| `shadow:GetWidth()` / `shadow:GetHeight()` | Return the configured dimensions or the texture's intrinsic dimensions. |
| `shadow:SetPosition(x, y)` / `shadow:GetPosition()` | Inherited from the shared shadow shape API; sets local position or returns world position and height. |
| `shadow:GetTransform()` | Inherited method returning the shape transform. |
| `shadow:Remove()` | Inherited removal; detaches the shape from its body. |

`GetSqrRadius` supplies the renderer's culling bound; `GenerateShadows` creates the internal shader draw call and sets the light uniforms.
