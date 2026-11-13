---@module Loads the Shädows package modules and registers their LÖVE filesystem loaders.
local Path = (...):gsub("%.", "/")
if love.filesystem.getInfo("src/" .. Path .. "/Object.lua") then
    Path = "src/" .. Path
end
--- @class Shadows
--- @field BlurShader love.Shader Box blur shader.
--- @field BloomShader love.Shader Bloom shader.
--- @field DarkenShader love.Shader Ambient-darkening shader.
--- @field AberrationShader love.Shader Chromatic-aberration shader.
--- @field LightShader love.Shader Radial light falloff shader.
--- @field OccluderSeedShader love.Shader Occluder-coordinate initialization shader.
--- @field OccluderDistanceShader love.Shader Nearest-occluder jump-flood shader.
--- @field PenumbraRadiusShader love.Shader Per-pixel contact-hardening footprint shader.
--- @field PenumbraShader love.Shader Normalized contact-hardening shadow filter.
--- @field ShapeShader love.Shader Sprite and shape shader.
--- @field NormalShader love.Shader Normal-map shadow shader.
--- @field HeightShader love.Shader Height-map shadow shader.
--- @field DropShadows love.Shader Image-derived drop-shadow shader.
--- @field Normalize fun(v: number[]): number[] Returns a unit vector.
--- @field PointInPolygon fun(x: number, y: number, Vertices: number[]): boolean Tests polygon containment.
--- @field insertionSort fun(Table: table) Sorts an array in place.
--- @field Insert fun(Table: table, Index: integer, Value: any?) Inserts or appends an array value.
--- @field newDropshadowsFromImageData fun(ImageData: love.ImageData, LightX: number, LightY: number, LightZ: number, LightRadius: number, TextureZ: number, LightRadiusMult: number?): love.Canvas Renders and returns a drop-shadow canvas.
local Shadows                                         = {}

package.loaded["shadows"]                             = Shadows
package.preload["shadows.DPI"]                        = assert(love.filesystem.load(Path .. "/DPI.lua"))
package.preload["shadows.Penumbra"]                   = assert(love.filesystem.load(Path .. "/Penumbra.lua"))
package.preload["shadows.Object"]                     = assert(love.filesystem.load(Path .. "/Object.lua"))
package.preload["shadows.Transform"]                  = assert(love.filesystem.load(Path .. "/Transform.lua"))
package.preload["shadows.LightWorld"]                 = assert(love.filesystem.load(Path .. "/LightWorld.lua"))
package.preload["shadows.Light"]                      = assert(love.filesystem.load(Path .. "/Light.lua"))
package.preload["shadows.Star"]                       = assert(love.filesystem.load(Path .. "/Star.lua"))
package.preload["shadows.Body"]                       = assert(love.filesystem.load(Path .. "/Body.lua"))
package.preload["shadows.OutputShadow"]               = assert(love.filesystem.load(Path .. "/OutputShadow.lua"))
package.preload["shadows.PriorityQueue"]              = assert(love.filesystem.load(Path .. "/PriorityQueue.lua"))

-- Shadow shapes

package.preload["shadows.ShadowShapes.Shadow"]        = assert(love.filesystem.load(Path .. "/ShadowShapes/Shadow.lua"))
package.preload["shadows.ShadowShapes.CircleShadow"]  = assert(love.filesystem.load(Path ..
    "/ShadowShapes/CircleShadow.lua"))
package.preload["shadows.ShadowShapes.HeightShadow"]  = assert(love.filesystem.load(Path ..
    "/ShadowShapes/HeightShadow.lua"))
package.preload["shadows.ShadowShapes.ImageShadow"]   = assert(love.filesystem.load(Path ..
    "/ShadowShapes/ImageShadow.lua"))
package.preload["shadows.ShadowShapes.CastImageShadow"] = assert(love.filesystem.load(Path ..
    "/ShadowShapes/CastImageShadow.lua"))
package.preload["shadows.ShadowShapes.NormalShadow"]  = assert(love.filesystem.load(Path ..
    "/ShadowShapes/NormalShadow.lua"))
package.preload["shadows.ShadowShapes.PolygonShadow"] = assert(love.filesystem.load(Path ..
    "/ShadowShapes/PolygonShadow.lua"))

-- Rooms

package.preload["shadows.Room"]                       = assert(love.filesystem.load(Path .. "/Room/Room.lua"))
package.preload["shadows.Room.CircleRoom"]            = assert(love.filesystem.load(Path .. "/Room/CircleRoom.lua"))
package.preload["shadows.Room.PolygonRoom"]           = assert(love.filesystem.load(Path .. "/Room/PolygonRoom.lua"))
package.preload["shadows.Room.RectangleRoom"]         = assert(love.filesystem.load(Path .. "/Room/RectangleRoom.lua"))

package.preload["shadows.Functions"]                  = assert(love.filesystem.load(Path .. "/Functions.lua"))
package.preload["shadows.Shaders"]                    = assert(love.filesystem.load(Path .. "/Shaders.lua"))

require("shadows.Shaders")
require("shadows.Functions")

return Shadows
