local Path, Shadows = ...
local Room = {}

Shadows.Room = {Base = Room}

assert(love.filesystem.load(Path.."/Circle.lua"))(Shadows)
assert(love.filesystem.load(Path.."/Polygon.lua"))(Shadows)
assert(love.filesystem.load(Path.."/Rectangle.lua"))(Shadows)

Room.__index = Room
Room.x, Room.y = 0, 0
Room.Angle = 0
Room.R, Room.G, Room.B, Room.A = 0, 0, 0, 255

function Room:SetColor(R, G, B, A)
	if R ~= self.R then
		self.R = R
		self.World.UpdateCanvas = true
	end
	if G ~= self.G then
		self.G = G
		self.World.UpdateCanvas = true
	end
	if B ~= self.B then
		self.B = B
		self.World.UpdateCanvas = true
	end
	if A ~= self.A then
		self.A = A
		self.World.UpdateCanvas = true
	end
end

function Room:GetColor()
	return self.R, self.G, self.B, self.A
end