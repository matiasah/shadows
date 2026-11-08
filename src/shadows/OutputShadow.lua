--- Stores a deferred LÖVE draw call with optional shader state and layer filtering.
module("shadows.OutputShadow", package.seeall)

Object = require("shadows.Object")

--- @class OutputShadow: Object
--- @field Shader love.Shader? Shader applied before drawing.
--- @field ShaderValue table Values sent to the shader before drawing.
--- @field Type string love.graphics drawing function name; defaults to "draw".
--- @field Input table Packed drawing arguments.
--- @field Mode string? Optional first argument to the drawing function.
--- @field Layer number? Layer on which this draw call is emitted.
OutputShadow = setmetatable({}, Object)
OutputShadow.__index = OutputShadow
OutputShadow.__type = "OutputShadow"

OutputShadow.Type = "draw"

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
--- @return nil
function OutputShadow:SetShader(Shader)
	self.Shader = Shader
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
--- @param Type string Operation name.
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
