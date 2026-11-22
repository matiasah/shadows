---@module Tests particle illumination, simulation ownership, and cached emitter shadows inside LOVE.
---@diagnostic disable: undefined-global
local LightWorld = require("shadows.LightWorld")
local LightCamera = require("shadows.LightCamera")
local ParticleLight = require("shadows.ParticleLight")
local Body = require("shadows.Body")
local CircleShadow = require("shadows.ShadowShapes.CircleShadow")

describe("Particle lights",
    ---@description Defines real-pixel and lifecycle regressions.
    ---@return nil
    function()
        local world, light, particles
        local shadowRenders

        before_each(
            ---@description Creates a deterministic broad particle and an emitter-centered shadow caster.
            ---@return nil
            function()
                love.graphics.push("all")
                love.graphics.reset()
                world = LightWorld:new()
                local data = love.image.newImageData(128, 128)
                data:mapPixel(
                    ---@description Supplies an opaque white illumination texture.
                    ---@param x number Pixel x-coordinate.
                    ---@param y number Pixel y-coordinate.
                    ---@return number r Red channel.
                    ---@return number g Green channel.
                    ---@return number b Blue channel.
                    ---@return number a Alpha channel.
                    function(x, y) return 1, 1, 1, 1 end)
                particles = love.graphics.newParticleSystem(love.graphics.newImage(data), 4)
                particles:setParticleLifetime(2)
                particles:setColors(1, 1, 1, 0.6)
                particles:setSpeed(20)
                particles:setDirection(0)
                particles:emit(1)
                light = ParticleLight:new(world, 112, particles)
                light.Blur = false
                light:SetPosition(80, 96, 2)
                local body = Body:new(world)
                body:SetPosition(112, 96, 1)
                CircleShadow:new(body, 0, 0, 10)
                shadowRenders = 0
                local render = light.RenderShadowCanvas
                ---@description Counts shadow rasterizations independently from illumination updates.
                ---@param self ParticleLight Light being rendered.
                ---@param x number Emitter x-coordinate.
                ---@param y number Emitter y-coordinate.
                ---@param z number Emitter height.
                ---@return nil
                function light:RenderShadowCanvas(x, y, z)
                    shadowRenders = shadowRenders + 1
                    render(self, x, y, z)
                end
            end)

        after_each(
            ---@description Restores graphics state and releases test references.
            ---@return nil
            function()
                love.graphics.setCanvas()
                love.graphics.pop()
                world, light, particles = nil, nil, nil
                collectgarbage("collect")
            end)

        it("casts shadows through particle illumination at DPI scales 1 and 2",
            ---@description Checks actual lit and occluded pixels and forced-rebuild equality.
            ---@return nil
            function()
                for _, scale in ipairs({ 1, 2 }) do
                    light:DestroyCanvas()
                    light:InitCanvas()
                    light.Canvas = love.graphics.newCanvas(224, 224, { dpiscale = scale })
                    world:Update(0)
                    local pixels = light.Canvas:newImageData()
                    local shadow = pixels:getPixel(168 * scale, 112 * scale)
                    local clear = pixels:getPixel(112 * scale, 168 * scale)
                    assert.is_true(clear > 0.4, "Particles must illuminate the canvas")
                    assert.is_true(clear - shadow > 0.3, "Emitter shadows must mask particles")
                    local before = pixels:getString()
                    world:ForceUpdate()
                    world:Update(0)
                    assert.equals(before, light.Canvas:newImageData():getString())
                end
            end)

        it("animates and tints particles without rebuilding shadows",
            ---@description Verifies dt propagation, tint alpha, external simulation, and geometry cache reuse.
            ---@return nil
            function()
                world:Update(0)
                local original = world.Canvas:newImageData():getString()
                world:Update()
                assert.equals(original, world.Canvas:newImageData():getString())
                world:Update(0.25)
                assert.is_true(original ~= world.Canvas:newImageData():getString())
                local animated = world.Canvas:newImageData():getString()
                particles:update(0.25)
                world:Update()
                assert.is_true(animated ~= world.Canvas:newImageData():getString(),
                    "External particle simulation must refresh illumination without dt")
                light:SetColor(0.25, 0.5, 1, 0.5)
                world:Update(0)
                local r, g, b = world.Canvas:newImageData():getPixel(80, 140)
                assert.is_true(b > g and g > r and b < 0.4, "Tint and alpha must reach particle pixels")
                assert.equals(1, shadowRenders)
            end)

        it("ages offscreen particles and removes expired illumination",
            ---@description Prevents frozen offscreen emitters and stale pixels after particles die.
            ---@return nil
            function()
                light:SetPosition(-10000, 0, 2)
                world:Update(3)
                assert.equals(0, particles:getCount())
                assert.is_true(light:GetCanvasDestroyed())
                light:SetPosition(80, 96, 2)
                world:Update(0)
                assert.equals(0, world.Canvas:newImageData():getPixel(80, 140))
                local replacement = particles:clone()
                replacement:start()
                replacement:emit(1)
                light:SetParticleSystem(replacement)
                world:Update(0)
                assert.equals(replacement, light:GetParticleSystem())
                assert.is_true(world.Canvas:newImageData():getPixel(80, 140) > 0.4)
                light:Remove()
                world:Update(0)
                assert.equals(0, world.Canvas:newImageData():getPixel(80, 140))
            end)

        it("advances simulation only once when multiple cameras render the same world",
            ---@description Ensures view updates and repeated draws do not multiply particle aging.
            ---@return nil
            function()
                local first = LightCamera:new(world, 192, 192)
                local second = LightCamera:new(world, 192, 192)
                second:SetPosition(32, 32, 2)
                particles:reset()
                particles:setParticleLifetime(0.3)
                particles:emit(1)
                world:Update(0.2)
                assert.equals(1, particles:getCount())
                assert.equals(1, shadowRenders)
                first:Draw()
                second:Draw()
                first:Draw()
                assert.equals(1, particles:getCount(), "Drawing cannot advance particles")
                world:Update(0.2)
                assert.equals(0, particles:getCount())
            end)

        it("retains illumination at square canvas corners outside the emitter's radius",
            ---@description Checks conservative cache and submission culling with translated, zoomed corner-only views.
            ---@return nil
            function()
                particles:reset()
                particles:setSpeed(0)
                particles:setEmissionArea("uniform", 0, 0)
                particles:setPosition(90, 90)
                particles:emit(1)
                local primary = world:GetCamera()
                primary:Resize(32, 32)
                primary:SetPosition(180, 196, 2)
                local camera = LightCamera:new(world, 32, 32)
                camera:SetPosition(1000, 1000)
                assert.is_false(primary:IsVisible(80, 96, light.Radius),
                    "This viewport must intersect only the square canvas corner, not the influence circle")
                world:Update(0)
                assert.is_false(light:GetCanvasDestroyed())
                assert.equals(1, primary.FrameMetrics.LightsComposited)
                assert.equals(0, camera.FrameMetrics.LightsComposited)
                assert.is_true(primary.Canvas:newImageData():getPixel(4, 4) > 0.4)
                local before = primary.Canvas:newImageData():getString()
                world:ForceUpdate()
                world:Update(0)
                assert.equals(before, primary.Canvas:newImageData():getString())
                assert.equals(0, camera.FrameMetrics.CompositionMs)
            end)
    end)
