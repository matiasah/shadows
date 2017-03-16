local Shadows = ...

Star = Light:new()
Star.__index = Star

local setCanvas = love.graphics.setCanvas
local clear = love.graphics.clear
local origin = love.graphics.origin
local translate = love.graphics.translate
local setBlendMode = love.graphics.setBlendMode
local setColor = love.graphics.setColor
local setShader = love.graphics.setShader
local arc = love.graphics.arc
local draw = love.graphics.draw
local halfPi = math.pi * 0.5

function Star:new(World, Radius)
	
	local self = setmetatable({}, Star)
	
	if World and Radius then
		
		local Width, Height = World.Canvas:getDimensions()
		
		self.Transform = Shadows.Transform:new()
		self.Transform:SetLocalPosition(0, 0, 1)
		
		self.Star = true
		self.Radius = Radius
		self.Canvas = love.graphics.newCanvas( Width, Height )
		self.ShadowCanvas = love.graphics.newCanvas( Width, Height )
		self.Shadows = {}
		
		World:AddStar(self)
		
	end
	
	return self
	
end

function Star:Update()
	
	if self.Changed or self.World.Changed or self.Transform.HasChanged or self.World.UpdateStars then
		
		local x, y, z = self.Transform:GetPosition()
		
		setCanvas(self.ShadowCanvas)
		clear(255, 255, 255, 255)
		
		translate(-self.World.x, -self.World.y)
		
		setBlendMode("subtract", "alphamultiply")
		setColor(255, 255, 255, 255)
		
		self:GenerateShadows(x, y)
		self.Moved = nil
		
		if self.Transform.HasChanged then
			
			self.Transform.HasChanged = false
			
		end
		
		for _, Shapes in pairs(self.Shadows) do
			
			for _, Shadow in pairs(Shapes) do
				
				love.graphics[Shadow.type]("fill", unpack(Shadow))
				
			end
			
		end
		
		setColor(255, 255, 255, 255)
		setBlendMode("add")
		
		for Index, Body in pairs(self.World.Bodies) do
			
			Body:DrawRadius(x, y, self.Radius)
			
		end
		
		setCanvas(self.Canvas)
		clear()
		origin()
		translate(x - self.World.x - self.Radius, y - self.World.y - self.Radius)
		
		if self.Image then
			
			setBlendMode("lighten", "premultiplied")
			setColor(self.R, self.G, self.B, self.A)
			draw(self.Image, self.Radius, self.Radius)
			
		else
			
			Shadows.LightShader:send("Radius", self.Radius)
			Shadows.LightShader:send("Center", {x - self.World.x, y - self.World.y, z})
			
			local Arc = math.rad(self.Arc * 0.5)
			local Angle = self.Transform.Radians - halfPi
			
			setShader(Shadows.LightShader)
			setBlendMode("alpha", "premultiplied")
			
			setColor(self.R, self.G, self.B, self.A)
			arc("fill", self.Radius, self.Radius, self.Radius, Angle - Arc, Angle + Arc)
			
			setShader()
			
		end
		
		if self.Blur then
			
			origin()
			setShader(Shadows.RadialBlurShader)
			Shadows.RadialBlurShader:send("Size", {self.Canvas:getDimensions()})
			Shadows.RadialBlurShader:send("Position", {x - self.World.x, y - self.World.y})
			Shadows.RadialBlurShader:send("Radius", self.Radius)
			
		end
		
		setBlendMode("multiply", "alphamultiply")
		draw(self.ShadowCanvas, 0, 0)
		
		setBlendMode("alpha", "alphamultiply")
		setShader()
		
		self.Changed = nil
		self.World.UpdateCanvas = true
		
	end
	
end

function Star:Remove()
	
	self.World.Stars[self.ID] = nil
	self.World.Changed = true
	
	self.Transform:SetParent(nil)
	
end

return Star