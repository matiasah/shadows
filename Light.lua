module("shadows.Light", package.seeall)

Shadows = require("shadows")
Transform = require("shadows.Transform")

Light = {}
Light.__index = Light

Light.Arc = 360
Light.Radius = 0
Light.SizeRadius = 10

Light.R, Light.G, Light.B, Light.A = 255, 255, 255, 255

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

function Light:new(World, Radius)
	
	local self = setmetatable({}, Light)
	
	if World and Radius then
		
		local Width, Height = World.Canvas:getDimensions()
		
		self.Transform = Transform:new()
		self.Transform:SetLocalPosition(0, 0, 1)
		
		self.Radius = Radius
		self.Canvas = love.graphics.newCanvas( Radius * 2, Radius * 2 )
		self.ShadowCanvas = love.graphics.newCanvas( Radius * 2, Radius * 2 )
		self.Shadows = {}
		
		World:AddLight(self)
		
	end
	
	return self
	
end

function Light:GenerateShadows(x, y)
	
	for _, Body in pairs(self.World.Bodies) do
		-- If a body has been removed from the local reference, the light has moved, or the body has moved
		if self.Transform.HasChanged or Body.Moved or not self.Shadows[ Body.ID ] then
			-- Insert the shadow shapes of a body into this table
			local Shapes = {}
			
			if Body.Body then
				-- Get the physics shapes of the physics body
				for _, Fixture in pairs(Body.Body:getFixtureList()) do
					
					local Shape = Fixture:getShape()
					-- It must be a type of shape that is supported by the engine
					if Shape.GenerateShadows then
						
						local Radius = self.Radius + Shape:GetRadius(Body)
						local ShapeX, ShapeY = Shape:GetPosition(Body)
						local dx, dy = ShapeX - x, ShapeY - y
						-- Is the light in the draw range?
						if dx * dx + dy * dy < Radius * Radius then
							
							Shape:GenerateShadows(Shapes, Body, 0, 0, self)
							
						end
						
					end
					
				end
				
			else
				
				for _, Shape in pairs(Body.Shapes) do
					
					local Radius = self.Radius + Shape:GetRadius()
					local ShapeX, ShapeY = Shape:GetPosition()
					local dx, dy = ShapeX - x, ShapeY - y
					-- Is the light in the draw range?
					if dx * dx + dy * dy < Radius * Radius then
						
						Shape:GenerateShadows(Shapes, Body, 0, 0, self)
						
					end
					
				end
				
			end
			-- Make a local reference to a body's shadow shapes
			self.Shadows[ Body.ID ] = Shapes
			
		end
		
	end
	
	return Shapes
end

