local Path = (...):gsub("%.", "/")
local Shadows = {}

package.loaded["shadows"] = Shadows
package.preload["shadows.Object"]			=	assert(love.filesystem.load(Path.."/Object.lua"))
package.preload["shadows.Transform"]		=	assert(love.filesystem.load(Path.."/Transform.lua"))
package.preload["shadows.LightWorld"]		=	assert(love.filesystem.load(Path.."/LightWorld.lua"))
package.preload["shadows.Light"]				=	assert(love.filesystem.load(Path.."/Light.lua"))
package.preload["shadows.Star"]				=	assert(love.filesystem.load(Path.."/Star.lua"))
package.preload["shadows.Body"]				=	assert(love.filesystem.load(Path.."/Body.lua"))
package.preload["shadows.OutputShadow"]	=	assert(love.filesystem.load(Path.."/OutputShadow.lua"))
package.preload["shadows.PriorityQueue"]	=	assert(love.filesystem.load(Path.."/PriorityQueue.lua"))

-- Shadow shapes

package.preload["shadows.ShadowShapes.Shadow"]			=	assert(love.filesystem.load(Path.."/ShadowShapes/Shadow.lua"))
package.preload["shadows.ShadowShapes.CircleShadow"]	=	assert(love.filesystem.load(Path.."/ShadowShapes/CircleShadow.lua"))
package.preload["shadows.ShadowShapes.HeightShadow"]	=	assert(love.filesystem.load(Path.."/ShadowShapes/HeightShadow.lua"))
package.preload["shadows.ShadowShapes.ImageShadow"]	=	assert(love.filesystem.load(Path.."/ShadowShapes/ImageShadow.lua"))
package.preload["shadows.ShadowShapes.NormalShadow"]	=	assert(love.filesystem.load(Path.."/ShadowShapes/NormalShadow.lua"))
package.preload["shadows.ShadowShapes.PolygonShadow"]	=	assert(love.filesystem.load(Path.."/ShadowShapes/PolygonShadow.lua"))

-- Rooms

package.preload["shadows.Room"]						=		assert(love.filesystem.load(Path.."/Room/Room.lua"))
package.preload["shadows.Room.CircleRoom"]		=		assert(love.filesystem.load(Path.."/Room/CircleRoom.lua"))
package.preload["shadows.Room.PolygonRoom"]		=		assert(love.filesystem.load(Path.."/Room/PolygonRoom.lua"))
package.preload["shadows.Room.RectangleRoom"]	=		assert(love.filesystem.load(Path.."/Room/RectangleRoom.lua"))

package.preload["shadows.Functions"]				=		assert(love.filesystem.load(Path.."/Functions.lua"))
package.preload["shadows.Shaders"]					=		assert(love.filesystem.load(Path.."/Shaders.lua"))

require("shadows.Shaders")
require("shadows.Functions")

return Shadows