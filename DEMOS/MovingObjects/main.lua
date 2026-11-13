---@module Animates back-and-forth occluders under three colored lights using the shared library.
local capture = require("Capture").new("movingobjects-capture.png")
local LightWorld = require("shadows.LightWorld")
local Light = require("shadows.Light")
local Body = require("shadows.Body")
local CircleShadow = require("shadows.ShadowShapes.CircleShadow")
local PolygonShadow = require("shadows.ShadowShapes.PolygonShadow")

---@class MovingDemoObject
---@field body Body Animated body.
---@field shape CircleShadow|PolygonShadow Visible shadow caster.
---@field x number Center of the movement path.
---@field y number Center of the movement path.
---@field dx number Horizontal oscillation amplitude.
---@field dy number Vertical oscillation amplitude.
---@field phase number Starting phase in radians.

---@class MovingDemoLight
---@field light Light Fixed colored light.
---@field color number[] Normalized RGB marker color.
---@field redraws integer Shadow-canvas rebuilds in the latest update.

---@type LightWorld
local world
---@type MovingDemoObject[]
local objects = {}
---@type MovingDemoLight[]
local lights = {}
---@type number
local elapsed = 0
---@type number
local period = 8
---@type boolean
local paused = false
---@type boolean
local soft = true

---@description Places all objects on periodic straight-line paths without accumulating motion error.
---@param time number Simulation time in seconds.
---@return nil
local function positionObjects(time)
    for _, object in ipairs(objects) do
        local offset = math.sin(time * 2 * math.pi / period + object.phase)
        object.body:SetPosition(object.x + object.dx * offset, object.y + object.dy * offset, 2)
    end
end

---@description Updates lighting and measures which fixed lights actually rebuild shadows.
---@return nil
local function updateWorld()
    for _, entry in ipairs(lights) do entry.redraws = 0 end
    world:Update()
end

---@description Checks the seven's opaque bar/stem and its open notch in the occluder mask.
---@return nil
local function verifySeven()
    local x, y = objects[5].body:GetPosition()
    for i, entry in ipairs(lights) do
        local light = entry.light
        local lx, ly = light:GetPosition()
        local image = light.ShadowCanvas:newImageData()
        local dpi = light.ShadowCanvas:getDPIScale()
        for _, point in ipairs({ { -20, -30 }, { 0, 20 } }) do
            local sx, sy = x + point[1], y + point[2]
            if (sx - lx)^2 + (sy - ly)^2 < (light.Radius - 3)^2 then
                assert(image:getPixel(math.floor((sx - lx + light.Radius) * dpi),
                    math.floor((sy - ly + light.Radius) * dpi)) < 0.01,
                    "Seven top bar and stem must occlude light " .. i)
            end
        end
        if i == 1 and light.Penumbra
            and (x - 22 - lx)^2 + (y - ly)^2 < (light.Radius - 3)^2 then
            local mask = light.Penumbra.Mask:newImageData()
            assert(select(4, mask:getPixel(math.floor((x - 22 - lx + light.Radius) * dpi),
                math.floor((y - ly + light.Radius) * dpi))) < 0.01,
                "Seven's concave notch must remain open in the occluder silhouette")
        end
    end
end

---@description Samples a deterministic animation pose and verifies it against a complete rebuild.
---@param time number Simulation time in seconds.
---@return string pixels Rendered world pixels before forcing regeneration.
local function verifyPose(time)
    positionObjects(time)
    updateWorld()
    verifySeven()
    if time == 0 then
        local light = lights[1].light
        local x, y = objects[5].body:GetPosition()
        local lx, ly = light:GetPosition()
        local dpi = light.ShadowCanvas:getDPIScale()
        local image = light.ShadowCanvas:newImageData()
        assert(image:getPixel(math.floor((x - 22 - lx + light.Radius) * dpi),
            math.floor((y - ly + light.Radius) * dpi)) > 0.99,
            "The seven must not cast a false shadow into its unobstructed notch")
    end
    local images = { world.Canvas:newImageData():getString() }
    for i, entry in ipairs(lights) do
        images[i + 1] = entry.light.Canvas:newImageData():getString()
    end
    world:ForceUpdate()
    updateWorld()
    assert(images[1] == world.Canvas:newImageData():getString(),
        "Animated world must match a full rebuild at time " .. time)
    for i, entry in ipairs(lights) do
        assert(images[i + 1] == entry.light.Canvas:newImageData():getString(),
            "Animated light " .. i .. " must match a full rebuild at time " .. time)
    end
    return images[1]
