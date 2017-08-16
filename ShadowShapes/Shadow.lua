module("shadows.ShadowShapes.Shadow", package.seeall)

Object = require("shadows.Object")

Shadow = setmetatable( {}, Object )
Shadow.__index = Shadow
Shadow.__type = "Shadow"

function Shadow:Update()
	
	if self.Transform then
		
		if self.Transform.HasChanged then
			
			self.Transform.HasChanged = false
			self.Body:GetTransform().HasChanged = true
			
		end
		
	end
	
end

function Shadow:__lt(secondShadow)
	
	local x1, y1, z1 = self:GetTransform():GetPosition()
	local x2, y2, z2 = secondShadow:GetTransform():GetPosition()
	
	return z1 < z2
	
end

function Shadow:__le(secondShadow)
	
	local x1, y1, z1 = self:GetTransform():GetPosition()
	local x2, y2, z2 = secondShadow:GetTransform():GetPosition()
	
	return z1 <= z2
	
end

function Shadow:Draw()
	
end

function Shadow:SetPosition(x, y)
	
	if self.Transform:SetLocalPosition(x, y) then
		
		self.Body.World.Changed = true
		self.Changed = true
		
	end
	
end

function Shadow:GetPosition()
	
	return self.Transform:GetPosition()
	
end

function Shadow:GetCentroid()
	
	return self.Transform:GetPosition()
	
end

function Shadow:GetRadius()
	
	return math.sqrt( self:GetSqrRadius() )
	
end

function Shadow:GetSqrRadius()
	
	return 0
	
end

function Shadow:Remove()
	
	if self.Body then
		
		self.Body:GetShapes():Remove(self)
		self.Body.World.Changed = true
		self.Body = nil
		
		self.Transform:SetParent(nil)
		
	end
	
end

function Shadow:GenerateShadows(Shapes, Body, DeltaX, DeltaY, DeltaZ, Light)
	
end

function Shadow:GetTransform()
	
	return self.Transform
	
end

function Shadow:SetChanged(Changed)
	
	self.Changed = Changed
	
end

function Shadow:GetChanged()
	
	return self.Changed
	
end

return Shadow