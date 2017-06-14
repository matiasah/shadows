local Path = (...):gsub("%.", "/")
local Shadows = {}

package.loaded["shadows"] = Shadows
package.preload["shadows.Transform"]	=		assert(love.filesystem.load(Path.."/Transform.lua"))
package.preload["shadows.LightWorld"]	=		assert(love.filesystem.load(Path.."/LightWorld.lua"))
package.preload["shadows.Light"]			=		assert(love.filesystem.load(Path.."/Light.lua"))
package.preload["shadows.Star"]			=		assert(love.filesystem.load(Path.."/Star.lua"))
package.preload["shadows.Body"]			=		assert(love.filesystem.load(Path.."/Body.lua"))

-- Shadow shapes

package.preload["shadows.ShadowShapes.CircleShadow"]	=	assert(love.filesystem.load(Path.."/ShadowShapes/CircleShadow.lua"))
package.preload["shadows.ShadowShapes.PolygonShadow"]	=	assert(love.filesystem.load(Path.."/ShadowShapes/PolygonShadow.lua"))
package.preload["shadows.ShadowShapes.NormalShadow"]	=	assert(love.filesystem.load(Path.."/ShadowShapes/NormalShadow.lua"))

-- Integration for love.physics.*

package.preload["shadows.PhysicsShapes.CircleShape"]	=	assert(love.filesystem.load(Path.."/PhysicsShapes/CircleShape.lua"))
package.preload["shadows.PhysicsShapes.PolygonShape"]	=	assert(love.filesystem.load(Path.."/PhysicsShapes/PolygonShape.lua"))

-- Rooms

package.preload["shadows.Room"]						=		assert(love.filesystem.load(Path.."/Room/init.lua"))
package.preload["shadows.Room.CircleRoom"]		=		assert(love.filesystem.load(Path.."/Room/CircleRoom.lua"))
package.preload["shadows.Room.PolygonRoom"]		=		assert(love.filesystem.load(Path.."/Room/PolygonRoom.lua"))
package.preload["shadows.Room.RectangleRoom"]	=		assert(love.filesystem.load(Path.."/Room/RectangleRoom.lua"))

package.preload["shadows.Functions"]				=		assert(love.filesystem.load(Path.."/Functions.lua"))
package.preload["shadows.Shaders"]					=		assert(love.filesystem.load(Path.."/Shaders.lua"))

require("shadows.Shaders")
require("shadows.Functions")

require("shadows.PhysicsShapes.CircleShape")
require("shadows.PhysicsShapes.PolygonShape")

return Shadows