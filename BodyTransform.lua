module("shadows.BodyTransform", package.seeall)

Transform = require("shadows.Transform")

BodyTransform = setmetatable( {}, Transform )
BodyTransform.DestroyAttachments = false

function BodyTransform:new(Body)
	
	if Body then
		
		local self = setmetatable( {}, BodyTransform )
		
		self.Body = Body
		self.Attachments = {}
		
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
			
			self:SetLocalPosition( self.Body:getPosition() )
			
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

return BodyTransform