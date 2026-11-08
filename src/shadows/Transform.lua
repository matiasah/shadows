--- Provides hierarchical 2D translation and rotation with an independent height axis.
--- @author Starkkz
module("shadows.Transform", package.seeall)

Object = require("shadows.Object")

--- @class Transform: Object
--- @field x number Local x-coordinate.
--- @field y number Local y-coordinate.
--- @field z number Local height.
--- @field Rotation number Local rotation in degrees.
--- @field Radians number Local rotation in radians.
--- @field Parent Transform? Parent transform.
--- @field Children table Child transforms indexed by attachment ID.
--- @field ID integer? Index in the parent's child table.
--- @field Matrix number[][] Local rotation matrix.
--- @field InverseMatrix number[][] Inverse local rotation matrix.
--- @field HasChanged boolean? Whether this transform or an ancestor changed.
--- @field Object any? Object associated with this transform.
Transform = setmetatable({}, Object)
Transform.__index = Transform
Transform.__type = "Transform"
Transform.x, Transform.y, Transform.z = 0, 0, 0

PI = math.pi

--- @description Creates a new transform at the origin with no parent.
--- @return Transform transform New transform.
function Transform:new()
	local self = setmetatable({}, Transform)

	self.Children = {}
	self.Matrix = { {}, {} }
	self.InverseMatrix = { {}, {} }

	self:SetLocalRotation(0)

	return self
end

--- @description Attaches this transform to a parent, making its coordinates parent-relative.
--- @param Parent Transform? Parent transform; nil detaches this transform.
--- @return nil
function Transform:SetParent(Parent)
	if self.Parent then
		self.Parent.Children[self.ID] = nil
	end

	if Parent then
		self.ID = #Parent.Children + 1
		self.Parent = Parent

		Parent.Children[self.ID] = self
	else
		self.ID = nil
		self.Parent = nil
	end
end

--- @description Returns the parent transform.
--- @return Transform? parent Parent transform, if attached.
function Transform:GetParent()
	return self.Parent
end

--- @description Marks this transform and all descendants as changed.
--- @return nil
function Transform:Change()
	self.HasChanged = true

	for ID, Child in pairs(self.Children) do
		Child:Change()
	end
end

--- @description Sets the local rotation in degrees and updates its rotation matrices.
--- @param Angle number Local rotation in degrees.
--- @return boolean? changed True when the rotation changed.
function Transform:SetLocalRotation(Angle)
	while Angle < -180 do
		Angle = Angle + 360
	end

	while Angle > 180 do
		Angle = Angle - 360
	end

	if Angle ~= self.Rotation then
		self.Rotation = Angle
		self.Radians = math.rad(Angle)

		if Angle == 0 then
			self.Matrix[1][1] = 1
			self.Matrix[1][2] = 0
			self.Matrix[2][1] = 0
			self.Matrix[2][2] = 1

			self.InverseMatrix[1][1] = 1
			self.InverseMatrix[1][2] = 0
			self.InverseMatrix[2][1] = 0
			self.InverseMatrix[2][2] = 1
		else
			local Cosine = math.cos(self.Radians)
			local Sine = math.sin(self.Radians)

			-- The transformation matrix

			self.Matrix[1][1] = Cosine
			self.Matrix[1][2] = -Sine
			self.Matrix[2][1] = Sine
			self.Matrix[2][2] = Cosine

			local a = self.Matrix[1][1]
			local b = self.Matrix[1][2]
			local c = self.Matrix[2][1]
			local d = self.Matrix[2][2]
			local Multiplier = 1 / (a * d - b * c)

			self.InverseMatrix[1][1] = d * Multiplier
			self.InverseMatrix[1][2] = -b * Multiplier
			self.InverseMatrix[2][1] = -c * Multiplier
			self.InverseMatrix[2][2] = a * Multiplier
		end

		self:Change()

		return true
	end
end

--- @description Returns the local rotation in degrees.
--- @return number rotation Local rotation.
function Transform:GetLocalRotation()
	return self.Rotation
end

--- @description Returns the local rotation in radians.
--- @return number radians Local rotation in radians.
function Transform:GetLocalRadians()
	return self.Radians
end

--- @description Sets the world rotation in degrees, converting to local space when parented.
--- @param Angle number Desired world rotation in degrees.
--- @return boolean? changed True when the local rotation changed.
function Transform:SetRotation(Angle)
	if self.Parent then
		Angle = Angle - self.Parent:GetRotation()
	end

	return self:SetLocalRotation(Angle)
end

--- @description Returns the accumulated world rotation in degrees, optionally including an offset.
--- @param SumRotation number? Additional rotation in degrees; defaults to 0.
--- @return number rotation Normalized world rotation.
function Transform:GetRotation(SumRotation)
	local Rotation = self.Rotation + (SumRotation or 0)

	if self.Parent then
		Rotation = Rotation + self.Parent:GetRotation()
	end

	while Rotation < -180 do
		Rotation = Rotation + 360
	end

	while Rotation > 180 do
		Rotation = Rotation - 360
	end

	return Rotation
end

