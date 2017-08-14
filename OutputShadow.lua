module("shadows.OutputShadow", package.seeall)

Object = require("shadows.Object")

OutputShadow = setmetatable( {}, Object )
OutputShadow.__index = OutputShadow
OutputShadow.__type = "OutputShadow"

OutputShadow.Type = "draw"

function OutputShadow:new(Type, Mode, ...)
	
	local self = setmetatable( {}, OutputShadow )
	
	self.ShaderValue = {}
	
	self:SetType(Type)
	self:SetMode(Mode)
	self:Pack(...)
	
	return self
	
end

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

function OutputShadow:SetShader(Shader)
	
	self.Shader = Shader
	
end

function OutputShadow:GetShader()
	
	return self.Shader
	
end

function OutputShadow:SendShader(Variable, Value)
	
	self.ShaderValue[Variable] = Value
	
end

function OutputShadow:SetType(Type)
	
	self.Type = Type
	
end

function OutputShadow:GetType()
	
	return self.Type
	
end

function OutputShadow:Pack(...)
	
	self.Input = {...}
	
end

function OutputShadow:UnPack()
	
	return unpack(self.Input)
	
end

function OutputShadow:SetMode(Mode)
	
	self.Mode = Mode
	
end

function OutputShadow:GetMode()
	
	return self.Mode
	
end

function OutputShadow:SetLayer(Layer)
	
	self.Layer = Layer
	
end

function OutputShadow:GetLayer()
	
	return self.Layer
	
end

return OutputShadow