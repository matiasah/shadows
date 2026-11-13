# Geometric shadow shapes

Geometric shadow shapes are attached to a [`Body`](Body.md), which supplies their world position, rotation, and height. The two primitive shapes are `CircleShadow` and `PolygonShadow`.

## Import and construction

```lua
local CircleShadow = require("shadows.ShadowShapes.CircleShadow")
local PolygonShadow = require("shadows.ShadowShapes.PolygonShadow")
local Body = require("shadows.Body")
local LightWorld = require("shadows.LightWorld")

local world = LightWorld:new()
local body = Body:new(world)
local circle = CircleShadow:new(body, 0, 0, 24)
local polygon = PolygonShadow:new(body, -32, -24, 32, -24, 32, 24, -32, 24)
```

Coordinates are local to the body. Polygon vertices are passed as alternating `x, y` numbers.

## Shared shape methods

| Method | Description and return values |
|---|---|
| `shape:SetPosition(x, y)` / `shape:GetPosition()` | Sets local x/y position or returns world x/y/z. |
| `shape:GetTransform()` | Returns the shape's [`Transform`](Transform.md). |
| `shape:GetCentroid()` | Returns the shape's world-space centroid. |
| `shape:GetRadius()` / `shape:GetSqrRadius()` | Returns its bounding radius or squared radius. |
| `shape:SetChanged(changed)` / `shape:GetChanged()` | Sets or returns the renderer's geometry-dirty flag. |
| `shape:Remove()` | Removes the shape from its body and detaches its transform. |

`Update`, `Draw`, and `GenerateShadows` are renderer hooks called by the body and light world.
Shape-local changes invalidate only that shape's projected geometry and local
lights intersecting its previous or current bounds. Body movement invalidates
all attached shapes. Removal clears the old shadow on the next world update.
For custom geometry changes, use `shape:SetChanged(true)`; use
`world:ForceUpdate()` for custom callbacks or textures whose pixels change in place.

## CircleShadow

| Method | Description |
|---|---|
| `CircleShadow:new(body, x, y, radius)` | Creates and attaches a circle occluder. |
| `shape:SetRadius(radius)` / `shape:GetRadius()` | Sets or returns the radius. Setting it invalidates this shape and lights intersecting its old or new bounds. |
| `shape:SetPosition(x, y)` | Sets local position through the shared shape API. |

## PolygonShadow

| Method | Description |
|---|---|
| `PolygonShadow:new(body, x1, y1, ...)` | Creates and attaches a polygon occluder. |
| `shape:SetVertices(x1, y1, ...)` | Replaces the vertices and recalculates its centroid and bounding radius. |
| `shape:GetVertices()` | Returns the transformed world-space vertices. |
| `shape:GetCentroid()` | Returns the polygon centroid in world space. |

Polygon input is expected to contain at least three coordinate pairs. Shape transforms can also be parented to other transforms; see [Transform](Transform.md).
Simple concave polygons, such as the seven in the `MovingObjects` demo, are
triangulated when vertices change. Their triangles are used for silhouette
drawing and projected-shadow coverage; convex polygons retain the single-contour
path. Self-intersecting polygons and polygons with holes are not supported.
Projected contours preserve silhouette boundary order as polygons rotate,
including when a light is below the caster. Invalid projected geometry raises
a triangulation error rather than silently dropping the shadow.

## Textured shapes

For texture-driven occluders, see [ImageShadow](ImageShadow.md), [NormalShadow](NormalShadow.md), and [HeightShadow](HeightShadow.md).
For upright sprites that cast alpha silhouettes onto the ground and receive
light and shadows from other sprites, see [CastImageShadow](CastImageShadow.md).
