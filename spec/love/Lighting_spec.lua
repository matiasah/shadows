---@module Tests real light pixels and incremental shadow caching inside LOVE.
---@diagnostic disable: undefined-global
local LightWorld = require("shadows.LightWorld")
local LightCamera = require("shadows.LightCamera")
local Light = require("shadows.Light")
local Star = require("shadows.Star")
local Transform = require("shadows.Transform")
local DebugOverlay = require("shadows.DebugOverlay")
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
                assert.equals(0, world:GetCamera().FrameMetrics.LightsComposited)
                assert.equals(1, camera.FrameMetrics.LightsComposited)
                assert.is_true(camera.Canvas:newImageData():getPixel(80, 152) > 0.1)
                local cache = light.Canvas
                camera:SetPosition(1010, 0, 1.5)
                world:Update(0)
                assert.equals(cache, light.Canvas)
                assert.equals(1, shadowRenders)
                assert.equals(0, world:GetCamera().FrameMetrics.CompositionMs)
                camera:Remove()
                world:Update(0)
                assert.is_true(light:GetCanvasDestroyed())
                assert.equals(0, world:GetCamera().FrameMetrics.CompositionMs,
                    "Removing another view must not recompose an unchanged camera")
                world:SetPosition(0, 0, 0.1)
                world:Update(0)
                assert.is_false(light:GetCanvasDestroyed(),
                    "Zoomed-out visibility must cover width divided by zoom")
                world:SetPosition(0, 0, 10)
                world:Update(0)
                assert.is_true(light:GetCanvasDestroyed())
            end)

        it("recomposes only cameras affected by local-light appearance, movement, and removal",
            ---@description Checks old/new visibility invalidation and pixel equality with unculled composition.
            ---@return nil
            function()
                world:Resize(128, 128)
                local primary = world:GetCamera()
                local camera = LightCamera:new(world, 192, 192)
                camera:SetPosition(1000, 0, 1.25)
                light:SetPosition(1080, 96, 2)
                body:SetPosition(1112, 96, 1)
                local nearby = Light:new(world, 48)
                nearby.Blur = false
                nearby:SetPosition(64, 64, 2)
                world:Update(0)
                assert.equals(1, primary.FrameMetrics.LightsComposited)
                assert.equals(1, camera.FrameMetrics.LightsComposited)

                ---@description Compares every pixel against submitting all retained light canvases.
                ---@param view LightCamera Camera whose optimized composition is checked.
                ---@return nil
                local function assertMatchesUnculled(view)
                    local before = view.Canvas:newImageData():getString()
                    local visible, previous = view.IsLightVisible, view.CompositedLights
                    ---@description Disables submission culling to reproduce the previous composition behavior.
                    ---@param candidate Light Local light; unused.
                    ---@return boolean visible Always true.
                    function view:IsLightVisible(candidate) return true end
                    view.UpdateCanvas = true
                    view:Compose()
                    view.IsLightVisible, view.CompositedLights = visible, previous
                    assert.equals(before, view.Canvas:newImageData():getString())
                end
                assertMatchesUnculled(primary)
                assertMatchesUnculled(camera)

                local unchanged = primary.Canvas:newImageData():getString()
                local beforeTint = camera.Canvas:newImageData():getString()
                light:SetColor(0.25, 0.5, 1, 1)
                world:Update(0)
                assert.equals(0, primary.FrameMetrics.CompositionMs)
                assert.equals(0, primary.FrameMetrics.LightsComposited)
                assert.equals(unchanged, primary.Canvas:newImageData():getString())
                assert.equals(1, camera.FrameMetrics.LightsComposited)
                assert.is_true(beforeTint ~= camera.Canvas:newImageData():getString())

                light:SetPosition(80, 96, 2)
                world:Update(0)
                assert.equals(2, primary.FrameMetrics.LightsComposited)
                assert.equals(0, camera.FrameMetrics.LightsComposited)
                assert.equals(0, camera.Canvas:newImageData():getPixel(80, 96),
                    "The previous camera must clear a light that moved away")
                assertMatchesUnculled(primary)
                assertMatchesUnculled(camera)

                light:SetRadius(64)
                world:Update(0)
                assert.equals(2, primary.FrameMetrics.LightsComposited)
                assert.equals(0, camera.FrameMetrics.CompositionMs)
                light:SetPosition(2000, 2000, 2)
                world:Update(0)
                assert.is_true(light:GetCanvasDestroyed())
                assert.equals(1, primary.FrameMetrics.LightsComposited)
                assert.equals(0, camera.FrameMetrics.CompositionMs)
                light:Remove()
                world:Update(0)
                assert.equals(0, primary.FrameMetrics.CompositionMs)
                nearby:Remove()
                world:Update(0)
                assert.equals(0, primary.Canvas:newImageData():getPixel(64, 64))
                assert.equals(0, camera.FrameMetrics.CompositionMs)

                local replacement = Light:new(world, 48)
                replacement.Blur = false
                replacement:SetPosition(64, 64, 2)
                world:Update(0)
                assert.equals(1, primary.FrameMetrics.LightsComposited)
                assert.equals(0, camera.FrameMetrics.CompositionMs)
                assert.is_true(primary.Canvas:newImageData():getPixel(64, 64) > 0.5)
                world:SetColor(0.2, 0.3, 0.4, 1)
                world:Update(0)
                assert.near(0.2, primary.Canvas:newImageData():getPixel(0, 0), 0.01)
                assert.near(0.2, camera.Canvas:newImageData():getPixel(64, 64), 0.01)
            end)

        it("preserves textured illumination outside circular light bounds",
            ---@description Measures square texture corners with fractional camera translation, zoom, and reduced canvas resolution.
            ---@return nil
            function()
                local data = love.image.newImageData(128, 128)
                data:mapPixel(
                    ---@description Supplies an opaque texture covering the light canvas's positive corner.
                    ---@param x number Pixel x-coordinate.
                    ---@param y number Pixel y-coordinate.
                    ---@return number r Red channel.
                    ---@return number g Green channel.
                    ---@return number b Blue channel.
                    ---@return number a Alpha channel.
                    function(x, y) return 1, 1, 1, 1 end)
                light:SetImage(love.graphics.newImage(data))
                local primary = world:GetCamera()
                primary:Resize(32, 32)
                local camera = LightCamera:new(world, 32, 32)
                camera:SetPosition(1000, 1000)
                for _, scale in ipairs({ 0.5, 1 }) do
                    world:SetQuality("high", { ShadowScale = scale })
                    for _, zoom in ipairs({ 0.5, 2 }) do
                        primary:SetPosition(160.25, 176.25, zoom)
                        assert.is_false(primary:IsVisible(80, 96, light.Radius))
                        world:Update(0)
                        assert.is_false(light:GetCanvasDestroyed())
                        assert.equals(1, primary.FrameMetrics.LightsComposited)
                        assert.equals(0, camera.FrameMetrics.LightsComposited)
                        assert.is_true(primary.Canvas:newImageData():getPixel(2, 2) > 0.9)
                        local before = primary.Canvas:newImageData():getString()
                        world:ForceUpdate()
                        world:Update(0)
                        assert.equals(before, primary.Canvas:newImageData():getString())
                        assert.equals(0, camera.FrameMetrics.CompositionMs)
                    end
                end
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

        it("renders direct camera transform edits without coupling height to zoom",
            ---@description Checks direct edits invalidate both composition and star views and keep world aliases current.
            ---@return nil
            function()
                world:Resize(192, 192)
                local camera = LightCamera:new(world, 192, 192)
                camera:SetPosition(0, 0, 2)
                world:SetPosition(0, 0, 2)
                local star = Star:new(world, 112)
                star.Blur = false
                star:SetPosition(80, 96, 2)
                world:Update(0)
                local before = camera.Canvas:newImageData():getString()
                camera:GetTransform():SetLocalPosition(32, 32, 100)
                world:GetCamera():GetTransform():SetLocalPosition(32, 32, 77)
                assert.same({ 32, 32, 2 }, { world:GetPosition() })
                assert.same({ 32, 32, 2 }, { world.x, world.y, world.z })
                world:Update(0)
                local moved = camera.Canvas:newImageData():getString()
                assert.is_true(before ~= moved, "Transform edits must refresh cached lighting")
                assert.equals(moved, world.Canvas:newImageData():getString())
                assert.same({ 96, 128, 4 }, { star:GetView(camera):GetCanvasCenter() })
                assert.equals(1, shadowRenders, "Camera transform edits must reuse local-light shadows")
                camera:SetPosition(50, 60)
                assert.same({ 50, 60, 2 }, { camera:GetPosition() })
                assert.same({ 50, 60, 100 }, { camera:GetTransform():GetPosition() })
                world:Update(0)
                local incremental = camera.Canvas:newImageData():getString()
                world:ForceUpdate()
                world:Update(0)
                assert.equals(incremental, camera.Canvas:newImageData():getString())
            end)

        it("follows hierarchical parents before culling and detaches cleanly on removal",
            ---@description Verifies parent rotation, world-coordinate setters, reparenting, visibility, and per-view pixels.
            ---@return nil
            function()
                world:Resize(192, 192)
                world:SetPosition(-1000, -1000)
                local camera = LightCamera:new(world, 192, 192)
                camera:SetPosition(0, 0, 2)
                local ancestor = Transform:new()
                ancestor:SetLocalPosition(30, 40, 50)
                local parent = Transform:new()
                parent:SetParent(ancestor)
                parent:SetLocalPosition(20, 10, 40)
                parent:SetLocalRotation(90)
                camera:GetTransform():SetParent(parent)
                camera:GetTransform():SetLocalPosition(16, 8, 3)
                local star = Star:new(world, 112)
                star.Blur = false
                star:SetPosition(80, 96, 2)
                world:Update(0)
                local x, y, zoom = camera:GetPosition()
                assert.near(42, x, 0.000001)
                assert.near(66, y, 0.000001)
                assert.equals(2, zoom)
                camera:SetPosition(32, 32)
                assert.equals(93, select(3, camera:GetTransform():GetPosition()),
                    "World positioning must preserve inherited height")
                world:Update(0)
                local before = camera.Canvas:newImageData():getString()
                parent:SetLocalRotation(0)
                ancestor:SetLocalPosition(35, 45, 50)
                world:Update(0)
                local moved = camera.Canvas:newImageData():getString()
                assert.is_true(before ~= moved, "Ancestor movement must refresh camera lighting")
                world:SetPosition(camera:GetPosition())
                world:Update(0)
                assert.equals(moved, world.Canvas:newImageData():getString(),
                    "Following and unparented views at the same position must match")

                local other = Transform:new()
                other:SetLocalPosition(10, 10, 0)
                camera:GetTransform():SetParent(other)
                world:SetPosition(-1000, -1000)
                world:Update(0)
                assert.is_true(moved ~= camera.Canvas:newImageData():getString(),
                    "Reparenting must invalidate the view even without a transform dirty flag")
                other:SetLocalPosition(10000, 10000, 0)
                world:Update(0)
                assert.is_true(light:GetCanvasDestroyed(), "Culling must use updated parent positions")
                other:SetLocalPosition(10, 10, 0)
                world:Update(0)
                assert.is_false(light:GetCanvasDestroyed())
                local id = camera:GetTransform().ID
                camera:Remove()
                assert.is_nil(other.Children[id])
                assert.is_nil(camera:GetTransform():GetParent())
            end)

        it("reports actual cache work without allocating star views or counting reuse as rebuilding",
            ---@description Checks completed redraw/geometry counts and their independent camera ownership.
            ---@return nil
            function()
                local debug = DebugOverlay:new(world)
                local camera = LightCamera:new(world, 192, 192)
                local star = Star:new(world, 112)
                star.Blur = false
                star:SetPosition(80, 96, 2)
                assert.equals(0, debug:GetStats(camera).ShadowRedraws)
                assert.is_nil(star.Views[camera], "Inspecting statistics cannot allocate a view")
                world:Update(0)
                local initial = debug:GetStats()
                assert.equals(2, initial.ShadowRedraws)
                assert.equals(2, initial.GeometryRebuilds)
                assert.is_true(initial.CachedDrawCalls > 0)
                world:Update(0)
                light:SetColor(0.5, 0.75, 1, 1)
                star:SetColor(0.75, 0.5, 1, 1)
                world:Update(0)
                assert.same(initial, debug:GetStats(), "Stationary and tint-only updates must not count as rebuilds")
                body:SetPosition(112, 120, 1)
                world:Update(0)
                assert.same({ 2, 2 }, { light:GetDebugCounts() })
                assert.equals(4, debug:GetStats().ShadowRedraws)
                assert.equals(4, debug:GetStats().GeometryRebuilds)
                local primary = debug:GetStats()
                local secondary = debug:GetStats(camera)
                camera:SetPosition(32, 32, 2)
                world:Update(0)
                assert.same(primary, debug:GetStats(), "Moving another view must not rebuild this view's shadows")
                assert.equals(secondary.ShadowRedraws + 1, debug:GetStats(camera).ShadowRedraws)
            end)

        it("draws each diagnostic category in the requested viewport while preserving state and lighting caches",
            ---@description Measures light, occluder, camera, and counter pixels independently at translated and zoomed coordinates.
            ---@return nil
            function()
                world:Resize(192, 192)
                world:SetPosition(32, 32, 1.5)
                world:Update(0)
                local debug = DebugOverlay:new(world)
                local fields = { "LightBounds", "ShadowGeometry", "CameraViewports", "CacheCounters" }
                local original = world.Canvas:newImageData():getString()
                local lightPixels = light.Canvas:newImageData():getString()
                local shapes = light.Shapes
                local stats = debug:GetStats()
                for _, field in ipairs(fields) do debug[field] = false end
                for _, scale in ipairs({ 1, 2 }) do
                    local target = love.graphics.newCanvas(384, 320, { dpiscale = scale })
                    for _, field in ipairs(fields) do
                        debug[field] = true
                        love.graphics.setCanvas(target)
                        love.graphics.setScissor()
                        love.graphics.clear()
                        love.graphics.origin()
                        love.graphics.translate(9, 7)
                        love.graphics.setShader(require("shadows").DarkenShader)
                        love.graphics.setColor(0.25, 0.5, 0.75, 1)
                        local color = { love.graphics.getColor() }
                        love.graphics.setBlendMode("add", "alphamultiply")
                        love.graphics.setLineWidth(7)
                        love.graphics.setLineStyle("rough")
                        love.graphics.setScissor(8, 8, 320, 300)
                        debug:Draw(world:GetCamera(), 16, 12)
                        assert.equals(target, love.graphics.getCanvas())
                        assert.equals(require("shadows").DarkenShader, love.graphics.getShader())
                        assert.same(color, { love.graphics.getColor() })
                        assert.same({ 9, 7 }, { love.graphics.transformPoint(0, 0) })
                        assert.same({ 8, 8, 320, 300 }, { love.graphics.getScissor() })
                        assert.same({ "add", "alphamultiply" }, { love.graphics.getBlendMode() })
                        assert.equals(7, love.graphics.getLineWidth())
                        assert.equals("rough", love.graphics.getLineStyle())
                        love.graphics.setCanvas()
                        local pixels = target:newImageData()
                        assert.equals(0, select(4, pixels:getPixel(12 * scale, 100 * scale)),
                            "Overlays must be viewport-clipped")
                        assert.equals(0, select(4, pixels:getPixel(208 * scale, 100 * scale)),
                            "Overlays must not bleed past the viewport")
                        local colored = 0
                        for py = 12, 203 do
                            for px = 16, 207 do
                                local r, g, b = pixels:getPixel(px * scale, py * scale)
                                if (field == "LightBounds" and r > 0.4 and g > 0.25 and b < 0.3)
                                    or (field == "ShadowGeometry" and g > 0.5 and g > r)
                                    or (field == "CameraViewports" and b > 0.5 and b > r)
                                    or (field == "CacheCounters" and r > 0.6 and g > 0.6 and b > 0.6) then
                                    colored = colored + 1
                                end
                            end
                        end
                        assert.is_true(colored > 20, field .. " must draw visible diagnostics at DPI " .. scale)
                        if field == "ShadowGeometry" then
                            local _, green = pixels:getPixel(136 * scale, 93 * scale)
                            assert.is_true(green > 0.5, "Occluder outlines must use the camera transform")
                        end
                        debug[field] = false
                    end
                end
                love.graphics.setScissor()
                love.graphics.setShader()
                assert.equals(original, world.Canvas:newImageData():getString())
                assert.equals(lightPixels, light.Canvas:newImageData():getString())
                assert.equals(shapes, light.Shapes)
                assert.same(stats, debug:GetStats())
            end)

        it("outlines cached textured and shader-based shapes without applying their shaders",
            ---@description Covers texture draw bounds, packed polygon arguments, upright shader rectangles, and geometry cache immutability.
            ---@return nil
            function()
                local texture = love.graphics.newCanvas(8, 8, { dpiscale = 1 })
                love.graphics.setCanvas(texture)
                love.graphics.clear(0.5, 0.5, 1, 1)
                love.graphics.setCanvas()
                require("shadows.ShadowShapes.ImageShadow"):new(body, texture)
                require("shadows.ShadowShapes.HeightShadow"):new(body, texture):SetPosition(0, 16)
                require("shadows.ShadowShapes.CastImageShadow"):new(body, texture)
                world:Update(0)
                local debug = DebugOverlay:new(world)
                debug.LightBounds, debug.CameraViewports, debug.CacheCounters = false, false, false
                local geometry = light.Shapes
                local stats = debug:GetStats()
                local lighting = world.Canvas:newImageData():getString()
                local output = love.graphics.newCanvas(world.Width, world.Height, { dpiscale = 1 })
                love.graphics.setCanvas(output)
                love.graphics.clear()
                debug:Draw()
                love.graphics.setCanvas()
                local _, green = output:newImageData():getPixel(112, 112)
                assert.is_true(green > 0.5, "Texture bounds must be outlined at their world coordinates")
                assert.equals(geometry, light.Shapes)
                assert.same(stats, debug:GetStats())
                assert.equals(lighting, world.Canvas:newImageData():getString())
            end)

        it("reports completed per-camera frame work separately from shared local-light work",
            ---@description Checks cold work, stationary zeros, camera isolation, composition counts, and stable completed snapshots.
            ---@return nil
            function()
                local debug = DebugOverlay:new(world)
                local camera = LightCamera:new(world, 192, 192)
                local star = Star:new(world, 112)
                star.Blur = false
                star:SetPosition(80, 96, 2)
                world:Update(0)
                local cold = debug:GetFrameStats()
                assert.equals(1, cold.Camera.Frame)
                assert.equals(1, cold.Shared.Frame)
                assert.equals(1, cold.Shared.ShadowRedraws)
                assert.equals(1, cold.Camera.ShadowRedraws)
                assert.equals(3, cold.Shared.ShadowDrawCalls)
                assert.equals(3, cold.Camera.ShadowDrawCalls)
                assert.equals(3, cold.Shared.CanvasAllocations)
                assert.equals(4, cold.Camera.CanvasAllocations)
                assert.equals(4, debug:GetFrameStats(camera).Camera.CanvasAllocations)
                assert.equals(2, cold.Camera.LightsComposited)
                assert.equals(cold.Shared, debug:GetFrameStats(camera).Shared,
                    "Shared work must be one world bucket, not copied into each camera")
                assert.is_true(cold.Camera.StarUpdateMs >= 0 and cold.Camera.CompositionMs >= 0
                    and cold.Shared.SharedUpdateMs >= 0)
                world:Update(0)
                local idle = debug:GetFrameStats()
                for _, field in ipairs({ "ShadowRedraws", "GeometryRebuilds", "ShadowDrawCalls", "CanvasAllocations" }) do
                    assert.equals(0, idle.Camera[field], field .. " must reset for an idle camera")
                    assert.equals(0, idle.Shared[field], field .. " must reset for idle shared lights")
                end
                assert.equals(0, idle.Camera.CompositionMs)
                assert.equals(0, idle.Camera.LightsComposited)
                assert.equals(1, cold.Camera.ShadowRedraws, "Older frame snapshots must not be cleared in place")
                camera:SetPosition(32, 32, 2)
                world:Update(0)
                local primary, secondary = debug:GetFrameStats(), debug:GetFrameStats(camera)
                assert.equals(0, primary.Camera.ShadowRedraws)
                assert.equals(0, primary.Camera.CompositionMs)
                assert.equals(0, primary.Camera.LightsComposited)
                assert.equals(0, primary.Shared.ShadowRedraws)
                assert.equals(1, secondary.Camera.ShadowRedraws)
                assert.equals(2, secondary.Camera.LightsComposited)
                light:SetColor(0.5, 0.75, 1, 1)
                world:Update(0)
                assert.equals(0, debug:GetFrameStats().Shared.ShadowRedraws)
                assert.equals(0, debug:GetFrameStats().Camera.GeometryRebuilds)
                assert.equals(2, debug:GetFrameStats().Camera.LightsComposited)

                local completed = debug:GetFrameStats()
                local render = light.RenderShadowCanvas
                local observedFrame
                ---@description Observes diagnostics during rendering to ensure only completed snapshots are public.
                ---@param self Light Renderer being observed.
                ---@param x number World x-coordinate.
                ---@param y number World y-coordinate.
                ---@param z number Light height.
                ---@return nil
                function light:RenderShadowCanvas(x, y, z)
                    observedFrame = debug:GetFrameStats()
                    render(self, x, y, z)
                end
                world:ForceUpdate()
                world:Update(0)
                assert.equals(completed.Shared, observedFrame.Shared)
                assert.equals(completed.Camera, observedFrame.Camera)
                assert.equals(completed.Camera.Frame + 1, debug:GetFrameStats().Camera.Frame)
                local before = {}
                for field, value in pairs(debug:GetFrameStats().Camera) do before[field] = value end
                debug:Draw()
                debug:Draw()
                assert.same(before, debug:GetFrameStats().Camera,
                    "Drawing diagnostics must not reset, time, or modify the sampled frame")
            end)

        it("counts camera and penumbra allocations in the next completed update without charging other views",
            ---@description Measures full buffer allocations for resize/quality churn and checks zero/nonnegative work after removal.
            ---@return nil
            function()
                light.Blur = true
                local debug = DebugOverlay:new(world)
                local camera = LightCamera:new(world, 192, 192)
                local star = Star:new(world, 112)
                star:SetPosition(80, 96, 2)
                world:Update(0)
                assert.equals(7, debug:GetFrameStats().Shared.CanvasAllocations)
                assert.equals(8, debug:GetFrameStats().Camera.CanvasAllocations)
                assert.equals(8, debug:GetFrameStats(camera).Camera.CanvasAllocations)
                local previous = debug:GetFrameStats(camera).Camera
                camera:Resize(160, 128)
                assert.equals(previous, debug:GetFrameStats(camera).Camera,
                    "Between-update allocations must not modify the completed snapshot")
                world:Update(0)
                assert.equals(8, debug:GetFrameStats(camera).Camera.CanvasAllocations)
                assert.equals(0, debug:GetFrameStats().Camera.CanvasAllocations)
                assert.equals(0, debug:GetFrameStats().Camera.CompositionMs)
                assert.equals(0, debug:GetFrameStats().Shared.CanvasAllocations)
                world:SetQuality("low")
                world:Update(0)
                assert.equals(7, debug:GetFrameStats().Shared.CanvasAllocations)
                assert.equals(8, debug:GetFrameStats().Camera.CanvasAllocations)
                assert.equals(8, debug:GetFrameStats(camera).Camera.CanvasAllocations)
                world:Update(0)
                assert.equals(0, debug:GetFrameStats().Shared.CanvasAllocations)
                assert.equals(0, debug:GetFrameStats(camera).Camera.CanvasAllocations)
                star:Remove()
                light:Remove()
                world:Update(0)
                assert.equals(0, debug:GetFrameStats().Shared.ShadowRedraws)
                assert.equals(0, debug:GetFrameStats().Camera.ShadowRedraws)
                assert.equals(0, debug:GetFrameStats().Camera.LightsComposited)
                local replacement = Light:new(world, 112)
                replacement:SetPosition(80, 96, 2)
                world:Update(0)
                assert.equals(1, debug:GetFrameStats().Shared.ShadowRedraws)
                assert.equals(7, debug:GetFrameStats().Shared.CanvasAllocations)
                assert.equals(0, debug:GetFrameStats().Camera.ShadowRedraws)
                assert.equals(1, debug:GetFrameStats().Camera.LightsComposited)
            end)
    end)
