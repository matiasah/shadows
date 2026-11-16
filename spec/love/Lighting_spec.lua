---@module Tests real light pixels and incremental shadow caching inside LOVE.
---@diagnostic disable: undefined-global
local LightWorld = require("shadows.LightWorld")
local Light = require("shadows.Light")
local Body = require("shadows.Body")
local CircleShadow = require("shadows.ShadowShapes.CircleShadow")

describe("LOVE lighting",
    ---@description Defines first-update rendering and incremental cache regressions.
    ---@return nil
    function()
        local world, light, body
        local shadowRenders

        before_each(
            ---@description Creates an isolated hard-shadow scene and records shadow canvas redraws.
            ---@return nil
            function()
                love.graphics.push("all")
                love.graphics.reset()
                world = LightWorld:new()
                light = Light:new(world, 112)
                light.Blur = false
                light:SetPosition(80, 96, 2)
                body = Body:new(world)
                body:SetPosition(112, 96, 1)
                CircleShadow:new(body, 0, 0, 10)
                shadowRenders = 0
                local render = light.RenderShadowCanvas
                ---@description Counts actual shadow rasterizations before invoking the original renderer.
                ---@param self Light Light being rendered.
                ---@param x number Light x-coordinate.
                ---@param y number Light y-coordinate.
                ---@param z number Light height.
                ---@return nil
                function light:RenderShadowCanvas(x, y, z)
                    shadowRenders = shadowRenders + 1
                    render(self, x, y, z)
                end
            end)

        after_each(
            ---@description Restores caller graphics state even when a test fails.
            ---@return nil
            function()
                love.graphics.setCanvas()
                love.graphics.pop()
                world, light, body = nil, nil, nil
                collectgarbage("collect")
            end)

        it("renders a visible shadow on the first update",
            ---@description Measures occlusion against an equally distant unobstructed pixel and saves the render.
            ---@return nil
            function()
                world:Update(0)
                local pixels = world.Canvas:newImageData()
                assert(love.filesystem.createDirectory("screenshots"))
                pixels:encode("png", "screenshots/first-update-shadow.png")
                local shadow = pixels:getPixel(136, 96)
                local clear = pixels:getPixel(80, 152)
                assert.is_true(clear > 0.1, "The unobstructed sample must contain light")
                assert.is_true(clear - shadow > 0.08, "The caster must darken its projected shadow on the first update")
                assert.equals(1, shadowRenders)
            end)

        it("reuses shadows for stationary and color-only updates",
            ---@description Checks color changes alter illumination without rerasterizing occluders.
            ---@return nil
            function()
                world:Update(0)
                local before = world.Canvas:newImageData():getPixel(80, 152)
                world:Update(0)
                assert.equals(1, shadowRenders)
                light:SetColor(0.25, 0.5, 1, 1)
                world:Update(0)
                assert.equals(1, shadowRenders)
                local after = world.Canvas:newImageData():getPixel(80, 152)
                assert.is_true(before - after > 0.08, "The new tint must reach the composed world")
            end)

        it("matches forced rebuilds after a body moves",
            ---@description Compares every rendered pixel after incremental invalidation and a full rebuild.
            ---@return nil
            function()
                world:Update(0)
                body:SetPosition(112, 120, 1)
                world:Update(0)
                assert.equals(2, shadowRenders)
                local incremental = world.Canvas:newImageData():getString()
                world:ForceUpdate()
                world:Update(0)
                assert.equals(3, shadowRenders)
                assert.is_true(incremental == world.Canvas:newImageData():getString(),
                    "Incremental pixels must match the full rebuild")
            end)

        it("updates soft-shadow footprints without rebuilding shadow geometry",
            ---@description Verifies radius-only edits reuse the distance field and hard-shadow controls release it.
            ---@return nil
            function()
                light.Blur = true
                world:Update(0)
                assert.is_not_nil(light.Penumbra)
                local filtering = light.Penumbra
                local original = world.Canvas:newImageData():getString()
                light.SizeRadius = 20
                world:Update(0)
                assert.equals(1, shadowRenders)
                assert.equals(filtering, light.Penumbra)
                local incremental = world.Canvas:newImageData():getString()
                assert.is_true(original ~= incremental, "The larger source must change the rendered penumbra")
                world:ForceUpdate()
                world:Update(0)
                assert.is_true(incremental == world.Canvas:newImageData():getString(),
                    "Updated filter pixels must match the full rebuild")
                light.SizeRadius = 0
                world:Update(0)
                assert.is_nil(light.Penumbra)
            end)
    end)