function Light:Update()
	
	if self.Changed or self.World.Changed or self.Transform.HasChanged then
		
		local x, y, z = self.Transform:GetPosition()
		
		-- Generate new content for the shadow canvas
		setCanvas(self.ShadowCanvas)
		setShader()
		clear(255, 255, 255, 255)
		
		-- Move all the objects so that their position local to the light are corrected
		translate(self.Radius - x, self.Radius - y)
		
		-- Shadow shapes should subtract white color, so that you see black
		setBlendMode("subtract", "alphamultiply")
		setColor(255, 255, 255, 255)
		
		-- Produce the shadow shapes
		self:GenerateShadows(x, y)
		self.Moved = nil
		
		-- This needs to be put right after self:GenerateShadows, because it uses the self.Transform.HasChanged field
		if self.Transform.HasChanged then
			-- If the light has moved, mark it as it hasn't so that it doesn't update until self.Transform.HasChanged is set to true
			self.Transform.HasChanged = false
			
		end
		
		-- Draw the shadow shapes
		for _, Shapes in pairs(self.Shadows) do
			
			for _, Shadow in pairs(Shapes) do
				
				love.graphics[Shadow.type]("fill", unpack(Shadow))
				
			end
			
		end
		
		-- Could possibly draw the normal maps here?
		
		-- Draw the shapes over the shadow shapes, so that the shadow of a object doesn't cover another object
		setColor(255, 255, 255, 255)
		setBlendMode("add", "alphamultiply")
		
		for Index, Body in pairs(self.World.Bodies) do
			
			Body:DrawRadius(x, y, self.Radius)
			
		end
		
		-- Now stop using the shadow canvas and generate the light
		setCanvas(self.Canvas)
		clear()
		origin()
		
		if self.Image then
			-- If there's a image to be used as light texture, use it
			setBlendMode("lighten", "premultiplied")
			setColor(self.R, self.G, self.B, self.A)
			draw(self.Image, self.Radius, self.Radius)
			
		else
			-- Use a shader to generate the light
			Shadows.LightShader:send("Radius", self.Radius)
			Shadows.LightShader:send("Center", {self.Radius, self.Radius, z})
			
			-- Calculate the rotation of the light
			local Arc = math.rad(self.Arc * 0.5)
			local Angle = self.Transform:GetRadians(-halfPi)
			
			-- Set the light shader
			setShader(Shadows.LightShader)
			setBlendMode("alpha", "premultiplied")
			
			-- Filling it with a arc is more efficient than with a rectangle for this case
			setColor(self.R, self.G, self.B, self.A)
			arc("fill", self.Radius, self.Radius, self.Radius, Angle - Arc, Angle + Arc)
			
			-- Unset the shader
			setShader()
			
		end
		
		-- Generate a radial blur (to make the light softer)
		setShader(Shadows.RadialBlurShader)
		Shadows.RadialBlurShader:send("Size", {self.Canvas:getDimensions()})
		Shadows.RadialBlurShader:send("Position", {self.Radius, self.Radius})
		Shadows.RadialBlurShader:send("Radius", self.Radius)
		
		-- Now apply the blur along with the shadow shapes over the light canvas
		setBlendMode("multiply", "alphamultiply")
		draw(self.ShadowCanvas, 0, 0)
		
		-- Reset the blending mode
		setBlendMode("alpha", "alphamultiply")
		
		-- Tell the world it needs to update it's canvas
		self.Changed = nil
		self.World.UpdateCanvas = true
		
	end
	
end

function Light:SetAngle(Angle)
	
	self.Transform:SetLocalRotation(Angle)
	
	return self
	
end

function Light:GetAngle()
	
	return self.Transform:GetRotation()
	
end

function Light:SetPosition(x, y, z)
	
	self.Transform:SetLocalPosition(x, y, z)
	
	return self
	
end

function Light:GetPosition()
	
	return self.Transform:GetPosition()
	
end

function Light:SetColor(R, G, B, A)
	
	if R ~= self.R then
		
		self.R = R
		self.Changed = true
		
	end
	
	if G ~= self.G then
		
		self.G = G
		self.Changed = true
		
	end
	
	if B ~= self.B then
		
		self.B = B
		self.Changed = true
		
	end
	
	if A ~= self.A then
		
		self.A = A
		self.Changed = true
		
	end
	
	return self
	
end

function Light:GetColor()
	
	return self.R, self.G, self.B, self.A
	
end

function Light:SetImage(Image)
	
	if Image ~= self.Image then
		
		local Width, Height = Image:getDimensions()
		
		self.Image = Image
		self.Radius = math.sqrt( Width * Width + Height * Height ) * 0.5
		self.Changed = true
		
	end
	
end

function Light:GetImage()
	
	return self.Image
	
end

function Light:SetRadius(Radius)
	
	if Radius ~= self.Radius then
		
		self.Radius = Radius
		self.Changed = true
		
	end
	
end

function Light:GetRadius()
	
	return self.Radius
	
end

function Light:Remove()
	
	self.World.Lights[self.ID] = nil
	self.World.Changed = true
	
	self.Transform:SetParent(nil)
	
end

return Light