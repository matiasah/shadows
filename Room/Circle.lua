local Shadows = ...
local Room = setmetatable({}, Shadows.Room.Base)

Room.__index = Room
Room.Radius = 0

function Shadows.CreateCircleRoom(World, x, y, Radius)
	
	local Room = setmetatable({}, Room)
	
	Room.Transform = Shadows.Transform:new()
	Room.Transform:SetLocalPosition(x, y)
	
	Room.Radius = Radius
	
	World:AddRoom(Room)
	
	return Room
	
end

function Room:Draw()
	
	local x, y = self.Transform:GetPosition()
	
	love.graphics.setColor(self.R, self.G, self.B, self.A)
	love.graphics.circle("fill", x, y, self.Radius)
	
end

function Room:Update()
	
	if self.Transform.HasChanged then
		
		self.Transform.HasChanged = nil
		self.World.UpdateCanvas = true
		
	end
	
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