local Shadows = ...
local Chain = {}

Shadows.Shape.ChainShape = Chain

Chain.__index = Chain

function Shadows.CreateChain(Body, ...)
	local Chain = setmetatable({}, Chain)
	
	Chain.Body = Body
	Chain.Vertices = {...}
	
	Body:AddShape(Circle)
	
	return Chain
end

function Chain:GenerateShadows(Body, Light)
end