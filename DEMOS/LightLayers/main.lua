---@module Demonstrates camera light groups, receiver layers, and inherited/overridden occluder masks.
local capture = require("Capture").new("light-layers-capture.png")
local LightWorld = require("shadows.LightWorld")
local LightCamera = require("shadows.LightCamera")
local Light = require("shadows.Light")
local Star = require("shadows.Star")
local Mask = require("shadows.Mask")
local DPI = require("shadows.DPI")
local Body = require("shadows.Body")
local PolygonShadow = require("shadows.ShadowShapes.PolygonShadow")
local CircleShadow = require("shadows.ShadowShapes.CircleShadow")

---@type LightWorld
local world
---@type LightCamera[]
local cameras = {}
---@type love.Canvas[]
local receiverLayers = {}
---@type Light[]
local lights = {}
---@type Body
local wall
---@type CircleShadow
local override
---@type (PolygonShadow|CircleShadow)[]
local shapes = {}
---@type string[]
local names = { "Wall lights", "Object lights", "All + effects" }
---@type integer[]
local groups = { Mask.group(0), Mask.group(1), Mask.group(2) }
---@type integer
local selected = 1
---@type boolean
local allCasters = false
---@type boolean
local paused = false
---@type boolean
local receiverLayerMode = false
---@type number
local elapsed = 0
---@type string[]
local qualities = { "high", "medium", "low" }

---@description Allocates transparent scene targets for the combined view's receiver groups.
---@return nil
local function resizeReceiverLayers()
    local camera = cameras[3]
    local options = { dpiscale = world.Settings.ShadowScale }
    receiverLayers[1] = love.graphics.newCanvas(camera.Width, camera.Height, options)
    receiverLayers[2] = love.graphics.newCanvas(camera.Width, camera.Height, options)
end

---@description Fits three matching world-space camera views to the current window.
---@param width number Logical window width.
---@param height number Logical window height.
---@return nil
local function resizeViews(width, height)
    local viewportWidth = math.max(1, math.floor((width - 48) / 3))
    local viewportHeight = math.max(1, height - 128)
    for _, camera in ipairs(cameras) do
        camera:Resize(viewportWidth, viewportHeight)
        camera:SetPosition(0, 0, viewportWidth / 360)
    end
    resizeReceiverLayers()
end

---@description Restores selective casting, body inheritance, and the three camera selections.
---@return nil
local function resetMasks()
    cameras[1]:SetLightMask(groups[1])
    cameras[2]:SetLightMask(groups[2])
    cameras[3]:SetLightMask(Mask.ALL)
    for i, light in ipairs(lights) do light:SetLightMask(groups[i]):SetShadowMask(groups[i]) end
    wall:SetShadowMask(groups[1])
    override:SetShadowMask(groups[2])
    allCasters = false
end

---@description Reads blue illumination behind the upper circle, outside its own silhouette.
---@param camera LightCamera Lighting view to sample.
---@return number blue Blue intensity at world position (132, 102).
local function upperShadowSample(camera)
    local x, y, zoom = camera:GetPosition()
    local scale = DPI.getCanvasScale(camera.Canvas)
    local pixels = camera.Canvas:newImageData(1, 1,
        math.floor((132 - x) * zoom * scale), math.floor((102 - y) * zoom * scale), 1, 1)
    local _, _, blue = pixels:getPixel(0, 0)
    return blue
end

---@description Requires a visibly darkened upper-circle projection in blue and combined views for hard and soft shadows.
---@return nil
local function verifyUpperShadow()
    local previousBlur = lights[2].Blur
    for _, blur in ipairs({ false, true }) do
        lights[2].Blur = blur
        world:Update(0)
        local wallPixels = cameras[1].Canvas:newImageData():getString()
        local blocked = { upperShadowSample(cameras[2]), upperShadowSample(cameras[3]) }
        override:SetShadowMask(0)
        world:Update(0)
        assert(wallPixels == cameras[1].Canvas:newImageData():getString(),
            "The upper circle's blue-only caster mask must not change the wall-light view")
        for i = 2, 3 do
            local contrast = upperShadowSample(cameras[i]) - blocked[i - 1]
            assert(contrast >= 0.08, string.format(
                "Upper circle must visibly cast in %s with %s shadows: blue reduction %.5f, required 0.08",
                names[i], blur and "soft" or "hard", contrast))
        end
        override:SetShadowMask(groups[2])
        world:Update(0)
    end
    lights[2].Blur = previousBlur
    world:Update(0)
