---@module Tests real light pixels and incremental shadow caching inside LOVE.
---@diagnostic disable: undefined-global
local LightWorld = require("shadows.LightWorld")
local LightCamera = require("shadows.LightCamera")
local Light = require("shadows.Light")
local Star = require("shadows.Star")
local Body = require("shadows.Body")
local CircleShadow = require("shadows.ShadowShapes.CircleShadow")
local PolygonShadow = require("shadows.ShadowShapes.PolygonShadow")

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

        it("keeps soft shadows attached to polygon casters for local lights and stars",
            ---@description Compares hard and soft visibility at the caster contact and on the lit face.
            ---@return nil
            function()
                body:GetShapes():Get(1):Remove()
                PolygonShadow:new(body, -10, -10, 10, -10, 10, 10, -10, 10)
                local star = Star:new(world, 112)
                star:SetPosition(80, 96, 2)
                star.Blur = false
                world:Update(0)
                local localHard = light.Canvas:newImageData()
                local starHard = star.Canvas:newImageData()
                light.Blur, star.Blur = true, true
                world:Update(0)
                local localSoft = light.Canvas:newImageData()
                local starSoft = star.Canvas:newImageData()

                for _, sample in ipairs({
                    { localHard, localSoft, 155, 112 },
                    { starHard, starSoft, 123, 96 },
                }) do
                    local hard = sample[1]:getPixel(sample[3], sample[4])
                    local soft = sample[2]:getPixel(sample[3], sample[4])
                    assert.is_true(hard < 0.01 and soft < 0.01,
                        string.format("Shadow contact must remain dark: hard %.3f soft %.3f", hard, soft))
                    local hardFace = sample[1]:getPixel(sample[3] - 5, sample[4])
                    local softFace = sample[2]:getPixel(sample[3] - 5, sample[4])
                    assert.is_true(hardFace > 0.1 and math.abs(hardFace - softFace) < 0.01,
                        "Filtering must preserve the illuminated caster face")
                end
            end)

        it("applies quality presets and per-world overrides to rendering buffers",
            ---@description Checks shadow resolution, MSAA, and penumbra-buffer resolution.
            ---@return nil
            function()
                light.Blur = true
                assert.equals(world.Settings, light.Settings)
                assert.equals(world.Settings, world:GetSettings())
                local otherWorld = LightWorld:new()
                assert.is_true(otherWorld.Settings ~= world.Settings)
                world.Settings:SetQuality("low")
                local otherQuality, otherScale = otherWorld.Settings:GetQuality()
                assert.equals("high", otherQuality)
                assert.equals(1, otherScale)
                world:Update(0)

                assert.equals(0.5, world.Canvas:getDPIScale())
                assert.equals(0.5, light.ShadowCanvas:getDPIScale())
                assert.equals(0, light.ShadowRenderCanvas:getMSAA())
                assert.equals(0.25, light.Penumbra.Mask:getDPIScale())

                world:SetQuality("medium", {
                    ShadowScale = 1,
                    ShadowMSAA = 4,
                    PenumbraScale = 0.5,
                })
                world:Update(0)

                assert.equals(1, world.Canvas:getDPIScale())
                assert.equals(1, light.ShadowCanvas:getDPIScale())
                assert.equals(4, light.ShadowRenderCanvas:getMSAA())
                assert.equals(0.5, light.Penumbra.Mask:getDPIScale())
            end)

        it("rejects invalid quality overrides without changing the current settings",
            ---@description Verifies invalid per-world settings fail before reallocating canvases.
            ---@return nil
            function()
                local canvas = world.Canvas
                assert.has_error(
                    ---@description Rejects a zero rendering-resolution override.
                    ---@return nil
                    function()
                        world:SetQuality("low", { ShadowScale = 0 })
                    end, "ShadowScale must be a finite number greater than 0 and at most 1")
                assert.has_error(
                    ---@description Rejects fractional multisample counts.
                    ---@return nil
                    function()
                        world:SetQuality("high", { ShadowMSAA = 1.5 })
                    end, "ShadowMSAA must be a finite nonnegative integer")
                local quality, shadowScale = world.Settings:GetQuality()
                assert.equals("high", quality)
                assert.equals(1, shadowScale)
                assert.equals(canvas, world.Canvas)
            end)

        it("recreates full-scene star buffers when quality changes",
            ---@description Checks star canvas resolution and penumbra quality invalidation.
            ---@return nil
            function()
                local star = Star:new(world, 200)
                local originalCanvas = star.Canvas
                assert.equals(world.Settings, star.Settings)

                world:SetQuality("low")
                assert.is_true(originalCanvas ~= star.Canvas)
                assert.equals(0.5, star.Canvas:getDPIScale())
                assert.equals(0, star.ShadowRenderCanvas:getMSAA())
                world:Update(0)

                local lowCanvas = star.Canvas
                world:SetQuality("low", { PenumbraScale = 0.25 })
                assert.is_true(lowCanvas ~= star.Canvas)
                assert.equals(0.25, star.RenderPenumbraScale)
                world:Update(0)
            end)

        it("renders independent camera views with shared local lights and per-view star shadows",
            ---@description Compares translated and zoomed views, incremental shape updates, and destination drawing.
            ---@return nil
            function()
                world:Resize(192, 192)
                local camera = LightCamera:new(world, 192, 192)
                camera:SetPosition(32, 32, 2)
                local star = Star:new(world, 112)
                star.Blur = false
                star:SetPosition(80, 96, 2)
                local view = star:GetView(camera)
                local render = view.RenderShadowCanvas
                local viewRenders = 0
                ---@description Counts shadow rasterization for this camera independently of the default view.
                ---@param self Star Camera-specific star renderer.
                ---@param x number Star world x-coordinate.
                ---@param y number Star world y-coordinate.
                ---@param z number Star height.
                ---@return nil
                function view:RenderShadowCanvas(x, y, z)
                    viewRenders = viewRenders + 1
                    render(self, x, y, z)
                end
                world:Update(0)
                assert.equals(world:GetCamera().Canvas, world.Canvas)
                assert.equals(world.Settings, camera.Settings)
                assert.is_true(star.Canvas ~= star:GetView(camera).Canvas)
                local secondary = camera.Canvas:newImageData():getString()
                assert.is_true(secondary ~= world.Canvas:newImageData():getString())
                assert.equals(1, shadowRenders)

                local secondaryShadows = star:GetView(camera).ShadowCanvas:newImageData():getString()
                world:SetPosition(32, 32, 2)
                world:Update(0)
                assert.equals(secondary, world.Canvas:newImageData():getString(),
                    "Identical views must produce identical lighting")
                assert.equals(secondaryShadows, star:GetView(camera).ShadowCanvas:newImageData():getString())
                assert.equals(1, shadowRenders, "Moving a camera must reuse local-light shadows")
                assert.equals(1, viewRenders, "Moving the default camera must not rerender another view's stars")

                body:SetPosition(112, 120, 1)
                world:Update(0)
                local changed = camera.Canvas:newImageData():getString()
                assert.is_true(changed ~= secondary, "Every camera must see shape changes")
                assert.equals(changed, world.Canvas:newImageData():getString())
                assert.equals(2, viewRenders)
                world:ForceUpdate()
                world:Update(0)
                assert.equals(changed, camera.Canvas:newImageData():getString())
                assert.equals(changed, world.Canvas:newImageData():getString())

                local target = love.graphics.newCanvas(416, 192, { dpiscale = 1 })
                love.graphics.setCanvas(target)
                love.graphics.clear(1, 1, 1, 1)
                love.graphics.translate(9, 7)
                love.graphics.setColor(0.2, 0.3, 0.4, 1)
                local color = { love.graphics.getColor() }
                camera:Draw(208, 0)
                assert.same({ 9, 7 }, { love.graphics.transformPoint(0, 0) })
                assert.same(color, { love.graphics.getColor() })
                love.graphics.setCanvas()
                local drawn = target:newImageData()
                assert.equals(1, drawn:getPixel(96, 64), "Drawing must not affect another viewport")
                assert.near(camera.Canvas:newImageData():getPixel(96, 64),
                    drawn:getPixel(304, 64), 0.01)
            end)

        it("keeps lights visible to any camera and culls with world-space zoom bounds",
            ---@description Prevents offscreen cache destruction by another view and checks zoomed-out coverage.
            ---@return nil
            function()
                world:Resize(128, 128)
                local camera = LightCamera:new(world, 192, 192)
                camera:SetPosition(1000, 0)
                light:SetPosition(1080, 96, 2)
                body:SetPosition(1112, 96, 1)
                world:Update(0)
                assert.equals(0, world.Canvas:newImageData():getPixel(80, 96))
                assert.is_true(camera.Canvas:newImageData():getPixel(80, 152) > 0.1)
                local cache = light.Canvas
                camera:SetPosition(1010, 0, 1.5)
                world:Update(0)
                assert.equals(cache, light.Canvas)
                assert.equals(1, shadowRenders)
                camera:Remove()
                world:Update(0)
                assert.is_true(light:GetCanvasDestroyed())
                world:SetPosition(0, 0, 0.1)
                world:Update(0)
                assert.is_false(light:GetCanvasDestroyed(),
                    "Zoomed-out visibility must cover width divided by zoom")
                world:SetPosition(0, 0, 10)
                world:Update(0)
                assert.is_true(light:GetCanvasDestroyed())
            end)

        it("resizes only the requested view and propagates quality and star appearance to all cameras",
            ---@description Verifies compatibility aliases, independent resizing, settings invalidation, and removals.
            ---@return nil
            function()
                world:Resize(192, 192)
                local camera = LightCamera:new(world, 192, 192)
                local star = Star:new(world, 200)
                star:SetPosition(80, 96, 2)
                world:Update(0)
                local otherCanvas = camera.Canvas
                local otherStarCanvas = star:GetView(camera).Canvas
                world:Resize(160, 160)
                assert.equals(otherCanvas, camera.Canvas)
                assert.equals(otherStarCanvas, star:GetView(camera).Canvas)
                camera:Resize(128, 128)
                assert.equals(160, world:GetWidth())
                assert.equals(128, star:GetView(camera).Canvas:getWidth())
                world:SetQuality("low")
                assert.equals(0.5, camera.Canvas:getDPIScale())
                assert.equals(0.5, star:GetView(camera).ShadowCanvas:getDPIScale())
                assert.equals(0, star:GetView(camera).ShadowRenderCanvas:getMSAA())
                world:Update(0)
                local before = camera.Canvas:newImageData():getString()
                star:SetColor(0, 0, 1, 0.5)
                star.SizeRadius = 20
                world:SetColor(0.1, 0, 0, 1)
                world:Update(0)
                assert.is_true(before ~= camera.Canvas:newImageData():getString())
                local incremental = camera.Canvas:newImageData():getString()
                world:ForceUpdate()
                world:Update(0)
                assert.equals(incremental, camera.Canvas:newImageData():getString())
                star:Remove()
                world:Update(0)
                assert.is_true(incremental ~= camera.Canvas:newImageData():getString())
                assert.has_error(
                    ---@description Prevents detaching the compatibility viewport.
                    ---@return nil
                    function() world:GetCamera():Remove() end,
                    "Cannot remove the default LightCamera")
                assert.has_error(
                    ---@description Rejects a zoom that would produce an invalid viewport.
                    ---@return nil
                    function() camera:SetPosition(0, 0, 0) end,
                    "LightCamera scale must be finite and positive")
            end)

        it("translates and scales textured stars with each camera",
            ---@description Measures texture coverage at corresponding world positions in differently zoomed views.
            ---@return nil
            function()
                light:Remove()
                body:Remove()
                world:Resize(192, 192)
                local camera = LightCamera:new(world, 192, 192)
                camera:SetPosition(16, 8, 2)
                local texture = love.graphics.newCanvas(32, 32, { dpiscale = 1 })
                love.graphics.setCanvas(texture)
                love.graphics.clear(1, 1, 1, 1)
                love.graphics.setCanvas()
                local star = Star:new(world, 112)
                star.Blur = false
                star:SetImage(texture)
                star:SetPosition(40, 40, 2)
                world:Update(0)
                local primary = world.Canvas:newImageData()
                local secondary = camera.Canvas:newImageData()
                assert.is_true(primary:getPixel(56, 56) > 0.9)
                assert.is_true(secondary:getPixel(80, 96) > 0.9,
                    "The camera must translate and scale a star's image, not pin it to the viewport")
                assert.equals(0, primary:getPixel(56, 30))
                assert.equals(0, secondary:getPixel(40, 96))
            end)
    end)
