--- Adds geometry and image-shadow helpers to the shared Shädows module table.
module("shadows.Functions", package.seeall)

---@type Shadows
Shadows = require("shadows")
Shaders = require("shadows.Shaders")

local sqrt = math.sqrt
local min = math.min
local max = math.max

--- @description Returns a normalized two-dimensional vector.
--- @param v number[] Vector as {x, y}.
--- @return number[] normalized Unit vector as {x, y}.
function Shadows.Normalize(v)
	local LengthFactor = 1 / sqrt(v[1] * v[1] + v[2] * v[2])

	return {

		v[1] * LengthFactor,
		v[2] * LengthFactor

	}
end

--- @description Tests whether a point lies inside a polygon using its flat coordinate array.
--- @param x number Point x-coordinate.
--- @param y number Point y-coordinate.
--- @param Vertices number[] Polygon coordinates as alternating x/y values.
--- @return boolean inside Whether the point is inside the polygon.
function Shadows.PointInPolygon(x, y, Vertices)
	local Intersects = false
	local j = #Vertices - 1

	for i = 1, #Vertices, 2 do
		if Vertices[i + 1] < y and Vertices[j + 1] >= y or Vertices[j + 1] < y and Vertices[i + 1] >= y then
			if Vertices[i] + (y - Vertices[i + 1]) / (Vertices[j + 1] - Vertices[i + 1]) * (Vertices[j] - Vertices[i]) < x then
				Intersects = not Intersects
			end
		end

		j = i
	end

	return Intersects
end

--- @description Sorts an array in place using the values' less-than operator.
--- @param Table table Array to sort.
--- @return nil
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

--- @description Inserts a value at an index, or appends Index when Value is omitted.
--- @param Table table Array to modify.
--- @param Index integer Insertion index, or value to append when Value is omitted.
--- @param Value any? Value to insert at Index.
--- @return nil
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

--- @description Renders and returns a canvas containing drop shadows derived from image data.
--- @param ImageData love.ImageData Source image data.
--- @param LightX number Light x-coordinate.
--- @param LightY number Light y-coordinate.
--- @param LightZ number Light height.
--- @param LightRadius number Light radius.
--- @param TextureZ number Source image height.
--- @param LightRadiusMult number? Shadow-radius multiplier; defaults to 2.
--- @return love.Canvas canvas Rendered shadow canvas.
function Shadows.newDropshadowsFromImageData(ImageData, LightX, LightY, LightZ, LightRadius, TextureZ, LightRadiusMult)
	local width, height = ImageData:getDimensions()
	local scale         = LightZ / (LightZ - TextureZ)
	local canvasWidth   = math.ceil(width * scale)
	local canvasHeight  = math.ceil(height * scale)
	local canvas        = love.graphics.newCanvas(canvasWidth, canvasHeight)

	Shaders.DropShadows:send("DpiScale", require("shadows.DPI").getCanvasScale(canvas))
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