--- @description Returns the accumulated world rotation in radians, optionally including an offset.
--- @param SumRadians number? Additional rotation in radians; defaults to 0.
--- @return number radians Normalized world rotation in radians.
function Transform:GetRadians(SumRadians)
	local Rotation = self.Radians + (SumRadians or 0)

	if self.Parent then
		Rotation = Rotation + self.Parent:GetRadians()
	end

	while Rotation < -PI do
		Rotation = Rotation + PI * 2
	end

	while Rotation > PI do
		Rotation = Rotation - PI * 2
	end

	return Rotation
end

--- @description Sets the local x/y position and optionally the local height.
--- @param x number Local x-coordinate.
--- @param y number Local y-coordinate.
--- @param z number? Local height; preserves the current height when omitted.
--- @return boolean changed Whether any supplied coordinate changed.
function Transform:SetLocalPosition(x, y, z)
	if x ~= self.x or y ~= self.y or (z and z ~= self.z) then
		if z then
			self.z = z
		end

		self.x, self.y = x, y
		self:Change()

		return true
	end

	return false
end

--- @description Returns the local position and height.
--- @return number x Local x-coordinate.
--- @return number y Local y-coordinate.
--- @return number z Local height.
function Transform:GetLocalPosition()
	return self.x, self.y, self.z
end

--- @description Sets the world position, converting it into parent-local coordinates when needed.
--- @param x number World x-coordinate.
--- @param y number World y-coordinate.
--- @param z number? World height; defaults through the parent conversion.
--- @return boolean changed Whether any coordinate changed.
function Transform:SetPosition(x, y, z)
	if self.Parent then
		x, y, z = self.Parent:ToLocal(x, y, z)
	end

	return self:SetLocalPosition(x, y, z)
end

--- @description Returns the world position and height.
--- @return number x World x-coordinate.
--- @return number y World y-coordinate.
--- @return number z World height.
function Transform:GetPosition()
	if self.Parent then
		return self.Parent:ToWorld(self.x, self.y, self.z)
	end

	return self.x, self.y, self.z
end

--- @description Returns the world position as a keyed vector.
--- @return table position Vector containing x, y, and z.
function Transform:GetPositionVector()
	if self.Parent then
		local x, y, z = self.Parent:ToWorld(self.x, self.y, self.z)

		return { x = x, y = y, z = z }
	end

	return { x = self.x, y = self.y, z = self.z }
end

--- @description Transforms a local point and optional height into world coordinates.
--- @param x number Local x-coordinate.
--- @param y number Local y-coordinate.
--- @param z number? Local height offset; defaults to 0.
--- @return number x World x-coordinate.
--- @return number y World y-coordinate.
--- @return number z World height.
function Transform:ToWorld(x, y, z)
	if self.Parent then
		return self.Parent:ToWorld(self.x + self.Matrix[1][1] * x + self.Matrix[1][2] * y,
			self.y + self.Matrix[2][1] * x + self.Matrix[2][2] * y, self.z + (z or 0))
	end

	return self.x + tonumber(self.Matrix[1][1] * x + self.Matrix[1][2] * y),
		self.y + tonumber(self.Matrix[2][1] * x + self.Matrix[2][2] * y), self.z + (z or 0)
end

--- @description Transforms a flat list of local x/y points to world coordinates.
--- @param Points number[] Alternating local x/y coordinates.
--- @return number[] points Alternating world x/y coordinates; height is not supported.
function Transform:ToWorldPoints(Points)
	local TransformedPoints = {}

	for i = 1, #Points, 2 do
		local x, y = Points[i], Points[i + 1]

		TransformedPoints[i] = self.x + tonumber(self.Matrix[1][1] * x + self.Matrix[1][2] * y)
		TransformedPoints[i + 1] = self.y + tonumber(self.Matrix[2][1] * x + self.Matrix[2][2] * y)
	end

	if self.Parent then
		return self.Parent:ToWorldPoints(TransformedPoints)
	end

	return TransformedPoints
end

--- @description Transforms a world point and height into this transform's local coordinates.
--- @param x number World x-coordinate.
--- @param y number World y-coordinate.
--- @param z number World height.
--- @return number x Local x-coordinate.
--- @return number y Local y-coordinate.
--- @return number z Local height.
function Transform:ToLocal(x, y, z)
	if self.Parent then
		x, y, z = self.Parent:ToLocal(x, y, z)
	end

	x, y, z = x - self.x, y - self.y, z - self.z

	return tonumber(self.InverseMatrix[1][1] * x + self.InverseMatrix[1][2] * y),
		tonumber(self.InverseMatrix[2][1] * x + self.InverseMatrix[2][2] * y), z
end

--- @description Converts a local angle in degrees to a normalized world angle.
--- @param Angle number Local angle in degrees.
--- @return number rotation World angle in degrees.
function Transform:ToWorldAngle(Angle)
	local Rotation = Angle + self:GetRotation()

	while Rotation < -180 do
		Rotation = Rotation + 360
	end

	while Rotation > 180 do
		Rotation = Rotation - 360
	end

	return Rotation
end

--- @description Converts a world angle in degrees to a normalized local angle.
--- @param Angle number World angle in degrees.
--- @return number rotation Local angle in degrees.
function Transform:ToLocalAngle(Angle)
	local Rotation = Angle - self:GetRotation()

	while Rotation < -180 do
		Rotation = Rotation + 360
	end

	while Rotation > 180 do
		Rotation = Rotation - 360
	end

	return Rotation
end

return Transform
