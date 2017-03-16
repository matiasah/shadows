local Path = (...):gsub("%.", "/")
local Shadows = {}

assert(love.filesystem.load(Path.."/Functions.lua"))(Shadows)

Shadows.LightWorld = assert(love.filesystem.load(Path.."/LightWorld.lua"))(Shadows)
Shadows.Light = assert(love.filesystem.load(Path.."/Light.lua"))(Shadows)
Shadows.Star = assert(love.filesystem.load(Path.."/Star.lua"))(Shadows)
Shadows.Body = assert(love.filesystem.load(Path.."/Body.lua"))(Shadows)

-- Shadow shapes

Shadows.CircleShadow = assert(love.filesystem.load(Path.."/ShadowShapes/CircleShadow.lua"))(Shadows)
Shadows.PolygonShadow = assert(love.filesystem.load(Path.."/ShadowShapes/PolygonShadow.lua"))(Shadows)

-- Integration for love.physics.*

assert(love.filesystem.load(Path.."/PhysicsShapes/CircleShape.lua"))(Shadows)
assert(love.filesystem.load(Path.."/PhysicsShapes/PolygonShape.lua"))(Shadows)

-- Rooms

Shadows.Room = assert(love.filesystem.load(Path.."/Room/init.lua"))(Shadows)
Shadows.CircleRoom = assert(love.filesystem.load(Path.."/Room/CircleRoom.lua"))(Shadows)
Shadows.PolygonRoom = assert(love.filesystem.load(Path.."/Room/PolygonRoom.lua"))(Shadows)
Shadows.RectangleRoom = assert(love.filesystem.load(Path.."/Room/RectangleRoom.lua"))(Shadows)

assert(love.filesystem.load(Path.."/Shaders.lua"))(Shadows)

Shadows.Transform = assert(love.filesystem.load(Path.."/Transform.lua"))(Shadows)

return Shadows