end

---@description Verifies separate camera illumination, selective occluders, inherited overrides, and full-rebuild equality.
---@return nil
local function verifyLayers()
    world:Update(0)
    assert(cameras[1].FrameMetrics.LightsComposited == 1
        and cameras[2].FrameMetrics.LightsComposited == 1
        and cameras[3].FrameMetrics.LightsComposited == 3,
        "Camera masks must select the two local lights and the effects-only star independently")
    verifyUpperShadow()
    local first = cameras[1].Canvas:newImageData():getString()
    assert(first ~= cameras[2].Canvas:newImageData():getString()
        and first ~= cameras[3].Canvas:newImageData():getString(),
        "The same scene must show different lighting for each mask")
    cameras[1]:SetLightMask(Mask.ALL)
    world:Update(0)
    assert(cameras[1].Canvas:newImageData():getString() == cameras[3].Canvas:newImageData():getString(),
        "Matching camera masks and transforms must produce identical pixels")
    assert(cameras[3].FrameMetrics.CompositionMs == 0,
        "Changing one camera mask must not recompose another view")
    selected = 2
    love.keypressed("0")
    world:Update(0)
    local ambient = cameras[2].Canvas:newImageData():getPixel(80, 80)
    assert(math.abs(ambient - world.R) < 0.01 and cameras[2].FrameMetrics.LightsComposited == 0,
        "A zero mask must preserve ambient illumination without submitting lights")
    resetMasks()
    world:Update(0)
    local beforeOverride = {
        cameras[1].Canvas:newImageData():getString(), cameras[2].Canvas:newImageData():getString(),
    }
    love.keypressed("o")
    world:Update(0)
    for i = 1, 2 do
        assert(beforeOverride[i] ~= cameras[i].Canvas:newImageData():getString(),
            "Restoring body inheritance must move the small circle between caster groups")
    end
    local images = {}
    for i, camera in ipairs(cameras) do images[i] = camera.Canvas:newImageData():getString() end
    world:ForceUpdate()
    world:Update(0)
    for i, camera in ipairs(cameras) do
        assert(images[i] == camera.Canvas:newImageData():getString(),
            "Mask changes must match full rebuilds in every view")
    end
    resetMasks()
    world:Update(0)
    local selective = cameras[1].Canvas:newImageData():getString()
    love.keypressed("s")
    world:Update(0)
    assert(selective ~= cameras[1].Canvas:newImageData():getString(),
        "Selecting all caster groups must change actual projected shadows")
    love.keypressed("g")
    assert(wall:GetShadowMask() == groups[2], "G must change the body's inherited caster groups")
    selected = 1
    love.keypressed("l")
    world:Update(0)
    assert(cameras[1].FrameMetrics.LightsComposited == 0
        and cameras[2].FrameMetrics.LightsComposited == 2,
        "Changing a light's membership must clear its previous view and illuminate the newly selected view")
    resetMasks()
    selected = 1
    world:Update(0)
    world:Update(0)
    for _, camera in ipairs(cameras) do
        assert(camera.FrameMetrics.ShadowRedraws == 0 and camera.FrameMetrics.LightsComposited == 0,
            "Stationary masks must reuse camera compositions and star buffers")
    end
    print("LightLayers camera selection, caster masks, inheritance, and cache verification passed")
end

