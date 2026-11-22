---@module Stores deferred LÖVE draws with shader state, layer filtering, and conservative projected bounds.
module("shadows.OutputShadow", package.seeall)

Object = require("shadows.Object")
local Shadows = require("shadows")
local DPI = require("shadows.DPI")

--- @class OutputShadow: Object
--- @field Shader love.Shader? Shader applied before drawing.
--- @field ShaderValue table Values sent to the shader before drawing.
--- @field Type string love.graphics drawing function name; defaults to "draw".
--- @field Input table Packed drawing arguments.
--- @field Mode string? Optional first argument to the drawing function.
--- @field Layer number? Layer on which this draw call is emitted.
--- @field ShaderBoundsSafe boolean? Whether a custom shader preserves ordinary vertex bounds; defaults to nil.
--- @field private __index OutputShadow Instance method lookup.
--- @field private __type string Runtime type name.
OutputShadow = setmetatable({}, Object)
OutputShadow.__index = OutputShadow
OutputShadow.__type = "OutputShadow"

OutputShadow.Type = "draw"

---@description Tests whether a coordinate can produce reliable finite geometry bounds.
---@param value any Coordinate or drawing parameter.
---@return boolean finite Whether the value is a finite number.
local function isFinite(value)
	return type(value) == "number" and value > -math.huge and value < math.huge
end

--- @description Creates a deferred draw call and stores its arguments.
--- @param Type string? love.graphics operation; pass nil to use the default draw operation.
--- @param Mode string? Optional mode argument, such as "fill".
--- @param ... any Drawing arguments passed to the selected LÖVE function.
--- @return OutputShadow output New draw call.
function OutputShadow:new(Type, Mode, ...)
	local self = setmetatable({}, OutputShadow)

	self.ShaderValue = {}

	self:SetType(Type)
	self:SetMode(Mode)
	self:Pack(...)

	return self
end

---@description Returns world-space bounds for supported filled primitives and ordinary texture draws, without caching mutable arguments.
---@return number? minX Left bound; nil for unsupported operations, stroke modes, or untrusted vertex shaders.
---@return number? minY Top bound.
---@return number? maxX Right bound.
---@return number? maxY Bottom bound.
function OutputShadow:GetBounds()
	if self.Shader and not self.ShaderBoundsSafe
		and self.Shader ~= Shadows.HeightShader and self.Shader ~= Shadows.NormalShader then
		return nil
	end
	local input = self.Input
	if self.Type == "polygon" and self.Mode == "fill" then
		local vertices = type(input[1]) == "table" and input[1] or input
		if #vertices < 6 or #vertices % 2 ~= 0 then return nil end
		local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
		for i = 1, #vertices, 2 do
			local x, y = vertices[i], vertices[i + 1]
			if not isFinite(x) or not isFinite(y) then return nil end
			minX, minY = math.min(minX, x), math.min(minY, y)
			maxX, maxY = math.max(maxX, x), math.max(maxY, y)
		end
		return minX, minY, maxX, maxY
	elseif self.Type == "circle" and self.Mode == "fill" then
		local x, y, radius = input[1], input[2], input[3]
		if not isFinite(x) or not isFinite(y) or not isFinite(radius) or radius < 0 then return nil end
		return x - radius, y - radius, x + radius, y + radius
	elseif self.Type == "rectangle" and self.Mode == "fill" then
		local x, y, width, height = input[1], input[2], input[3], input[4]
		if not isFinite(x) or not isFinite(y) or not isFinite(width) or not isFinite(height) then return nil end
		return math.min(x, x + width), math.min(y, y + height),
			math.max(x, x + width), math.max(y, y + height)
	elseif self.Type == "draw" and not self.Mode then
		local texture = input[1]
		if type(texture) ~= "userdata" or not texture:typeOf("Texture")
			or texture:getTextureType() ~= "2d" then return nil end
		for i = 2, 10 do
			if input[i] ~= nil and not isFinite(input[i]) then return nil end
		end
		local transform = love.math.newTransform(input[2] or 0, input[3] or 0, input[4] or 0,
			input[5] or 1, input[6] or input[5] or 1, input[7] or 0, input[8] or 0,
			input[9] or 0, input[10] or 0)
		local width, height = texture:getDimensions()
		local ax, ay = transform:transformPoint(0, 0)
		local bx, by = transform:transformPoint(width, 0)
		local cx, cy = transform:transformPoint(width, height)
		local dx, dy = transform:transformPoint(0, height)
		return math.min(ax, bx, cx, dx), math.min(ay, by, cy, dy),
			math.max(ax, bx, cx, dx), math.max(ay, by, cy, dy)
	end
	return nil
