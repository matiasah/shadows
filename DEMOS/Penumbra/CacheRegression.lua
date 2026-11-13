---@module Verifies granular cache work counts and rendering against forced full rebuilds.
local LightWorld = require("shadows.LightWorld")
local Light = require("shadows.Light")
local Star = require("shadows.Star")
local Body = require("shadows.Body")
local CircleShadow = require("shadows.ShadowShapes.CircleShadow")
local PolygonShadow = require("shadows.ShadowShapes.PolygonShadow")
local ImageShadow = require("shadows.ShadowShapes.ImageShadow")
local NormalShadow = require("shadows.ShadowShapes.NormalShadow")
local HeightShadow = require("shadows.ShadowShapes.HeightShadow")
local CacheRegression = {}

---@class CacheCallCount
---@field value integer Calls since the last reset.

---@description Counts calls to an instance method without changing its results.
---@param object table Instance whose method is wrapped.
---@param name string Method name.
---@return CacheCallCount count Mutable call counter.
local function countCalls(object, name)
    local original = object[name]
    local count = { value = 0 }
    ---@description Records a call and forwards all arguments and results.
    ---@param self table Wrapped instance.
    ---@param ... any Original method arguments.
    ---@return any ... Original method results.
    object[name] = function(self, ...)
        count.value = count.value + 1
        return original(self, ...)
    end
    return count
end

