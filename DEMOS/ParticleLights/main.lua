---@module Demonstrates fire, water spray, and sparks illuminating shadow-casting objects.
local capture = require("Capture").new("particle-lights-capture.png")
local LightWorld = require("shadows.LightWorld")
local ParticleLight = require("shadows.ParticleLight")
local Body = require("shadows.Body")
local CircleShadow = require("shadows.ShadowShapes.CircleShadow")
local PolygonShadow = require("shadows.ShadowShapes.PolygonShadow")

---@type LightWorld
local world
---@type ParticleLight[]
local lights = {}
local paused = false
local soft = true
local labels = { "FIRE", "WATER SPRAY", "SPARKS" }
local verify = false
for _, argument in ipairs(arg or {}) do
    if argument == "--verify" then verify = true end
end

---@description Builds an original soft glow texture for the fire and spark emitters.
---@return love.Image image Radially fading white particle.
local function glowTexture()
    local data = love.image.newImageData(64, 64)
    data:mapPixel(
        ---@description Computes a smooth alpha falloff around the texture center.
        ---@param x number Pixel x-coordinate.
        ---@param y number Pixel y-coordinate.
        ---@return number r Red channel.
        ---@return number g Green channel.
        ---@return number b Blue channel.
        ---@return number a Alpha channel.
        function(x, y)
            local distance = math.sqrt((x - 31.5)^2 + (y - 31.5)^2) / 32
            return 1, 1, 1, math.max(0, 1 - distance)^2
        end)
    return love.graphics.newImage(data)
end

---@description Builds a narrow water droplet surrounded by a faint illumination halo.
---@return love.Image image White droplet tinted blue by the water emitter.
local function waterTexture()
    local data = love.image.newImageData(64, 64)
    data:mapPixel(
        ---@description Combines a tapered droplet core with a soft radial halo.
        ---@param x number Pixel x-coordinate.
        ---@param y number Pixel y-coordinate.
        ---@return number r Red channel.
        ---@return number g Green channel.
        ---@return number b Blue channel.
        ---@return number a Alpha channel.
        function(x, y)
            local dx, dy = x - 31.5, y - 31.5
            local width = 3.5 + math.max(-1, math.min(1, dy / 10))
            local drop = math.sqrt((dx / width)^2 + (dy / 10)^2)
            local halo = math.max(0, 1 - math.sqrt(dx^2 + dy^2) / 32)^2
            return 1, 1, 1, math.max(math.max(0, 1 - drop) * 0.95, halo * 0.12)
        end)
    return love.graphics.newImage(data)
end

---@description Measures the vertical center of blue illumination in a water-light canvas.
---@param light ParticleLight Water light to sample.
---@return number y Blue-energy-weighted local y-coordinate.
local function waterCenter(light)
    local pixels = light.Canvas:newImageData()
    local energy, weightedY = 0, 0
    local scale = light.Canvas:getDPIScale()
    for y = 0, pixels:getHeight() - 1 do
        for x = 0, pixels:getWidth() - 1 do
            local r, g, b = pixels:getPixel(x, y)
            local blue = math.max(0, b - math.max(r, g))
            energy = energy + blue
            weightedY = weightedY + blue * (y / scale - light.Radius)
        end
    end
    assert(energy > 1, "Water droplets must produce visibly blue illumination")
    return weightedY / energy
end