end

---@description Checks path reversal, periodicity, multiple shadow sources, and pixel-cache correctness.
---@return nil
local function verifyAnimation()
    local first = verifyPose(0)
    local forward = verifyPose(period / 4)
    assert(first ~= forward, "Moving occluders must change rendered illumination")
    for _, object in ipairs(objects) do
        local x, y = object.body:GetPosition()
        local offset = math.cos(object.phase)
        assert(math.abs(x - object.x - object.dx * offset) < 0.001
            and math.abs(y - object.y - object.dy * offset) < 0.001,
            "Objects must reach their forward path positions")
    end
    local backward = verifyPose(3 * period / 4)
    assert(forward ~= backward, "Return motion must produce a different shadow arrangement")
    for _, object in ipairs(objects) do
        local x, y = object.body:GetPosition()
        local offset = -math.cos(object.phase)
        assert(math.abs(x - object.x - object.dx * offset) < 0.001
            and math.abs(y - object.y - object.dy * offset) < 0.001,
            "Objects must reverse to their backward path positions")
    end
    assert(first == verifyPose(period), "A complete oscillation must return to the initial rendered pose")
    for step = 1, 15 do
        positionObjects(period * step / 16)
        updateWorld()
        verifySeven()
    end
    verifyPose(period)
    updateWorld()
    for _, entry in ipairs(lights) do
        assert(entry.redraws == 0, "Stationary poses must retain cached light shadows")
        local image = entry.light.ShadowCanvas:newImageData()
        local width, height = image:getDimensions()
        local shadowed = 0
        for y = 0, height - 1, 8 do
            for x = 0, width - 1, 8 do
                if image:getPixel(x, y) < 0.5 then shadowed = shadowed + 1 end
            end
        end
        assert(shadowed > 10, "Each light location must cast visible shadows")
    end
    for _, entry in ipairs(lights) do entry.light.Blur = false end
    for step = 0, 15 do
        positionObjects(period * step / 16)
        updateWorld()
        verifySeven()
    end
    verifyPose(0)
    verifyPose(period / 4)
    verifyPose(3 * period / 4)
    for _, entry in ipairs(lights) do entry.light.Blur = soft end
    print("MovingObjects animation and multi-light rendering regressions passed")
end

