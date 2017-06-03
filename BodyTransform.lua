module("shadows.BodyTransform", package.seeall)

Transform = require("shadows.Transform")

BodyTransform = setmetatable( {}, Transform )
BodyTransform.__index = BodyTransform

BodyTransform.DestroyAttachments = false
BodyTransform.FollowPosition = true
BodyTransform.FollowRotation = true

function BodyTransform:new(Body)
	
	if Body then
		
		local self = setmetatable( {}, BodyTransform )
		
		self.Body = Body
		
		self.Children = {}
		self.Matrix = { {}, {} }
		self.InverseMatrix = { {}, {} }
		
		self:SetLocalRotation(0)
		
		return self
		
	end
	
end

function BodyTransform:Update()
	
	if self.Body then
		
		if self.Body:isDestroyed() then
			
			self:Remove()
		
		else
			
			if self.FollowPosition then
				
				self:SetLocalPosition( self.Body:getPosition() )
				
			end
			
			if self.FollowRotation then
				
				self:SetLocalRotation( math.deg( self.Body:getAngle() ) )
				
			end
			
		end
		
	end
	
end

function BodyTransform:Remove()
	
	if self.World then
		
		self.World.BodyTracks[self.TransformID] = nil
		self.World = nil
		self.TransformID = nil
		
		for Index, Child in pairs(self.Children) do
			
			if self.DestroyAttachments then
				
				if Child.Object then
					
					Child.Object:Remove()
					
				end
				
			end
			
			Child:SetParent(nil)
			
		end
		
		self:SetParent(nil)
		
	end
	
end

function BodyTransform:SetDestroyAttachments(DestroyAtachments)
	
	self.DestroyAttachments = DestroyAttachments
	
end

function BodyTransform:GetDestroyAttachments()
	
	return self.DestroyAttachments
	
end

function BodyTransform:SetFollowPosition(FollowPosition)
	
	self.FollowPosition = FollowPosition
	
end

function BodyTransform:GetFollowPosition()
	
	return self.FollowPosition
	
end

function BodyTransform:SetFollowRotation(FollowRotation)
	
	self.FollowRotation = FollowRotation
	
end

function BodyTransform:GetFollowRotation()
	
	return self.FollowRotation
	
end

return BodyTransform