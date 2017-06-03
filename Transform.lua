-- @author Starkkz

module("shadows.Transform", package.seeall)

Transform = {}
Transform.__index = Transform
Transform.x, Transform.y, Transform.z = 0, 0, 0

PI = math.pi

-- @description: Creates a new transformation
function Transform:new()
	
	local self = setmetatable({}, Transform)
	
	self.Children = {}
	self.Matrix = { {}, {} }
	self.InverseMatrix = { {}, {} }
	
	self:SetLocalRotation(0)
	
	return self
	
end

-- @description: Assigns a transform as a parent of another transform (Makes the coordinates of a transform local to another)
function Transform:SetParent(Parent)
	
	if self.Parent then
		
		self.Parent.Children[ self.ID ] = nil
		
	end
	
	if Parent then
		
		self.ID = #Parent.Children + 1
		self.Parent = Parent
		
		Parent[ self.ID ] = self
		
	else
		
		self.ID = nil
		self.Parent = nil
		
	end
	
end

-- @description: Gets the parent transform of a transform
function Transform:GetParent()
	
	return self.Parent
	
end

-- @description: Tells the children that the transform has changed
function Transform:Change()
	
	self.HasChanged = true
	
	for ID, Child in pairs(self.Children) do
		
		Child:Change()
		
	end
	
end

-- @description: Sets the local rotation of a transform
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
			local Multiplier = 1 / ( a * d - b * c )
			
			self.InverseMatrix[1][1] = d * Multiplier
			self.InverseMatrix[1][2] = -b * Multiplier
			self.InverseMatrix[2][1] = -c * Multiplier
			self.InverseMatrix[2][2] = a * Multiplier
			
		end
		
		self:Change()
		
		return true
		
	end
	
end

-- @description: Gets the local rotation of a transform
function Transform:GetLocalRotation()
	
	return self.Rotation
	
end

-- @description: Gets the local rotation of a transform in radians
function Transform:GetLocalRadians()
	
	return self.Radians
	
end

-- @description: Sets the rotation of a transform
function Transform:SetRotation(Angle)
	
	if self.Parent then
		
		Angle = Angle - self.Parent:GetRotation()
		
	end
	
	return self:SetLocalRotation(Angle)
	
end

-- @description: Gets the rotation of a transform + SumRotation in degrees
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

-- @description: Gets the rotation of a transform + SumRadians in radians
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

-- @description: Sets the local position of a transform
function Transform:SetLocalPosition(x, y, z)
	
	if x ~= self.x or y ~= self.y or ( z and z ~= self.z ) then
		
		if z then
			
			self.z = z
			
		end
		
		self.x, self.y = x, y
		self:Change()
		
		return true
		
	end
	
	return false
	
end

-- @description: Gets the local position of a transform
function Transform:GetLocalPosition()
	
	return self.x, self.y, self.z
	
end

-- @description: Sets the position of a transform
function Transform:SetPosition(x, y, z)
	
	if self.Parent then
		
		x, y, z = self.Parent:ToLocal(x, y, z)
		
	end
	
	return self:SetLocalPosition(x, y, z)
	
end

-- @description: Gets the position of a transform
function Transform:GetPosition()
	
	if self.Parent then
		
		return self.Parent:ToWorld(self.x, self.y, self.z)
		
	end
	
	return self.x, self.y, self.z
	
end

-- @description: Gets the position of a transform as a vector
function Transform:GetPositionVector()
	
	if self.Parent then
		
		local x, y, z = self.Parent:ToWorld(self.x, self.y, self.z)
		
		return {x = x, y = y, z = z}
		
	end
	
	return {x = self.x, y = self.y, z = self.z}
	
end

-- @description: Transforms a point to world coordinates
function Transform:ToWorld(x, y, z)
	
	if self.Parent then
		
		return self.Parent:ToWorld( self.x + self.Matrix[1][1] * x + self.Matrix[1][2] * y, self.y + self.Matrix[2][1] * x + self.Matrix[2][2] * y, self.z + ( z or 0 ) )
		
	end
	
	return self.x + tonumber( self.Matrix[1][1] * x + self.Matrix[1][2] * y ), self.y + tonumber( self.Matrix[2][1] * x + self.Matrix[2][2] * y ), self.z + ( z or 0 )
	
end

-- @description: Transform multiple points to world coordinates (does not support 'z' coordinate)
function Transform:ToWorldPoints(Points)
	
	local TransformedPoints = {}
	
	for i = 1, #Points, 2 do
		
		local x, y = Points[i], Points[i + 1]
		
		TransformedPoints[i] = self.x + tonumber( self.Matrix[1][1] * x + self.Matrix[1][2] * y )
		TransformedPoints[i + 1] = self.y + tonumber( self.Matrix[2][1] * x + self.Matrix[2][2] * y )
		
	end
	
	if self.Parent then
		
		return self.Parent:ToWorldPoints(TransformedPoints)
		
	end
	
	return TransformedPoints
	
end

-- @description: Transforms a point to local coordinates
function Transform:ToLocal(x, y, z)
	
	if self.Parent then
		
		x, y, z = self.Parent:ToLocal(x, y, z)
		
	end
	
	x, y, z = x - self.x, y - self.y, z - self.z
	
	return tonumber( self.InverseMatrix[1][1] * x + self.InverseMatrix[1][2] * y ), tonumber( self.InverseMatrix[2][1] * x + self.InverseMatrix[2][2] * y ), z
	
end

-- @description: Transform a local angle to world
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

-- @description: Transform a world angle to local
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