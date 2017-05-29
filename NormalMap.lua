module("shadows.NormalMap", package.seeall)

Transform = require("shadows.Transform")

NormalMap = {}
NormalMap.__index = NormalMap

function NormalMap:new(World, Texture)
	
	if World and Texture then
		
		local self = setmetatable( {}, NormalMap )
		
		self.Transform = Transform:new()
		self.Texture = Texture
		
		World:AddNormalMap(self)
		
		return self
		
	end
	
end

function NormalMap:Draw()
	
	local x, y = self.Transform:GetPosition()
	local Rotation = self.Transform:GetRadians()
	
	love.graphics.draw(self.Texture, x, y, Rotation)
	
end

function NormalMap:Update()
	
	if self.Transform.HasChanged then
		
		self.Transform.HasChanged = false
		self.World.Changed = true
		
	end
	
end

function NormalMap:SetAngle(Angle)
	
	self.Transform:SetLocalRotation(Angle)
	
	return self
	
end

function NormalMap:GetAngle()
	
	return self.Transform:GetRotation()
	
end

function NormalMap:SetPosition(x, y, z)
	
	self.Transform:SetLocalPosition(x, y, z)
	
	return self
	
end

function NormalMap:GetPosition()
	
	return self.Transform:GetPosition()
	
end

function NormalMap:SetTexture(Texture)
	
	if Texture ~= self.Texture then
		
		self.Texture = Texture
		self.World.Changed = true
		
	end
	
end

function NormalMap:GetTexture()
	
	return self.Texture
	
end

function NormalMap:Remove()
	
	self.World.NormalMaps[self.ID] = nil
	self.World.Changed = true
	
	self.Transform:SetParent(nil)
	
end

return NormalMap