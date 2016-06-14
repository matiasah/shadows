local Shadows = ...
local Room = setmetatable({}, Shadows.Room.Base)

Room.__index = Room
Room.Width, Room.Height = 0, 0

function Shadows.CreateRectangleRoom(World, x, y, Width, Height)
	local Room = setmetatable({}, Room)
	
	Room.x, Room.y = x, y
	Room.Width, Room.Height = Width, Height
	World:AddRoom(Room)
	
	return Room
end

function Room:Draw()
	love.graphics.setColor(self.R, self.G, self.B, self.A)
	love.graphics.rectangle("fill", self.x, self.y, self.Width, self.Height)
end

function Room:SetDimensions(Width, Height)
	if Width ~= self.Width then
		self.Width = Width
		self.World.UpdateCanvas = true
	end
	if Height ~= self.Height then
		self.Height = Height
		self.World.UpdateCanvas = true
	end
end

function Room:GetDimensions()
	return self.Width, self.Height
end

function Room:GetWidth()
	return self.Width
end

function Room:GetHeight()
	return self.Height
end