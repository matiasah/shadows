local Path = (...):gsub("%p", "/")
local Shadows = {}

assert(love.filesystem.load(Path.."/Functions.lua"))(Shadows)
assert(love.filesystem.load(Path.."/World.lua"))(Shadows)
assert(love.filesystem.load(Path.."/Light.lua"))(Shadows)
assert(love.filesystem.load(Path.."/Body/init.lua"))(Path.."/Body", Shadows)
assert(love.filesystem.load(Path.."/Room/init.lua"))(Path.."/Room", Shadows)
assert(love.filesystem.load(Path.."/Shaders.lua"))(Shadows)

return Shadows