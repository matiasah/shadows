# Rooms

Rooms are filled shapes rendered with the ambient-darkening shader. They are useful for dark sectors and interior regions. A room belongs to a [`LightWorld`](LightWorld.md); local lights can illuminate rooms, but stars do not.

## Import and construction

```lua
local LightWorld = require("shadows.LightWorld")
local CircleRoom = require("shadows.Room.CircleRoom")
local RectangleRoom = require("shadows.Room.RectangleRoom")
local PolygonRoom = require("shadows.Room.PolygonRoom")

local world = LightWorld:new()
local circle = CircleRoom:new(world, 400, 300, 120)
local rectangle = RectangleRoom:new(world, 100, 100, 240, 160)
local polygon = PolygonRoom:new(world, 500, 300, {
    0, 0,
    100, 0,
    80, 80,
    0, 60,
})
```

Coordinates and dimensions are in logical pixels. Polygon vertices are a flat array of alternating local `x, y` values. Constructors register rooms when the world and required arguments are supplied.

## Shared room methods

| Method | Description and return values |
|---|---|
| `room:SetPosition(x, y, z?)` / `room:GetPosition()` | Sets or returns the world position and height. The setter returns the transform's changed flag. |
| `room:SetLocalPosition(x, y, z?)` / `room:GetLocalPosition()` | Sets or returns the position relative to the parent transform. |
| `room:SetRotation(angle)` / `room:GetRotation()` | Sets or returns world rotation in degrees. |
| `room:SetLocalRotation(angle)` / `room:GetLocalRotation()` | Sets or returns local rotation in degrees. |
| `room:SetColor(r, g, b, a)` / `room:GetColor()` | Sets or returns RGBA color channels in the 0–255 range. |
| `room:GetTransform()` | Returns the room's [`Transform`](Transform.md). |
| `room:Remove()` | Removes the room from its world and detaches its transform. |

`Room:Update` is called by the world to propagate transform changes to the room canvas; it is not normally called by applications.

## CircleRoom

| Method | Description |
|---|---|
| `CircleRoom:new(world, x, y, radius)` | Creates a circle centered at local position `x, y`. |
| `room:SetRadius(radius)` / `room:GetRadius()` | Sets or returns the circle radius. |

## RectangleRoom

| Method | Description |
|---|---|
| `RectangleRoom:new(world, x, y, width, height)` | Creates a rectangle from its local top-left position and dimensions. |
| `room:SetDimensions(width, height)` | Sets width and height and marks the room canvas for redraw. |
| `room:GetDimensions()` | Returns width and height. |
| `room:GetWidth()` / `room:GetHeight()` | Return the corresponding dimension. |

## PolygonRoom

| Method | Description |
|---|---|
| `PolygonRoom:new(world, x, y, vertices)` | Creates a polygon from a flat local coordinate array. |
| `room:GetVertices()` | Returns the stored local coordinate array. |
| `room:GetWorldVertices()` | Returns a transformed coordinate array in world space. |
| `room:SetVertices(x1, y1, ...)` | Replaces the vertex array with the supplied alternating coordinates. |

Changing polygon vertices directly does not currently mark the world canvas dirty. Call `world:ForceUpdate()` after changing them if the room has already been rendered.
