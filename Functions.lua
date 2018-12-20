module("shadows.Functions", package.seeall)

Shadows = require("shadows")
Shaders = require("shadows.Shaders")

local sqrt = math.sqrt
local min = math.min
local max = math.max

function Shadows.Normalize(v)
	
	local LengthFactor = 1 / sqrt( v[1] * v[1] + v[2] * v[2] )
	
	return {
		
		v[1] * LengthFactor,
		v[2] * LengthFactor
		
	}
	
end

function Shadows.PointInPolygon(x, y, Vertices)
	
	local Intersects = false
	local j = #Vertices - 1
	
	for i = 1, #Vertices, 2 do
		
		if Vertices[i + 1] < y and Vertices[j + 1] >= y or Vertices[j + 1] < y and Vertices[i + 1] >= y then
			
			if Vertices[i] + ( y - Vertices[i + 1] ) / (Vertices[j + 1] - Vertices[i + 1]) * (Vertices[j] - Vertices[i]) < x then
				
				Intersects = not Intersects
				
			end
			
		end
		
		j = i
		
	end
	
	return Intersects
end

function Shadows.insertionSort(Table)
	
	local Length = #Table
	
	for j = 2, Length do
		
		local Aux = Table[j]
		local i = j - 1
		
		while i > 0 and Table[j] > Aux do
			
			Table[i + 1] = Table[i]
			i = i - 1
			
		end
		
		Table[i + 1] = Aux
		
	end
	
end

function Shadows.Insert(Table, Index, Value)
	
	if Value then
		
		for i = #Table, Index, -1 do
			
			Table[i + 1] = Table[i]
			
		end
		
		Table[Index] = Value
		
	else
		
		Table[#Table + 1] = Index
		
	end
	
end

function Shadows.newDropshadowsFromImageData(ImageData, LightX, LightY, LightZ, LightRadius, TextureZ, LightRadiusMult)
	
	local width, height	= ImageData:getDimensions()
	local scale		= LightZ / ( LightZ - TextureZ )
	local canvasWidth	= math.ceil( width * scale )
	local canvasHeight	= math.ceil( height * scale )
	local canvas		= love.graphics.newCanvas( canvasWidth, canvasHeight )
	
	Shaders.DropShadows:send("lightPosition", { LightX, LightY, LightZ })
	Shaders.DropShadows:send("lightRadius", LightRadius)
	Shaders.DropShadows:send("lightRadiusMult", LightRadiusMult or 2)
	Shaders.DropShadows:send("texure", love.graphics.newImage(ImageData))
	Shaders.DropShadows:send("textureSize", { width - 0.5, height - 0.5 })
	Shaders.DropShadows:send("textureZ", TextureZ)
	
	love.graphics.setCanvas(canvas)
	love.graphics.clear(0, 0, 0, 0)
	
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setShader(Shaders.DropShadows)
	love.graphics.rectangle("fill", 0, 0, canvasWidth, canvasHeight)
	
	love.graphics.setCanvas()
	love.graphics.setShader()
	
	return canvas
	
end