module("shadows.Room", package.seeall)

Shadows = require("shadows")

Room = {}
Room.__index = Room

Room.R, Room.G, Room.B, Room.A = 0, 0, 0, 255

function Room:new()
	
	return setmetatable( {}, Room )
	
end

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

function Room:Update()
	
	if self.Transform.HasChanged then
		
		self.Transform.HasChanged = nil
		self.World.UpdateCanvas = true
		
	end
	
end

function Room:GetPosition()
	
	return self.Transform:GetPosition()
	
end

function Room:SetPosition(x, y, z)
	
	return self.Transform:SetPosition(x, y, z)
	
end

function Room:GetLocalPosition()
	
	return self.Transform:GetLocalPosition()
	
end

function Room:SetLocalPosition(x, y, z)
	
	return self.Transform:SetLocalPosition(x, y, z)
	
end

function Room:GetRotation()
	
	return self.Transform:GetRotation()
	
end

function Room:SetRotation(Rotation)
	
	return self.Transform:SetRotation(Rotation)
	
end

function Room:GetLocalRotation()
	
	return self.Transform:GetLocalRotation()
	
end

function Room:SetLocalRotation(Rotation)
	
	return self.Transform:SetLocalRotation(Rotation)
	
end

function Room:GetColor()
	
	return self.R, self.G, self.B, self.A
	
end

function Room:Remove()
	
	if self.World then
		
		self.World.Rooms[self.ID] = nil
		self.World.UpdateCanvas = true
		self.World = nil
		self.ID = nil
		
		self.Transform:SetParent(nil)
		
	end
	
end

function Room:GetTransform()
	
	return self.Transform
	
end

return Room