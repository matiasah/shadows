# Transform

`Transform` represents a local position, height, and rotation and can be parented to another transform. Its world-space values compose the transforms of all ancestors. Rotations are in degrees unless a method explicitly says radians.

## Import and construction

```lua
local Transform = require("shadows.Transform")

local parent = Transform:new()
local child = Transform:new()
child:SetParent(parent)
child:SetLocalPosition(20, 10, 0.5)
child:SetLocalRotation(30)
```

Changing a parent propagates the changed flag through its descendants. Setting a parent does not preserve the child's prior world-space transform.

## Parent and rotation

| Method | Description and return values |
|---|---|
| `transform:SetParent(parent?)` | Sets or clears the parent transform. |
| `transform:GetParent()` | Returns the parent, if any. |
| `transform:SetLocalRotation(angle)` | Sets local rotation in degrees; returns `true` when it changes. |
| `transform:GetLocalRotation()` | Returns local rotation in degrees. |
| `transform:GetLocalRadians()` | Returns local rotation in radians. |
| `transform:SetRotation(angle)` | Sets world rotation in degrees; converts to local rotation when parented and returns whether it changed. |
| `transform:GetRotation(offset?)` | Returns normalized accumulated world rotation in degrees. An optional offset is added before normalization. |
| `transform:GetRadians(offset?)` | Returns normalized accumulated world rotation in radians. |
| `transform:ToWorldAngle(angle)` | Converts a local angle in degrees to world space. |
| `transform:ToLocalAngle(angle)` | Converts a world angle in degrees to local space. |

Angles are normalized into `[-180, 180]` degrees or `[-pi, pi]` radians.

## Position and coordinate conversion

| Method | Description and return values |
|---|---|
| `transform:SetLocalPosition(x, y, z?)` | Sets local x/y and optional height; returns whether a supplied coordinate changed. |
| `transform:GetLocalPosition()` | Returns local `x`, `y`, and `z`. |
| `transform:SetPosition(x, y, z)` | Sets world `x`, `y`, and `z`, converting to parent-local coordinates when parented. |
| `transform:GetPosition()` | Returns world `x`, `y`, and `z`. |
| `transform:GetPositionVector()` | Returns `{ x = ..., y = ..., z = ... }` in world coordinates. |
| `transform:ToWorld(x, y, z?)` | Converts one local point to world `x`, `y`, and `z`; omitted local height defaults to zero. |
| `transform:ToWorldPoints(points)` | Converts a flat array of local x/y pairs to world-space pairs. Height is not supported. |
| `transform:ToLocal(x, y, z)` | Converts one world point and height to local coordinates. |

For a parented transform, supply all three coordinates to `SetPosition` and `ToLocal`; use `SetLocalPosition` when only x/y need to change while preserving local height.

## Change tracking

`Transform:Change()` marks this transform and all descendants changed. Transform-owning objects use this flag to invalidate cached rendering. `HasChanged`, `Children`, `Matrix`, and `InverseMatrix` are implementation state; applications should use the methods above instead of modifying these fields directly.
