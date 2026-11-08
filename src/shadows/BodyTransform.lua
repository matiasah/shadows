--- Provides a transform that follows a LÖVE physics body.
module("shadows.BodyTransform", package.seeall)

Transform = require("shadows.Transform")

--- @class BodyTransform: Transform
--- @field Body love.Body Physics body being tracked.
--- @field Children table Child transforms indexed by attachment ID.
--- @field Matrix number[][] Local rotation matrix.
--- @field InverseMatrix number[][] Inverse local rotation matrix.
--- @field World LightWorld? World that registered this transform.
--- @field TransformID integer? Index in the world's tracked-body table.
--- @field DestroyAttachments boolean Whether attached objects are removed on detach.
--- @field FollowPosition boolean Whether updates copy the physics body's position.
--- @field FollowRotation boolean Whether updates copy the physics body's rotation.
BodyTransform = setmetatable({}, Transform)
BodyTransform.__index = BodyTransform
BodyTransform.__type = "BodyTransform"

BodyTransform.DestroyAttachments = false
BodyTransform.FollowPosition = true
BodyTransform.FollowRotation = true

--- @description Creates a transform that follows a physics body.
--- @param Body love.Body? Physics body to track.
--- @return BodyTransform? transform New tracked transform, or nil when Body is omitted.
function BodyTransform:new(Body)
	if Body then
		local self = setmetatable({}, BodyTransform)

		self.Body = Body

		self.Children = {}
		self.Matrix = { {}, {} }
		self.InverseMatrix = { {}, {} }

		self:SetLocalRotation(0)

		return self
	end
end

--- @description Synchronizes enabled position and rotation tracking, removing destroyed bodies.
--- @return nil
function BodyTransform:Update()
	if self.Body then
		if self.Body:isDestroyed() then
			self:Remove()
		else
			if self.FollowPosition then
				self:SetLocalPosition(self.Body:getPosition())
			end

			if self.FollowRotation then
				self:SetLocalRotation(math.deg(self.Body:getAngle()))
			end
		end
	end
end

--- @description Unregisters the transform and detaches or removes its child objects.
--- @return nil
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

--- @description Sets whether objects attached to this transform are removed on detach.
--- @param DestroyAtachments boolean Whether to remove attached objects.
--- @return nil
function BodyTransform:SetDestroyAttachments(DestroyAtachments)
	self.DestroyAttachments = DestroyAttachments
end

--- @description Returns whether attached objects are removed on detach.
--- @return boolean destroyAttachments Attachment cleanup setting.
function BodyTransform:GetDestroyAttachments()
	return self.DestroyAttachments
end

--- @description Enables or disables position tracking.
--- @param FollowPosition boolean Whether to copy the physics body's position.
--- @return nil
function BodyTransform:SetFollowPosition(FollowPosition)
	self.FollowPosition = FollowPosition
end

--- @description Returns whether position tracking is enabled.
--- @return boolean followPosition Position tracking setting.
function BodyTransform:GetFollowPosition()
	return self.FollowPosition
end

--- @description Enables or disables rotation tracking.
--- @param FollowRotation boolean Whether to copy the physics body's rotation.
--- @return nil
function BodyTransform:SetFollowRotation(FollowRotation)
	self.FollowRotation = FollowRotation
end

--- @description Returns whether rotation tracking is enabled.
--- @return boolean followRotation Rotation tracking setting.
function BodyTransform:GetFollowRotation()
	return self.FollowRotation
end

return BodyTransform
