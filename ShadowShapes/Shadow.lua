module("shadows.ShadowShapes.Shadow", package.seeall)

Shadow = {}
Shadow.__index = Shadow

function Shadow:Update()
	
	if self.Transform then
		
		if self.Transform.HasChanged then
			
			self.Transform.HasChanged = false
			self.Body:GetTransform().HasChanged = true
			
		end
		
	end
	
end

function Shadow:Draw()
	
end

function Shadow:SetPosition(x, y)
	
	if self.Transform:SetLocalPosition(x, y) then
		
		self.Body.World.Changed = true
		
	end
	
end

function Shadow:GetPosition()
	
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
		
		self.Body.Shapes[self.ID] = nil
		self.Body.World.Changed = true
		self.Body = nil
		self.ID = nil
		
		self.Transform:SetParent(nil)
		
	end
	
end

function Shadow:GenerateShadows(Shapes, Body, DeltaX, DeltaY, DeltaZ, Light)
	
end

return Shadow