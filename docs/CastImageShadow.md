# CastImageShadow

An upright, bottom-center-anchored image. Texture alpha determines blocking
coverage independently of RGB: even a black opaque trunk casts a solid shadow,
while transparent gaps transmit light. Ground shadows are ray-projected away
from each local light or star, not a copy of the texture at its original position.

```lua
local CastImageShadow = require("shadows.ShadowShapes.CastImageShadow")
local body = Body:new(world)
body:SetPosition(400, 300, 0) -- ground anchor
local tree = CastImageShadow:new(body, texture, 80, 100)

-- Update world lighting normally, then draw the floor and its lighting.
world:Draw()
tree:DrawSprite() -- after world lighting; depth-sort multiple sprites by ground y
```

Width and height default to the texture dimensions. `GetPosition` and
`GetCentroid` return the anchor x/y and **top height** for renderer sorting;
`GetTransform():GetPosition()` returns the actual bottom-center anchor.
Shape-local translation and ground-plane rotation are inherited. World camera
translation/zoom and high-DPI canvases are supported.

`DrawSprite()` shades the image using the world's ambient RGB and all registered
lights/stars, with radial attenuation, light color/alpha, angular coverage, and
front-facing diffuse illumination. A light behind the sprite produces an
ambient-only silhouette. Every other `CastImageShadow` in the same world is
tested for alpha occlusion between each sprite pixel and the light. The sprite
does not occlude itself. Call this method once per sprite, back to front.

Ground projection participates in the existing shadow cache and optional
penumbra filter. Sprite illumination is rebuilt at draw time; it uses two
per-sprite canvases and work proportional to the number of lights times the
number of other upright sprites. Sprite-to-sprite shadows are hard-edged.
Ground projection targets z=0. Other shape types, custom shadow callbacks,
normal maps, room darkening, and custom light textures do not participate in
the upright sprite receiver calculation. This is a vertical-plane approximation,
not volumetric foliage or a 3D renderer.

`SetTexture`, `GetTexture`, `GetWidth`, `GetHeight`, `SetPosition`,
`GetTransform`, and `Remove` follow the shared image/shape API.
Use `world:ForceUpdate()` if texture pixels are edited in place.

Run `love . CastImage --capture --verify` for the forest demonstration and
all-tree regression checks at DPI 1 and 2. Each tree is checked for solid and
transparent alpha projection, front/back illumination, occlusion by another
tree, blocker removal, rotated planes, multiple lights, cones, light alpha,
texture replacement, and camera zoom. All 17 trees are also rendered together
at three light positions and compared with forced full rebuilds.
