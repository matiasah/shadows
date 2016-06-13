local Shadows = ...
local Circle = {}

Shadows.Shape.CircleShape = Circle

Circle.__index = Circle

function Shadows.CreateCircle(Body, x, y, Radius)
	local Circle = setmetatable({}, Circle)
	
	Circle.Body = Body
	Circle.Radius = Radius
	Circle.x, Circle.y = x, y
	
	Body:AddShape(Circle)
	
	return Circle
end

function Circle:GenerateShadows(Body, Light)
end