---@description Creates three independent emitters and nearby shadow casters.
---@return nil
function love.load()
    world = LightWorld:new()
    world:SetColor(0.035, 0.045, 0.065, 1)
    local texture = glowTexture()
    local droplet = waterTexture()
    for i = 1, 3 do
        local particles = love.graphics.newParticleSystem(texture, 256)
        particles:setParticleLifetime(0.7, 1.5)
        particles:setEmissionRate(65)
        particles:setDirection(-math.pi / 2)
        particles:setSpread(0.65)
        particles:setSpeed(20, 70)
        particles:setSizes(2.6, 1.8, 0.2)
        particles:setColors(1, 0.4, 0.04, 0.8, 1, 0.12, 0.01, 0)
        if i == 2 then
            particles:setTexture(droplet)
            particles:setParticleLifetime(1.35, 1.45)
            particles:setEmissionRate(110)
            particles:setSpread(0.5)
            particles:setSpeed(110, 140)
            particles:setLinearAcceleration(0, 230, 0, 250)
            particles:setRelativeRotation(true)
            particles:setRotation(math.pi / 2)
            particles:setSizes(1.1, 0.9, 0.45)
            particles:setColors(0.15, 0.55, 1, 0.95, 0.3, 0.75, 1, 0.8, 0.1, 0.4, 1, 0)
        elseif i == 3 then
            particles:setDirection(0)
            particles:setSpread(math.pi * 2)
            particles:setSpeed(50, 100)
            particles:setSizes(1.2, 0.9, 0)
            particles:setColors(0.5, 1, 0.2, 0.8, 0.1, 0.7, 0.4, 0)
        end
        local x = 170 + (i - 1) * 310
        local light = ParticleLight:new(world, 150, particles)
        light:SetPosition(x, 340, 2)
        lights[i] = light
        local body = Body:new(world)
        body:SetPosition(x + 32, 310, 0.8)
        CircleShadow:new(body, 0, 0, 12)
        local block = Body:new(world)
        block:SetPosition(x - 35, 360, 0.7)
        PolygonShadow:new(block, -12, -9, 12, -9, 12, 9, -12, 9)
    end
    for _ = 1, 90 do
        for _, light in ipairs(lights) do light:GetParticleSystem():update(1 / 60) end
    end
    world:Update(0)
    if verify then
        local before = {}
        local shadows = {}
        for i, light in ipairs(lights) do
            assert(light:GetParticleSystem():getCount() > 0, "Emitter must contain live particles")
            before[i] = light.Canvas:newImageData():getString()
            shadows[i] = light.ShadowCanvas:newImageData():getString()
        end
        world:Update(0.2)
        for i, light in ipairs(lights) do
            assert(before[i] ~= light.Canvas:newImageData():getString(),
                "Every emitter must animate illumination")
            assert(shadows[i] == light.ShadowCanvas:newImageData():getString(),
                "Particle animation must preserve shadow pixels")
        end
        local water = lights[2]
        local original = water:GetParticleSystem()
        local burst = original:clone()
        burst:setEmissionRate(0)
        burst:emit(24)
        water:SetParticleSystem(burst)
        for _ = 1, 18 do burst:update(1 / 60) end
        world:Update()
        local rising = waterCenter(water)
        for _ = 1, 57 do burst:update(1 / 60) end
        world:Update()
        local falling = waterCenter(water)
        assert(rising < -10 and falling > 0 and falling - rising > 20,
            "Water illumination must rise above the emitter and fall back under gravity")
        water:SetParticleSystem(original)
        world:Update()
        print("ParticleLights verification passed")
    end
end

---@description Advances the emitters unless paused or capturing a prewarmed pose.
---@param dt number Elapsed seconds.
---@return nil
function love.update(dt)
    if not paused and not capture.auto then world:Update(dt) end
end

---@description Draws a tiled surface, its particle illumination, and the controls.
---@return nil
function love.draw()
    love.graphics.clear(0.18, 0.2, 0.25, 1)
    for y = 110, 550, 32 do
        for x = 20, 940, 32 do
            love.graphics.setColor(0.65, 0.68, 0.75, 1)
            love.graphics.rectangle("fill", x, y, 30, 30)
        end
    end
    world:Draw()
    for i = 1, 3 do
        local x = 170 + (i - 1) * 310
        love.graphics.setColor(0.5, 0.53, 0.6, 1)
        love.graphics.circle("fill", x + 32, 310, 12)
        love.graphics.rectangle("fill", x - 47, 351, 24, 18)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(labels[i], x - 130, 450, 260, "center")
        love.graphics.printf(lights[i]:GetParticleSystem():getCount() .. " particles",
            x - 130, 475, 260, "center")
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("PARTICLE LIGHTS | Real ParticleSystem illumination + cached emitter shadows", 24, 24)
    love.graphics.print("Space: pause | B: hard/soft shadows | F12: capture | Escape: exit", 24, 50)
    capture.draw()
end

---@description Handles pause, shadow filtering, and shared screenshot controls.
---@param key string Pressed key.
---@return nil
function love.keypressed(key)
    if key == "space" then
        paused = not paused
    elseif key == "b" then
        soft = not soft
        for _, light in ipairs(lights) do light.Blur = soft end
        world:Update(0)
    end
    capture.keypressed(key)
end

---@description Resizes the composed world canvas with the window.
---@param width number New logical width.
---@param height number New logical height.
---@return nil
function love.resize(width, height)
    if world then
        world:Resize(width, height)
        world:Update(0)
    end
end