---@description Builds two selective point lights, an effects-only star, and differently grouped shapes.
---@return nil
function love.load()
    world = LightWorld:new()
    world:SetColor(0.045, 0.05, 0.065, 1)
    cameras = { world:GetCamera(), LightCamera:new(world), LightCamera:new(world) }
    lights[1] = Light:new(world, 235)
    lights[1]:SetPosition(70, 220, 6):SetColor(1, 0.6, 0.2)
    lights[2] = Light:new(world, 340)
    lights[2]:SetPosition(295, 220, 6):SetColor(0.2, 0.55, 1)
    local effects = Star:new(world, 400)
    effects.Blur = false
    effects:SetPosition(180, 60, 6):SetColor(0.16, 0.1, 0.22):SetLightMask(groups[3]):SetShadowMask(0)
    wall = Body:new(world)
    wall:SetPosition(150, 220, 2)
    shapes[1] = PolygonShadow:new(wall, -16, -28, 16, -28, 16, 28, -16, 28)
    override = CircleShadow:new(wall, 0, -105, 14)
    shapes[2] = override
    local objects = Body:new(world):SetShadowMask(groups[2])
    objects:SetPosition(225, 220, 2)
    shapes[3] = CircleShadow:new(objects, 0, 0, 18)
    resetMasks()
    resizeViews(love.graphics.getDimensions())
    for _, argument in ipairs(arg or {}) do
        if argument == "--verify" then verifyLayers() end
    end
    if capture.auto then world:ForceUpdate() end
end

---@description Advances the shared wall once; camera and caster masks remain interactive.
---@param dt number Elapsed seconds.
---@return nil
function love.update(dt)
    if not capture.auto and not paused then
        elapsed = elapsed + dt
        wall:SetPosition(150 + math.sin(elapsed) * 12, 220, 2)
    end
    world:Update(dt)
end

---@description Draws the same scene through one lighting selection and outlines effective caster membership.
---@param camera LightCamera Camera whose matching scene transform is used.
---@param screenX number Screen-space viewport left edge.
---@return nil
local function drawView(camera, screenX)
    local x, y, zoom = camera:GetPosition()
    if receiverLayerMode and camera == cameras[3] then
        for layerIndex, canvas in ipairs(receiverLayers) do
            love.graphics.push("all")
            love.graphics.setCanvas(canvas)
            love.graphics.setScissor(0, 0, camera.Width, camera.Height)
            love.graphics.origin()
            love.graphics.clear(0, 0, 0, 0)
            love.graphics.scale(zoom, zoom)
            love.graphics.translate(-x, -y)
            if layerIndex == 1 then
                love.graphics.setColor(0.85, 0.85, 0.9, 1)
                love.graphics.rectangle("fill", x, y, camera.Width / zoom, camera.Height / zoom)
                love.graphics.setColor(0.65, 0.65, 0.7, 1)
                for gx = 0, 360, 24 do love.graphics.line(gx, 0, gx, camera.Height / zoom) end
                for gy = 0, camera.Height / zoom, 24 do love.graphics.line(0, gy, 360, gy) end
            end
            love.graphics.setColor(0.35, 0.4, 0.45, 1)
            for index, shape in ipairs(shapes) do
                if (layerIndex == 1 and index == 1) or (layerIndex == 2 and index > 1) then
                    shape:Draw(math.huge)
                end
            end
            love.graphics.pop()
        end
        camera:DrawReceiverLayer(Mask.combine(groups[1], groups[3]), receiverLayers[1], screenX, 72)
        camera:DrawReceiverLayer(Mask.combine(groups[2], groups[3]), receiverLayers[2], screenX, 72)
    else
        love.graphics.push("all")
        love.graphics.origin()
        love.graphics.setScissor(screenX, 72, camera.Width, camera.Height)
        love.graphics.translate(screenX, 72)
        love.graphics.scale(zoom, zoom)
        love.graphics.translate(-x, -y)
        love.graphics.setColor(0.85, 0.85, 0.9, 1)
        love.graphics.rectangle("fill", x, y, camera.Width / zoom, camera.Height / zoom)
        love.graphics.setColor(0.65, 0.65, 0.7, 1)
        for gx = 0, 360, 24 do love.graphics.line(gx, 0, gx, camera.Height / zoom) end
        for gy = 0, camera.Height / zoom, 24 do love.graphics.line(0, gy, 360, gy) end
        love.graphics.setColor(0.35, 0.4, 0.45, 1)
        for _, shape in ipairs(shapes) do shape:Draw(math.huge) end
        love.graphics.pop()
        camera:Draw(screenX, 72)
    end
    love.graphics.push("all")
    love.graphics.setScissor(screenX, 72, camera.Width, camera.Height)
    love.graphics.translate(screenX, 72)
    love.graphics.scale(zoom, zoom)
    love.graphics.translate(-x, -y)
    for _, shape in ipairs(shapes) do
        if Mask.matches(shape:GetShadowMask(), groups[1]) then
            love.graphics.setColor(1, 0.65, 0.2, 1)
        else
            love.graphics.setColor(0.3, 0.7, 1, 1)
        end
        if shape.__type == "PolygonShadow" then
            love.graphics.polygon("line", shape:GetVertices())
        else
            local sx, sy = shape:GetPosition()
            love.graphics.circle("line", sx, sy, shape:GetRadius())
        end
    end
    love.graphics.pop()
