# Body

`Body` groups shadow shapes under one position, rotation, and height transform. Bodies are registered with a [`LightWorld`](LightWorld.md) and sorted by height during rendering.

## Import and construction

```lua
local Body = require("shadows.Body")
local LightWorld = require("shadows.LightWorld")

local world = LightWorld:new()
local body = Body:new(world)
body:SetPosition(300, 240, 0.5)
body:SetAngle(15)
```

`Body:new(world)` returns a registered body when given a world; without a world it returns `nil`.

## Methods

| Method | Description and return values |
|---|---|
| `Body:AddShape(shape)` | Adds a shadow shape and returns this body. Shape constructors usually register themselves automatically. |
| `Body:Draw()` | Draws all attached shapes. Used by the renderer. |
| `Body:DrawRadius(x, y, z, radius)` | Draws shapes whose centroids are within `radius` of the point. Used during light rendering. |
| `Body:Update()` | Synchronizes a tracked physics body and updates attached shapes. Called by the world. |
| `Body:InitFromPhysics(physicsBody)` | Imports circle and polygon fixtures from a LÖVE physics body, begins tracking it, and returns this body. |
| `Body:TrackPhysics(physicsBody)` | Makes this body follow a LÖVE physics body during updates; returns this body. |
| `Body:GetTrackedPhysics()` | Returns the tracked physics body, if any. |
| `Body:SetPosition(x, y, z?)` | Sets world position and optional height; returns this body. |
| `Body:GetPosition()` | Returns world `x`, `y`, and `z`. |
| `Body:GetPositionVector()` | Returns the world position as `{ x = ..., y = ..., z = ... }`. |
| `Body:SetAngle(angle)` / `Body:GetAngle()` | Sets or returns the world rotation in degrees. The setter returns this body. |
| `Body:GetRadianAngle()` | Returns the world rotation in radians. |
| `Body:GetTransform()` | Returns the body's [`Transform`](Transform.md). |
| `Body:GetShapes()` | Returns the ordered shape collection. |
| `Body:SetChanged(changed)` / `Body:GetChanged()` | Sets or returns the geometry-dirty flag used by the renderer. |
| `Body:Remove()` | Removes the body from its world and detaches its transform. |

## Physics integration

`InitFromPhysics` creates shadows for circle and polygon fixtures and follows the physics body's position and rotation:

```lua
local body = Body:new(world):InitFromPhysics(physicsBody)
```

Fixtures of other shape types are skipped. To control tracking separately, call `TrackPhysics` or use `LightWorld:TrackBody`.

## Shadow shapes

Add shapes with constructors such as `CircleShadow:new(body, x, y, radius)` and `PolygonShadow:new(body, x1, y1, ...)`. See [Shadow shapes](Shadow.md), [ImageShadow](ImageShadow.md), [NormalShadow](NormalShadow.md), and [HeightShadow](HeightShadow.md).