---@description Creates three fixed lights and five oscillating bodies, including a concave seven.
---@return nil
function love.load()
    world = LightWorld:new()
    world:SetColor(0.055, 0.065, 0.085, 1)
    local sources = {
        { 220, 190, 1, 0.48, 0.22 },
        { 780, 190, 0.25, 0.65, 1 },
        { 500, 500, 0.5, 1, 0.55 },
    }
    for _, source in ipairs(sources) do
        local light = Light:new(world, 340)
        light:SetPosition(source[1], source[2], 1)
        light:SetColor(source[3], source[4], source[5], 1)
        light.SizeRadius = 14
        local entry = { light = light, color = { source[3], source[4], source[5] }, redraws = 0 }
        local render = light.RenderShadowCanvas
        ---@description Records shadow rebuilds while preserving the shared renderer.
        ---@param self Light Light being rendered.
        ---@param x number Light world x-coordinate.
        ---@param y number Light world y-coordinate.
        ---@param z number Light height.
        ---@return nil
        light.RenderShadowCanvas = function(self, x, y, z)
            entry.redraws = entry.redraws + 1
            render(self, x, y, z)
        end
        lights[#lights + 1] = entry
    end
    local paths = {
        { 500, 285, 230, 0, 0 },
        { 380, 330, 0, 125, math.pi / 2 },
        { 640, 345, 90, 90, math.pi },
        { 500, 420, 160, 0, math.pi / 3 },
        { 500, 185, 115, 0, math.pi },
    }
    for i, path in ipairs(paths) do
        local body = Body:new(world)
        local shape
        if i == 5 then
            shape = PolygonShadow:new(body, -32, -40, 32, -40, 32, -22,
                2, 40, -20, 40, 10, -22, -32, -22)
        elseif i % 2 == 1 then
            shape = CircleShadow:new(body, 0, 0, 22)
        else
            shape = PolygonShadow:new(body, -24, -18, 24, -18, 24, 18, -24, 18)
            body:SetAngle(i == 2 and 20 or -25)
        end
        objects[#objects + 1] = {
            body = body, shape = shape, x = path[1], y = path[2],
            dx = path[3], dy = path[4], phase = path[5],
        }
    end
    for _, argument in ipairs(arg or {}) do
        if argument == "--verify" then verifyAnimation() end
    end
    elapsed = capture.auto and 1.25 or 0
    positionObjects(elapsed)
    updateWorld()
end

---@description Advances the looping motion unless paused or capturing a deterministic pose.
---@param dt number Elapsed frame time in seconds.
---@return nil
function love.update(dt)
    if not paused and not capture.auto then elapsed = (elapsed + dt) % period end
    positionObjects(elapsed)
    updateWorld()
end

---@description Draws a tiled floor, motion paths, lit objects, light markers, and animation controls.
---@return nil
function love.draw()
    local width, height = love.graphics.getDimensions()
    love.graphics.origin()
    love.graphics.clear(0.72, 0.75, 0.8, 1)
    love.graphics.setColor(0.58, 0.62, 0.68, 1)
    love.graphics.setLineWidth(1)
    for x = 0, width, 40 do love.graphics.line(x, 0, x, height) end
    for y = 0, height, 40 do love.graphics.line(0, y, width, y) end
    for _, object in ipairs(objects) do
        love.graphics.setColor(0.8, 0.82, 0.86, 1)
        love.graphics.line(object.x - object.dx, object.y - object.dy,
            object.x + object.dx, object.y + object.dy)
        love.graphics.setColor(0.95, 0.95, 0.95, 1)
        object.shape:Draw(math.huge)
    end
    world:Draw()
    for i, entry in ipairs(lights) do
        local x, y = entry.light:GetPosition()
        love.graphics.setColor(unpack(entry.color))
        love.graphics.circle("line", x, y, 12)
        love.graphics.circle("fill", x, y, 5)
        love.graphics.print("Light " .. i, x + 17, y - 7)
    end
    love.graphics.setColor(0.025, 0.035, 0.055, 0.94)
    love.graphics.rectangle("fill", 0, 0, width, 72)
    love.graphics.rectangle("fill", 0, height - 46, width, 46)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("MOVING OBJECTS / MULTIPLE LIGHTS", 20, 16)
    love.graphics.print("Five occluders, including a 7-shaped polygon, move through three fixed colored lights.", 20, 40)
    love.graphics.print("Space: pause | R: restart | B: hard/soft shadows | F12: capture | Esc: exit", 20, height - 34)
    local redraws = 0
    for _, entry in ipairs(lights) do redraws = redraws + entry.redraws end
    love.graphics.print(string.format("%s | %s | shadow redraws: %d/3",
        paused and "Paused" or "Moving", soft and "Soft" or "Hard", redraws), 600, height - 18)
    capture.draw()
end

---@description Handles animation controls and forwards capture and exit keys.
---@param key string Pressed key name.
---@return nil
function love.keypressed(key)
    if key == "space" then
        paused = not paused
    elseif key == "r" then
        elapsed = 0
    elseif key == "b" then
        soft = not soft
        for _, entry in ipairs(lights) do entry.light.Blur = soft end
    else
        capture.keypressed(key)
    end
end

---@description Keeps the composited lighting canvas aligned with the resized window.
---@param width number New logical window width.
---@param height number New logical window height.
---@return nil
function love.resize(width, height)
    world:Resize(width, height)
end
