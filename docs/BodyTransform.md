# BodyTransform

`BodyTransform` is a [`Transform`](Transform.md) that follows a LÖVE physics body. Obtain one from `LightWorld:TrackBody` so it is updated and removed with its world.

## Creating a tracked transform

```lua
local LightWorld = require("shadows.LightWorld")

local world = LightWorld:new()
local physicsWorld = love.physics.newWorld(0, 0)
local physicsBody = love.physics.newBody(physicsWorld, 100, 100)
local transform = world:TrackBody(physicsBody)
transform:SetFollowPosition(true)
transform:SetFollowRotation(true)
```

Position and rotation tracking are enabled by default. Update the world each frame to synchronize the transform.

## Methods

| Method | Description and return values |
|---|---|
| `world:TrackBody(physicsBody)` | Creates, registers, and returns a `BodyTransform`. |
| `transform:SetFollowPosition(enabled)` / `transform:GetFollowPosition()` | Enables or reads position tracking. |
| `transform:SetFollowRotation(enabled)` / `transform:GetFollowRotation()` | Enables or reads rotation tracking. |
| `transform:SetDestroyAttachments(enabled)` / `transform:GetDestroyAttachments()` | Enables or reads removal of attached objects when this transform is removed. Disabled by default. |
| `transform:Remove()` | Unregisters the tracked transform and detaches its children. If `DestroyAttachments` is enabled, attached objects are removed as well. |

`BodyTransform` inherits the position, rotation, parenting, and conversion methods documented in [Transform](Transform.md). It is removed automatically when its physics body is destroyed.