---@description Checks complete incremental light, visibility, and world pixels against a full rebuild.
---@param world LightWorld Scene to force.
---@param lights Light[] Lights whose intermediate canvases are compared.
---@param label string Mutation being checked.
---@return nil
local function checkFullRebuild(world, lights, label)
    local canvases = { world.Canvas }
    for _, light in ipairs(lights) do
        canvases[#canvases + 1] = light.Canvas
        canvases[#canvases + 1] = light.ShadowCanvas
    end
    local images = {}
    for i, canvas in ipairs(canvases) do images[i] = canvas:newImageData() end
    world:ForceUpdate()
    world:Update()
    for i, canvas in ipairs(canvases) do
        local actual = canvas:newImageData()
        assert(images[i]:getString() == actual:getString(),
            label .. ": incremental pixels must equal a full rebuild (canvas " .. i .. ")")
    end
end

---@description Checks cache counts, old/new influence bounds, and geometry reuse at a fixed DPI.
---@param scale number Physical pixels per logical unit.
---@return nil
local function checkScale(scale)
    local newCanvas = love.graphics.newCanvas
    ---@description Uses the requested DPI without changing other canvas options.
    ---@param width number Logical canvas width.
    ---@param height number Logical canvas height.
    ---@param settings table? Canvas options; defaults to an empty table.
    ---@return love.Canvas canvas New test canvas.
    love.graphics.newCanvas = function(width, height, settings)
        local options = {}
        for key, value in pairs(settings or {}) do options[key] = value end
        options.dpiscale = scale
        return newCanvas(width, height, options)
    end
    love.graphics.push("all")
    local world = LightWorld:new()
    world:Resize(384, 192)
    local left, right = Light:new(world, 80), Light:new(world, 80)
    left:SetPosition(80, 96, 1)
    right:SetPosition(304, 96, 1)
    local star = Star:new(world, 600)
    star:SetPosition(40, 96, 1)
    local lights = { left, right, star }
    local body = Body:new(world)
    body:SetPosition(108, 80, 2)
    local circle = CircleShadow:new(body, 0, 0, 10)
    local polygon = PolygonShadow:new(body, -8, 24, 8, 24, 8, 40, -8, 40)
    local leftDraws = countCalls(left, "RenderShadowCanvas")
    local rightDraws = countCalls(right, "RenderShadowCanvas")
    local starDraws = countCalls(star, "RenderShadowCanvas")
    local circleBuilds = countCalls(circle, "GenerateShadows")
    local polygonBuilds = countCalls(polygon, "GenerateShadows")
    world:Update()
    local fields = countCalls(left.Penumbra, "Update")
    local radii = countCalls(left.Penumbra, "UpdateRadius")
    local counters = { leftDraws, rightDraws, starDraws, circleBuilds, polygonBuilds, fields, radii }

    ---@description Resets instrumentation after each reference rebuild.
    ---@return nil
    local function reset()
        for _, count in ipairs(counters) do count.value = 0 end
    end

    reset()
    world:Update()
    for _, count in ipairs(counters) do assert(count.value == 0, "Unchanged scenes must stay cached") end
    left:SetColor(0.7, 0.4, 0.2, 0.8)
    star:SetColor(0.2, 0.3, 0.4, 0.6)
    world:Update()
    assert(leftDraws.value == 0 and starDraws.value == 0 and fields.value == 0 and radii.value == 0,
        "Color changes must only recompose illumination")
    checkFullRebuild(world, lights, "color")

    reset()
    left.Arc = 220
    left:SetAngle(35)
    world:Update()
    assert(leftDraws.value == 0 and circleBuilds.value == 0 and fields.value == 0,
        "Arc and rotation changes must reuse shadows and distance fields")
    checkFullRebuild(world, lights, "arc and rotation")

    reset()
    left.SizeRadius = 24
    world:Update()
    assert(leftDraws.value == 0 and fields.value == 0 and radii.value == 1,
        "Source size changes must update only filter radii and illumination")
    checkFullRebuild(world, lights, "source size")

    reset()
    circle:SetPosition(3, -4)
    world:Update()
    assert(leftDraws.value == 1 and rightDraws.value == 0 and starDraws.value == 1,
        "Shape movement must redraw only influenced local lights and full-scene stars")
    assert(circleBuilds.value > 0 and polygonBuilds.value == 0,
        "Shape movement must not regenerate an unchanged sibling's geometry")
    checkFullRebuild(world, lights, "shape movement")

    reset()
    body:SetAngle(20)
    world:Update()
    assert(leftDraws.value == 1 and rightDraws.value == 0
        and circleBuilds.value > 0 and polygonBuilds.value > 0,
        "Body rotation must rebuild all its shapes, but not distant lights")
    checkFullRebuild(world, lights, "body rotation")

    reset()
    body:SetPosition(320, 80, 2)
    world:Update()
    assert(leftDraws.value == 1 and rightDraws.value == 1,
        "Movement between lights must invalidate both old and new influence bounds")
    checkFullRebuild(world, lights, "movement between lights")

    reset()
    circle:SetRadius(260)
    world:Update()
    assert(leftDraws.value == 1 and rightDraws.value == 1, "Growing shapes must reach newly affected lights")
    checkFullRebuild(world, lights, "shape growth")
    reset()
    circle:SetRadius(8)
    world:Update()
    assert(leftDraws.value == 1 and rightDraws.value == 1, "Shrinking shapes must clear their old influence")
    checkFullRebuild(world, lights, "shape shrink")

    reset()
    circle:Remove()
    world:Update()
    assert(leftDraws.value == 0 and rightDraws.value == 1, "Removed shapes must invalidate their previous bounds")
    checkFullRebuild(world, lights, "shape removal")

    reset()
    polygon:SetVertices(-12, 20, 12, 20, 12, 42, -12, 42)
    world:Update()
    assert(leftDraws.value == 0 and rightDraws.value == 1, "Vertex edits must remain local")
    checkFullRebuild(world, lights, "vertex edit")
    body:Remove()
    world:Update()
    checkFullRebuild(world, lights, "body removal")

    local distant = Body:new(world)
    distant:SetPosition(2000, 2000, 2)
    local distantShape = CircleShadow:new(distant, 0, 0, 10)
    world:Update()
    reset()
    distantShape:SetRadius(12)
    world:Update()
    assert(leftDraws.value == 0 and rightDraws.value == 0 and starDraws.value == 1,
        "Changes outside local lights must not redraw their canvases")
    reset()
    world:Update()
    assert(starDraws.value == 0, "Distant dirty flags must clear even without local recomposition")

    left.Blur = false
    world:Update()
    assert(not left.Penumbra, "Disabling softness must release filtering buffers")
    checkFullRebuild(world, lights, "disable blur")
    left.Blur = true
    world:Update()
    checkFullRebuild(world, lights, "enable blur")
    left:SetRadius(72)
    world:Update()
    assert(left.Canvas:getWidth() == 144 and left.ShadowCanvas:getWidth() == 144,
        "Radius changes must resize local-light caches")
    checkFullRebuild(world, lights, "light radius")
    left:SetPosition(76, 100, 1.4)
    world:Update()
    checkFullRebuild(world, lights, "light movement")
    left:SetPosition(3000, 100, 1.4)
    world:Update()
    assert(left:GetCanvasDestroyed(), "Offscreen lights must release their caches")
    checkFullRebuild(world, { right, star }, "offscreen light")
    left:SetPosition(76, 100, 1.4)
    world:Update()
    checkFullRebuild(world, lights, "returning light")

    local textureA = love.graphics.newCanvas(12, 12)
    local textureB = love.graphics.newCanvas(12, 12)
    love.graphics.setCanvas(textureA)
    love.graphics.clear(0.5, 0.5, 1, 1)
    love.graphics.setCanvas(textureB)
    love.graphics.clear(0.7, 0.4, 0.8, 1)
    love.graphics.setCanvas()
    for _, kind in ipairs({ ImageShadow, NormalShadow, HeightShadow }) do
        local texturedBody = Body:new(world)
        texturedBody:SetPosition(96, 100, 0.5)
        local textured = kind:new(texturedBody, textureA)
        world:Update()
        reset()
        textured:SetTexture(textureB)
        world:Update()
        assert(leftDraws.value == 1 and rightDraws.value == 0,
            "Same-size texture replacement must invalidate only influenced lights")
        checkFullRebuild(world, lights, "texture replacement")
        world:SetPosition(3, 4, 1.1)
        world:Update()
        checkFullRebuild(world, lights, "textured camera movement")
        texturedBody:Remove()
        world:SetPosition(0, 0, 1)
        world:Update()
    end

    local emptyBody = Body:new(world)
    emptyBody:SetPosition(96, 100, 2)
    local empty = ImageShadow:new(emptyBody, textureA)
    local sibling = CircleShadow:new(emptyBody, 0, 16, 8)
    local emptyBuilds = countCalls(empty, "GenerateShadows")
    reset()
    world:Update()
    assert(leftDraws.value == 1 and rightDraws.value == 0 and emptyBuilds.value > 0,
        "New shapes must invalidate their influenced lights")
    emptyBuilds.value = 0
    sibling:SetRadius(9)
    world:Update()
    assert(emptyBuilds.value == 0, "Empty shadow lists must also be cached")
    checkFullRebuild(world, lights, "empty geometry cache")
    emptyBody:SetPosition(96, 100, 0.4)
    world:Update()
    checkFullRebuild(world, lights, "height layer change")
    emptyBody:Remove()
    world:Update()

    local callbackDraws = 0
    ---@description Draws a custom occluder whose position is external to shape tracking.
    ---@param self LightWorld Owning world.
    ---@param light Light|Star Light currently rendering.
    ---@return nil
    world.DrawShadows = function(self, light)
        callbackDraws = callbackDraws + 1
        love.graphics.rectangle("fill", 90, 90, 4, 4)
    end
    reset()
    world:ForceUpdate()
    world:Update()
    assert(callbackDraws == 3 and leftDraws.value == 1 and rightDraws.value == 1 and starDraws.value == 1,
        "ForceUpdate must rebuild every light and execute custom shadow callbacks")
    checkFullRebuild(world, lights, "custom callbacks")

    local physics = love.physics.newWorld()
    local tracked = love.physics.newBody(physics, 100, 80, "kinematic")
    local parent = world:TrackBody(tracked)
    local attached = Body:new(world)
    attached:GetTransform():SetParent(parent)
    CircleShadow:new(attached, 0, 0, 8)
    world:Update()
    tracked:setPosition(320, 80)
    tracked:setAngle(0.4)
    reset()
    world:Update()
    assert(leftDraws.value == 1 and rightDraws.value == 1,
        "Tracked parent transforms must invalidate old and new bounds in the same frame")
    checkFullRebuild(world, lights, "tracked parent")
    physics:destroy()

    left:SetImage(textureA)
    world:Update()
    checkFullRebuild(world, lights, "light image radius")
    reset()
    left:SetImage(textureB)
    world:Update()
    assert(leftDraws.value == 0, "Same-radius light image replacement must reuse shadow pixels")
    checkFullRebuild(world, lights, "light image appearance")
    left:Remove()
    star:Remove()
    world:Update()
    checkFullRebuild(world, { right }, "light and star removal")

    love.graphics.pop()
    love.graphics.newCanvas = newCanvas
    print("Granular cache regressions passed at DPI " .. scale)
end

---@description Runs real-renderer cache regressions at DPI scales one and two.
---@return nil
function CacheRegression.run()
    checkScale(1)
    checkScale(2)
end

return CacheRegression