end

---@description Conservatively tests projected draw bounds against a canvas under the active graphics transform.
---@param Canvas love.Canvas Shadow render target, whose logical dimensions and DPI determine clipping and raster padding.
---@return boolean visible Whether to submit the draw; unknown bounds are retained.
function OutputShadow:IsVisible(Canvas)
	local minX, minY, maxX, maxY = self:GetBounds()
	if minX == nil then return true end
	local ax, ay = love.graphics.transformPoint(minX, minY)
	local bx, by = love.graphics.transformPoint(maxX, minY)
	local cx, cy = love.graphics.transformPoint(maxX, maxY)
	local dx, dy = love.graphics.transformPoint(minX, maxY)
	local left, top = math.min(ax, bx, cx, dx), math.min(ay, by, cy, dy)
	local right, bottom = math.max(ax, bx, cx, dx), math.max(ay, by, cy, dy)
	if not isFinite(left) or not isFinite(top) or not isFinite(right) or not isFinite(bottom) then
		return true
	end
	local width, height = Canvas:getDimensions()
	local padding = 2 / DPI.getCanvasScale(Canvas)
	return right >= -padding and bottom >= -padding
		and left <= width + padding and top <= height + padding
end

--- @description Applies stored shader uniforms and draws when the requested layer matches.
--- @param Layer number? Layer being rendered.
--- @return nil
function OutputShadow:Draw(Layer)
	if not self.Layer or self.Layer == Layer then
		if self.Shader then
			for Variable, Value in pairs(self.ShaderValue) do
				self.Shader:send(Variable, Value)
			end
		end

		love.graphics.setShader(self.Shader)

		if self.Mode then
			love.graphics[self.Type](self.Mode, self:UnPack())
		else
			love.graphics[self.Type](self:UnPack())
		end
	end
end

--- @description Sets the shader used by this draw call.
--- @param Shader love.Shader? Shader to apply.
--- @param BoundsSafe boolean? Whether custom shader vertices remain inside ordinary draw bounds; defaults to false.
--- @return nil
function OutputShadow:SetShader(Shader, BoundsSafe)
	assert(BoundsSafe == nil or type(BoundsSafe) == "boolean", "Shader bounds safety must be a boolean or nil")
	self.Shader = Shader
	self.ShaderBoundsSafe = BoundsSafe
end

--- @description Returns the shader used by this draw call.
--- @return love.Shader? shader Configured shader.
function OutputShadow:GetShader()
	return self.Shader
end

--- @description Queues a shader uniform value for the next draw.
--- @param Variable string Uniform name.
--- @param Value any Uniform value accepted by the shader.
--- @return nil
function OutputShadow:SendShader(Variable, Value)
	self.ShaderValue[Variable] = Value
end

--- @description Sets the love.graphics operation used by this draw call.
--- @param Type string? Operation name; nil uses the default draw operation.
--- @return nil
function OutputShadow:SetType(Type)
	self.Type = Type
end

--- @description Returns the love.graphics operation used by this draw call.
--- @return string type Operation name.
function OutputShadow:GetType()
	return self.Type
end

--- @description Replaces the packed drawing arguments.
--- @param ... any Arguments passed to the drawing operation.
--- @return nil
function OutputShadow:Pack(...)
	self.Input = { ... }
end

--- @description Returns the packed drawing arguments.
--- @return any ... Stored arguments.
function OutputShadow:UnPack()
	return unpack(self.Input)
end

--- @description Sets the optional drawing mode.
--- @param Mode string? Mode argument, or nil to omit it.
--- @return nil
function OutputShadow:SetMode(Mode)
	self.Mode = Mode
end

--- @description Returns the optional drawing mode.
--- @return string? mode Configured mode.
function OutputShadow:GetMode()
	return self.Mode
end

--- @description Sets the optional layer filter.
--- @param Layer number? Layer to draw on, or nil to draw on every layer.
--- @return nil
function OutputShadow:SetLayer(Layer)
	self.Layer = Layer
end

--- @description Returns the optional layer filter.
--- @return number? layer Configured layer.
function OutputShadow:GetLayer()
	return self.Layer
end

return OutputShadow
