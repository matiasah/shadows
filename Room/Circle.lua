local Shadows = ...
local Room = setmetatable({}, Shadows.Room.Base)

Room.__index = Room
Room.Radius = 0

function Shadows.CreateCircleRoom(World, x, y, Radius)
	local Room = setmetatable({}, Room)
	
	Room.x, Room.y = x, y
	Room.Radius = Radius
	World:AddRoom(Room)
	
	return Room
end

function Room:Draw()
	love.graphics.setColor(self.R, self.G, self.B, self.A)
	love.graphics.circle("fill", self.x, self.y, self.Radius)
end

function Room:SetRadius(Radius)
	if Radius ~= self.Radius then
		self.Radius = Radius
		self.World.UpdateCanvas = true
	end
end

function Room:GetRadius()
	return self.Radius
end