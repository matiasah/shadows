# ImageShadow

`ImageShadow` draws a texture as an occluder. Its silhouette casts a shadow; lighter texture pixels produce darker shadow coverage in the resulting image.

For upright trees or other sprites that project their alpha silhouette away
from the light and receive lighting themselves, use [CastImageShadow](CastImageShadow.md).

## Import and construction

```lua
local ImageShadow = require("shadows.ShadowShapes.ImageShadow")
local Body = require("shadows.Body")
local LightWorld = require("shadows.LightWorld")

local world = LightWorld:new()
local texture = love.graphics.newImage("occluder.png")
local body = Body:new(world)
local shadow = ImageShadow:new(body, texture)
```

Optional width and height arguments scale the displayed texture independently. When omitted, the texture's intrinsic dimensions are used.

## Methods

| Method | Description and return values |
|---|---|
| `ImageShadow:new(body, texture, width?, height?)` | Creates and attaches a textured occluder. |
| `shadow:SetTexture(texture)` / `shadow:GetTexture()` | Replaces or returns the texture. |
| `shadow:GetWidth()` / `shadow:GetHeight()` | Return the configured dimensions or the texture's intrinsic dimensions. |
| `shadow:SetPosition(x, y)` / `shadow:GetPosition()` | Inherited from the shared shadow shape API; sets local position or returns world position and height. |
| `shadow:GetTransform()` | Inherited method returning the shape transform. |
| `shadow:Remove()` | Inherited removal; detaches the shape from its body. |

`GetSqrRadius` supplies the renderer's culling bound; `GenerateShadows` creates the internal draw call.
