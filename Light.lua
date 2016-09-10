local Shadows = ...
local Light = {}

Light.__index = Light
Light.x, Light.y, Light.z = 0, 0, 1
Light.Angle, Light.Arc = 0, 360
Light.Radius = 0
Light.SizeRadius = 10

Light.R, Light.G, Light.B, Light.A = 255, 255, 255, 255

function Shadows.CreateLight(World, Radius)
	
	local Light = setmetatable({}, Light)
	
	Light.Radius = Radius
	Light.Canvas = love.graphics.newCanvas(Light.Radius * 2, Light.Radius * 2)
	Light.ShadowCanvas = love.graphics.newCanvas(Light.Radius * 2, Light.Radius * 2)
	
	World:AddLight(Light)
	
	return Light
	
end

function Shadows.CreateStar(World, Radius)
	
	local Light = setmetatable({}, Light)
	
	Light.Star = true
	Light.Radius = Radius
	Light.Canvas = love.graphics.newCanvas(Light.Radius * 2, Light.Radius * 2)
	Light.ShadowCanvas = love.graphics.newCanvas(Light.Radius * 2, Light.Radius * 2)
	
	World:AddStar(Light)
	
	return Light
	
end

function Light:GenerateShadows()
	local Shapes = {}
	
	for _, Body in pairs(self.World.Bodies) do
		
		if Body.Body then
			
			for _, Fixture in pairs(Body.Body:getFixtureList()) do
				
				local Shape = Fixture:getShape()
				if Shape.GenerateShadows then
					
					local Radius = self.Radius + Shape:GetRadius(Body)
					local x, y = Shape:GetPosition(Body)
					local dx, dy = x - self.x, y - self.y
					if dx * dx + dy * dy < Radius * Radius then
						
						local SampleMax = self.World.Samples / 2
						local Inv = 1 / SampleMax
						
						for i = -SampleMax, SampleMax do
							
							Shape:GenerateShadows(Shapes, Body, Left[1] * i * self.SizeRadius * Inv, Left[2] * i * self.SizeRadius * Inv, self)
							
						end
						
					end
					
				end
				
			end
			
		else
			
			for _, Shape in pairs(Body.Shapes) do
				
				local Radius = self.Radius + Shape:GetRadius()
				local x, y = Shape:GetPosition()
				local dx, dy = x - self.x, y - self.y
				if dx * dx + dy * dy < Radius * Radius then
					
					local Heading = math.atan2(dy, dx) - math.pi / 2
					local Left = {math.cos(Heading), math.sin(Heading)}
					
					local SampleMax = self.World.Samples / 2
					local Inv = 1 / SampleMax
					
					for i = -SampleMax, SampleMax do
						
						Shape:GenerateShadows(Shapes, Body, Left[1] * i * self.SizeRadius * Inv, Left[2] * i * self.SizeRadius * Inv, self)
						
					end
					
				end
				
			end
			
		end
		
	end
	
	return Shapes
end

function Light:Update()
	
	if self.Changed or self.World.Changed then
		
		love.graphics.setCanvas(self.ShadowCanvas)
		
		love.graphics.translate(self.Radius - self.x, self.Radius - self.y)
		love.graphics.clear(255, 255, 255, 255)
		
		local SampleColor = 255 / self.World.Samples + 1
		
		love.graphics.setBlendMode("subtract", "alphamultiply")
		love.graphics.setColor(SampleColor, SampleColor, SampleColor, 255)
		
		for _, Shadow in pairs(self:GenerateShadows()) do
			
			love.graphics[Shadow.type]("fill", unpack(Shadow))
			
		end
		
		love.graphics.setColor(255, 255, 255, 255)
		love.graphics.setBlendMode("add")
		love.graphics.draw(self.World.BodyCanvas, 0, 0)
		
		love.graphics.setCanvas(self.Canvas)
		love.graphics.clear()
		love.graphics.origin()
		
		if self.Image then
			
			love.graphics.setBlendMode("lighten", "premultiplied")
			love.graphics.setColor(self.R, self.G, self.B, self.A)
			love.graphics.draw(self.Image, self.Radius, self.Radius)
			
		else
			
			Shadows.LightShader:send("Radius", self.Radius)
			Shadows.LightShader:send("Center", {self.Radius, self.Radius, self.z})
			
			local Arc = math.rad(self.Arc / 2)
			local Angle = math.rad(self.Angle) - math.pi/2
			
			love.graphics.setShader(Shadows.LightShader)
			love.graphics.setBlendMode("alpha", "premultiplied")
			
			love.graphics.setColor(self.R, self.G, self.B, self.A)
			love.graphics.arc("fill", self.Radius, self.Radius, self.Radius, Angle - Arc, Angle + Arc)
			
			love.graphics.setShader()
			
		end
		
		love.graphics.setBlendMode("multiply", "premultiplied")
		love.graphics.draw(self.ShadowCanvas, 0, 0)
		
		love.graphics.setBlendMode("alpha", "alphamultiply")
		love.graphics.origin()
		love.graphics.setCanvas()
		love.graphics.setShader()
		
		self.Changed = nil
		self.World.UpdateCanvas = true
		
	end
	
end

function Light:SetAngle(Angle)
	
	if type(Angle) == "number" and Angle ~= self.Angle then
		
		self.Angle = Angle
		self.Changed = true
		
	end
	
	return self
	
end

function Light:GetAngle()
	
	return self.Angle
	
end

function Light:SetPosition(x, y, z)
	
	if x ~= self.x then
		self.x = x
		self.Changed = true
	end
	
	if y ~= self.y then
		self.y = y
		self.Changed = true
	end
	
	if z and z ~= self.z then
		self.z = z
		self.Changed = true
	end
	
	return self
	
end

function Light:GetPosition()
	
	return self.x, self.y, self.z
	
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
		
		self.Image = Image
		self.Radius = math.sqrt( Image:getWidth() ^ 2 + Image:getHeight() ^ 2 ) / 2
		self.Canvas = love.graphics.newCanvas(self.Radius * 2, self.Radius * 2)
		self.ShadowCanvas = love.graphics.newCanvas(self.Radius * 2, self.Radius * 2)
		self.Changed = true
		
	end
	
end

function Light:GetImage()
	
	return self.Image
	
end

function Light:SetRadius(Radius)
	
	if Radius ~= self.Radius then
		
		self.Radius = Radius
		self.Canvas = love.graphics.newCanvas(self.Radius * 2, self.Radius * 2)
		self.ShadowCanvas = love.graphics.newCanvas(self.Radius * 2, self.Radius * 2)
		self.Changed = true
		
	end
	
end

function Light:GetRadius()
	
	return self.Radius
	
end

function Light:Remove()
	
	if self.Star then
		self.World.Stars[self.ID] = nil
	else
		self.World.Lights[self.ID] = nil
	end
	
end