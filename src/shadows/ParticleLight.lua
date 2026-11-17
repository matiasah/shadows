---@module Provides animated local illumination from a LOVE particle system.
local Light = require("shadows.Light")

---@class ParticleLight:Light
---@field ParticleSystem love.ParticleSystem Particle emitter owned and advanced by this light.
---@field private __index ParticleLight Instance method lookup.
---@field private __type string Runtime type name.
local ParticleLight = setmetatable({}, Light)
ParticleLight.__index = ParticleLight
ParticleLight.__type = "ParticleLight"

---@description Registers a particle light with inherited Light defaults and a bounded canvas.
---@param World LightWorld Owning world.
---@param Radius number Canvas half-size and shadow influence radius in world units.
---@param ParticleSystem love.ParticleSystem Emitter in light-local coordinates, centered at (0, 0).
---@return ParticleLight light New particle light.
function ParticleLight:new(World, Radius, ParticleSystem)
    assert(World, "ParticleLight requires a world")
    assert(type(Radius) == "number" and Radius > 0 and Radius < math.huge,
        "ParticleLight radius must be a finite positive number")
    assert(ParticleSystem and ParticleSystem:typeOf("ParticleSystem"),
        "ParticleLight requires a LOVE ParticleSystem")
    local light = setmetatable(Light:new(World, Radius), ParticleLight)
    light.ParticleSystem = ParticleSystem
    return light
end

---@description Advances particles even offscreen and refreshes illumination without invalidating shadows.
---@param dt number? Elapsed seconds; omitted dt leaves simulation to the caller.
---@return nil
function ParticleLight:Update(dt)
    if dt ~= nil then
        assert(type(dt) == "number" and dt >= 0 and dt < math.huge,
            "ParticleLight dt must be a finite nonnegative number")
        self.ParticleSystem:update(dt)
    end
    self.AppearanceChanged = true
    Light.Update(self)
end

---@description Draws additive particles before inherited shadow filtering and composition.
---@param z number Light height; unused by the particle renderer.
---@return nil
function ParticleLight:DrawLight(z)
    -- Additive blending preserves destination alpha; world composition needs opaque light pixels.
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setBlendMode("add", "alphamultiply")
    love.graphics.setColor(self.R, self.G, self.B, self.A)
    love.graphics.draw(self.ParticleSystem, self.Radius, self.Radius,
        math.rad(self:GetAngle()))
end

---@description Replaces the emitter without rebuilding shadow geometry.
---@param ParticleSystem love.ParticleSystem Replacement emitter in light-local coordinates.
---@return ParticleLight light This light, for chaining.
function ParticleLight:SetParticleSystem(ParticleSystem)
    assert(ParticleSystem and ParticleSystem:typeOf("ParticleSystem"),
        "ParticleLight requires a LOVE ParticleSystem")
    self.ParticleSystem = ParticleSystem
    self.AppearanceChanged = true
    return self
end

---@description Returns the emitter for configuration, emission, or external simulation.
---@return love.ParticleSystem particles Attached particle system.
function ParticleLight:GetParticleSystem()
    return self.ParticleSystem
end

return ParticleLight