end

---@description Displays three lighting views, effective masks, and per-frame submission counts.
---@return nil
function love.draw()
    love.graphics.clear(0.025, 0.025, 0.04, 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("LightLayers | one world, three lighting selections | orange: wall casters | blue: object casters", 12, 8)
    love.graphics.print("Small circle: " .. (override.ShadowMask == nil and "inherits wall body" or "explicit object override")
        .. " | casters: " .. (allCasters and "all groups" or "selective")
        .. " | quality " .. world.Settings:GetQuality()
        .. (receiverLayerMode and " | receiver layers on view 3" or "")
        .. (paused and " | paused" or ""), 12, 28)
    for i, camera in ipairs(cameras) do
        local screenX = 12 + (i - 1) * (camera.Width + 12)
        drawView(camera, screenX)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(string.format("%s %s | light mask %.0f",
            selected == i and ">" or " ", names[i], camera:GetLightMask()), screenX, 50)
        love.graphics.print(string.format("Composited %d | star shadow draws %d",
            camera.FrameMetrics.LightsComposited, camera.FrameMetrics.ShadowDrawCalls),
            screenX, 78 + camera.Height)
    end
    love.graphics.print(
        "Tab: view | 1/2/3/0: lights | R: receiver layers | S: caster selection | O: shape override | G: body group | L: light group | B: blur | Q: quality | Space: pause",
        12, love.graphics.getHeight() - 26)
    capture.draw()
end

---@description Resizes the three matching views after a window layout change.
---@param width number New logical window width.
---@param height number New logical window height.
---@return nil
function love.resize(width, height)
    if world then resizeViews(width, height) end
end

---@description Changes camera selection, light membership, caster groups, inheritance, and shared quality.
---@param key string Pressed key.
---@return nil
function love.keypressed(key)
    if key == "tab" then
        selected = selected % #cameras + 1
    elseif key == "1" or key == "2" or key == "3" or key == "0" then
        local choices = { ["1"] = groups[1], ["2"] = groups[2], ["3"] = Mask.ALL, ["0"] = 0 }
        cameras[selected]:SetLightMask(choices[key])
    elseif key == "s" then
        allCasters = not allCasters
        for i, light in ipairs(lights) do light:SetShadowMask(allCasters and Mask.ALL or groups[i]) end
    elseif key == "o" then
        override:SetShadowMask(override.ShadowMask == nil and groups[2] or nil)
    elseif key == "g" then
        wall:SetShadowMask(wall:GetShadowMask() == groups[1] and groups[2] or groups[1])
    elseif key == "l" then
        lights[1]:SetLightMask(lights[1]:GetLightMask() == groups[1] and groups[2] or groups[1])
    elseif key == "space" then
        paused = not paused
    elseif key == "b" then
        for _, light in ipairs(lights) do light.Blur = not light.Blur end
    elseif key == "q" then
        for i, quality in ipairs(qualities) do
            if world.Settings:GetQuality() == quality then
                world.Settings:SetQuality(qualities[i % #qualities + 1])
                resizeReceiverLayers()
                break
            end
        end
    elseif key == "r" then
        receiverLayerMode = not receiverLayerMode
    end
    capture.keypressed(key)
end
