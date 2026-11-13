---@module Demonstrates rotating polygons and shape-local rotation under three fixed lights.
local capture = require("Capture").new("rotatingobjects-capture.png")
local LightWorld = require("shadows.LightWorld")
local Light = require("shadows.Light")
local Body = require("shadows.Body")
local PolygonShadow = require("shadows.ShadowShapes.PolygonShadow")
local CircleShadow = require("shadows.ShadowShapes.CircleShadow")

---@class RotatingDemoObject
---@field body Body Body at a fixed pivot.
---@field shapes Shadow[] Visible shapes attached to the body.
---@field target Transform Body or shape transform animated by the demo.
---@field x number Fixed world-space pivot x-coordinate.
---@field y number Fixed world-space pivot y-coordinate.
---@field speed number Signed rotation speed in degrees per second.
---@field label string Shape and rotation description.

---@class RotatingDemoLight
---@field light Light Fixed scene light.
---@field color number[] Normalized RGB marker color.

---@type LightWorld
local world
---@type RotatingDemoObject[]
local objects = {}
---@type RotatingDemoLight[]
local lights = {}
---@type number
local elapsed = 0
---@type number
local period = 24
---@type number
local recordedTime = 2.9902296000000002
---@type number
local speed = 1
---@type boolean
local paused = false
---@type boolean
local soft = true
---@type boolean
local snapshotRequested = false
---@type boolean
local snapshotSaving = false
---@type string?
local snapshotMessage
---@type boolean
local verifySnapshot = false

---@description Returns the clickable snapshot button bounds in logical window coordinates.
---@return number x Button left edge.
---@return number y Button top edge.
---@return number width Button width.
---@return number height Button height.
local function snapshotButton()
    return love.graphics.getWidth() - 190, 12, 170, 30
end

---@description Pauses on the current pose and requests matching screenshot and scene metadata.
---@return nil
local function requestSnapshot()
    if snapshotRequested or snapshotSaving then return end
    paused = true
    snapshotRequested = true
    snapshotMessage = nil
end

---@description Serializes the exact rendered animation, shape geometry, transforms, lights, and DPI.
---@return string text Reproduction settings with full numeric precision.
local function snapshotText()
    local width, height = love.graphics.getDimensions()
    local pixelWidth, pixelHeight = love.graphics.getPixelDimensions()
    local major, minor, revision = love.getVersion()
    local lines = {
        "RotatingObjects scene snapshot",
        string.format("LOVE version: %d.%d.%d", major, minor, revision),
        string.format("Window logical size: %d x %d", width, height),
        string.format("Window pixel size: %d x %d", pixelWidth, pixelHeight),
        string.format("World canvas DPI: %.17g", world.Canvas:getDPIScale()),
        string.format("Animation elapsed: %.17g", elapsed),
        string.format("Animation speed: %.17g period: %.17g paused: %s soft: %s",
            speed, period, tostring(paused), tostring(soft)),
        string.format("Camera x y scale: %.17g %.17g %.17g", world:GetPosition()),
        string.format("Ambient RGBA: %.17g %.17g %.17g %.17g", world.R, world.G, world.B, world.A),
    }
    for i, object in ipairs(objects) do
        local x, y, z = object.body:GetPosition()
        lines[#lines + 1] = string.format(
            "Object %d: %s position=%.17g,%.17g,%.17g bodyAngle=%.17g targetAngle=%.17g speed=%.17g",
            i, object.label, x, y, z, object.body:GetAngle(),
            object.target:GetLocalRotation(), object.speed)
        for j, shape in ipairs(object.shapes) do
            local transform = shape:GetTransform()
            local sx, sy, sz = transform:GetLocalPosition()
            lines[#lines + 1] = string.format(
                "  Shape %d: localPosition=%.17g,%.17g,%.17g localAngle=%.17g worldAngle=%.17g radius=%.17g",
                j, sx, sy, sz, transform:GetLocalRotation(), transform:GetRotation(), shape:GetRadius())
            if getmetatable(shape) == PolygonShadow then
                ---@cast shape PolygonShadow
                local localVertices, worldVertices = {}, {}
                for k, value in ipairs(shape.Vertices) do localVertices[k] = string.format("%.17g", value) end
                for k, value in ipairs(shape:GetVertices()) do worldVertices[k] = string.format("%.17g", value) end
                local cx, cy, cz = shape.CentroidTransform:GetLocalPosition()
                lines[#lines + 1] = string.format("  Polygon centroid local: %.17g %.17g %.17g", cx, cy, cz)
                lines[#lines + 1] = "  Polygon centered vertices: " .. table.concat(localVertices, ",")
                lines[#lines + 1] = "  Polygon world vertices: " .. table.concat(worldVertices, ",")
            end
        end
    end
    for i, entry in ipairs(lights) do
        local light = entry.light
        local x, y, z = light:GetPosition()
        lines[#lines + 1] = string.format(
            "Light %d: position=%.17g,%.17g,%.17g radius=%.17g angle=%.17g arc=%.17g blur=%s sourceRadius=%.17g",
            i, x, y, z, light.Radius, light:GetAngle(), light.Arc, tostring(light.Blur), light.SizeRadius)
        lines[#lines + 1] = string.format("  RGBA: %.17g %.17g %.17g %.17g", light:GetColor())
        lines[#lines + 1] = string.format("  Canvas DPI: %.17g", light.Canvas:getDPIScale())
    end
    return table.concat(lines, "\n") .. "\n"
end

---@description Saves screenshot and metadata from the same paused rendered frame without exiting.
---@return nil
local function saveSnapshot()
    local text = snapshotText()
    local base = verifySnapshot and ("rotating-scene-verify-" .. tostring(love.timer.getTime())) or "rotating-scene"
    local pixelWidth, pixelHeight = love.graphics.getPixelDimensions()
    snapshotRequested = false
    snapshotSaving = true
    ---@description Persists matching pixels and state, reporting failures explicitly.
    ---@param image love.ImageData Captured window pixels.
    ---@return nil
    love.graphics.captureScreenshot(function(image)
        assert(love.filesystem.write(base .. ".png", image:encode("png")))
        assert(love.filesystem.write(base .. ".txt", text))
        snapshotSaving = false
        snapshotMessage = "Saved rotating-scene.png + .txt (LOVE save folder); Space to resume"
        print("Saved rotating scene snapshot to " .. love.filesystem.getSaveDirectory() .. "/" .. base .. ".png and .txt")
        if verifySnapshot then
            assert(paused, "Snapshot must pause the scene")
            assert(image:getWidth() == pixelWidth and image:getHeight() == pixelHeight,
                "Snapshot must match window pixel dimensions")
            assert(love.filesystem.read(base .. ".txt") == text, "Snapshot metadata must round-trip exactly")
            local saved = love.image.newImageData(base .. ".png")
            assert(saved:getString() == image:getString(), "Saved screenshot must preserve captured pixels")
            assert(text:find("Object 3: Pentagon / body rotation", 1, true), "Snapshot must identify the pentagon")
            assert(text:find("Polygon world vertices:", 1, true), "Snapshot must include transformed vertices")
            assert(text:find("Light 3: position=", 1, true), "Snapshot must include every light")
            assert(text:find(string.format("Animation elapsed: %.17g", elapsed), 1, true),
                "Snapshot must record the paused animation time")
            assert(love.filesystem.remove(base .. ".png"))
            assert(love.filesystem.remove(base .. ".txt"))
            print("RotatingObjects snapshot button and screenshot/state regressions passed")
            love.event.quit()
        end
    end)
end

---@description Sets each rotor's absolute angle, keeping animation frame-rate independent and periodic.
---@param time number Simulation time in seconds.
---@return nil
local function rotateObjects(time)
    for _, object in ipairs(objects) do
        object.target:SetLocalRotation((time * object.speed) % 360)
    end
end

---@description Compares complete cached rendering with a forced rebuild at a deterministic rotation.
---@param time number Simulation time in seconds.
---@return string pixels World illumination at the requested pose.
local function verifyPose(time)
    rotateObjects(time)
    world:Update()
    local canvases = { world.Canvas }
    for _, entry in ipairs(lights) do
        canvases[#canvases + 1] = entry.light.Canvas
        canvases[#canvases + 1] = entry.light.ShadowCanvas
    end
    local images = {}
    for i, canvas in ipairs(canvases) do images[i] = canvas:newImageData():getString() end
    world:ForceUpdate()
    world:Update()
    for i, canvas in ipairs(canvases) do
        assert(images[i] == canvas:newImageData():getString(),
            "Rotation at time " .. time .. " must match a full rebuild (canvas " .. i .. ")")
    end
    for _, object in ipairs(objects) do
        local expected = (time * object.speed) % 360
        local x, y = object.body:GetPosition()
        assert(x == object.x and y == object.y, "Body rotation must preserve its fixed pivot")
        assert(math.abs((object.target:GetLocalRotation() - expected + 180) % 360 - 180) < 0.001,
            "Clockwise and counterclockwise angles must match their signed speeds")
    end
    return images[1]
end

---@description Checks that the pentagon silhouette remains occluded by every light below it.
---@param time number Animation time to reproduce.
---@return nil
local function verifyPentagonSilhouette(time)
    rotateObjects(time)
    world:Update()
    local pentagon = objects[3].shapes[1]
    ---@cast pentagon PolygonShadow
    local vertices = pentagon:GetVertices()
    for i, entry in ipairs(lights) do
        local light = entry.light
        local lx, ly = light:GetPosition()
        local image = light.ShadowCanvas:newImageData()
        local dpi = light.ShadowCanvas:getDPIScale()
        for j = 1, #vertices, 2 do
            local x = 310 + (vertices[j] - 310) * 0.7
            local y = 460 + (vertices[j + 1] - 460) * 0.7
            if (x - lx)^2 + (y - ly)^2 < (light.Radius - 2)^2 then
                local visibility = image:getPixel(math.floor((x - lx + light.Radius) * dpi),
                    math.floor((y - ly + light.Radius) * dpi))
                assert(visibility < 0.01, string.format(
                    "Pentagon at time %.17g must occlude light %d at %.3f,%.3f; visibility=%.3f",
                    time, i, x, y, visibility))
            end
        end
    end
end

---@description Checks body and local-shape rotation, stable pivots, multiple lights, and cached rendering.
---@return nil
local function verifyAnimation()
    for _, blur in ipairs({ true, false }) do
        for _, entry in ipairs(lights) do entry.light.Blur = blur end
        verifyPentagonSilhouette(recordedTime)
        if not blur then
            for time = 0, 11 do verifyPentagonSilhouette(time) end
        end
        local first = verifyPose(0)
        local turned = verifyPose(2)
        assert(first ~= turned, "Rotating polygons must change their projected shadows")
        verifyPose(4)
        assert(first == verifyPose(period), "All rotors must return to their initial pose after a full loop")
        local localObject = objects[4]
        local sibling = localObject.shapes[2]
        local x, y = sibling:GetPosition()
        verifyPose(1)
        local nextX, nextY = sibling:GetPosition()
        assert(x == nextX and y == nextY and localObject.body:GetAngle() == 0,
            "Shape-local rotation must not move its stationary sibling or rotate its body")
        world:Update()
        for _, entry in ipairs(lights) do
            assert(not entry.light.Changed and not entry.light.ShadowChanged,
                "Stationary poses must clear shadow invalidation")
            local image = entry.light.ShadowCanvas:newImageData()
            local width, height = image:getDimensions()
            local shadowed = 0
            for py = 0, height - 1, 8 do
                for px = 0, width - 1, 8 do
                    if image:getPixel(px, py) < 0.5 then shadowed = shadowed + 1 end
                end
            end
            assert(shadowed > 10, "Every fixed light must cast visible polygon shadows")
        end
    end
    for _, object in ipairs(objects) do
        assert(object.target == object.body:GetTransform()
            or object.target:GetParent() == object.body:GetTransform(),
            "Rotation targets must remain attached to their fixed pivots")
    end
    for _, entry in ipairs(lights) do entry.light.Blur = soft end
    print("RotatingObjects clockwise, counterclockwise, local-shape, and rendering regressions passed")
end

---@description Creates three colored lights and rectangle, triangle, pentagon, and local-rotation examples.
---@return nil
function love.load()
    world = LightWorld:new()
    world:SetColor(0.06, 0.07, 0.09, 1)
    local sources = {
        { 170, 170, 1, 0.5, 0.25 },
        { 830, 170, 0.3, 0.65, 1 },
        { 500, 575, 0.55, 1, 0.65 },
    }
    for _, source in ipairs(sources) do
        local light = Light:new(world, 400)
        light:SetPosition(source[1], source[2], 1)
        light:SetColor(source[3], source[4], source[5], 1)
        light.SizeRadius = 12
        lights[#lights + 1] = { light = light, color = { source[3], source[4], source[5] } }
    end
    local examples = {
        { 330, 250, 45, "Rectangle / body rotation", { -48, -14, 48, -14, 48, 14, -48, 14 } },
        { 670, 250, -60, "Triangle / reverse rotation", { 0, -40, 35, 25, -35, 25 } },
        { 310, 460, 30, "Pentagon / body rotation",
            { 0, -40, 38, -12, 24, 32, -24, 32, -38, -12 } },
        { 670, 460, -90, "Local rotor / fixed circle", { -48, -10, 48, -10, 48, 10, -48, 10 } },
    }
    for i, example in ipairs(examples) do
        local body = Body:new(world)
        body:SetPosition(example[1], example[2], 2)
        local polygon = PolygonShadow:new(body, unpack(example[5]))
        ---@type Shadow[]
        local shapes = { polygon }
        local target = body:GetTransform()
        if i == 4 then
            target = polygon:GetTransform()
            shapes[#shapes + 1] = CircleShadow:new(body, 72, 0, 15)
        end
        objects[#objects + 1] = {
            body = body, shapes = shapes, target = target, speed = example[3], label = example[4],
            x = example[1], y = example[2],
        }
    end
    for _, argument in ipairs(arg or {}) do
        if argument == "--verify" then verifyAnimation() end
        if argument == "--snapshot-verify" then verifySnapshot = true end
    end
    elapsed = capture.auto and recordedTime or 0
    rotateObjects(elapsed)
    world:Update()
    if verifySnapshot then
        local x, y = snapshotButton()
        love.mousepressed(x + 5, y + 5, 2)
        assert(not snapshotRequested, "Only left clicks may request a snapshot")
        love.mousepressed(0, 0, 1)
        assert(not snapshotRequested, "Clicks outside the snapshot button must be ignored")
        love.mousepressed(x + 5, y + 5, 1)
        assert(snapshotRequested and paused, "Snapshot button must request capture and pause")
    end
end

---@description Advances continuous rotation unless paused or capturing a deterministic pose.
---@param dt number Elapsed frame time in seconds.
---@return nil
function love.update(dt)
    if not paused and not capture.auto then elapsed = (elapsed + dt * speed) % period end
    rotateObjects(elapsed)
    world:Update()
end

---@description Draws a tiled floor, rotating silhouettes, pivot indicators, and fixed light markers.
---@return nil
function love.draw()
    local width, height = love.graphics.getDimensions()
    love.graphics.origin()
    love.graphics.clear(0.72, 0.75, 0.8, 1)
    love.graphics.setColor(0.58, 0.62, 0.68, 1)
    love.graphics.setLineWidth(1)
    for x = 0, width, 40 do love.graphics.line(x, 0, x, height) end
    for y = 0, height, 40 do love.graphics.line(0, y, width, y) end
    love.graphics.setColor(0.95, 0.95, 0.95, 1)
    for _, object in ipairs(objects) do
        for _, shape in ipairs(object.shapes) do shape:Draw(math.huge) end
    end
    world:Draw()
    for _, object in ipairs(objects) do
        local x, y = object.body:GetPosition()
        local angle = object.target:GetRadians()
        love.graphics.setColor(0.9, 0.92, 0.96, 0.85)
        love.graphics.circle("fill", x, y, 3)
        love.graphics.line(x, y, x + 24 * math.cos(angle), y + 24 * math.sin(angle))
        love.graphics.printf(object.label, x - 140, y + 65, 280, "center")
        love.graphics.printf(string.format("%+.0f deg/s", object.speed * speed),
            x - 100, y + 83, 200, "center")
    end
    for i, entry in ipairs(lights) do
        local x, y = entry.light:GetPosition()
        love.graphics.setColor(unpack(entry.color))
        love.graphics.circle("line", x, y, 12)
        love.graphics.circle("fill", x, y, 5)
        love.graphics.print("Light " .. i, x + 17, y - 7)
    end
    love.graphics.setColor(0.025, 0.035, 0.055, 0.94)
    love.graphics.rectangle("fill", 0, 0, width, 72)
    love.graphics.rectangle("fill", 0, height - 54, width, 54)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("ROTATING OBJECTS / POLYGON SHADOWS", 20, 16)
    love.graphics.print("Clockwise and counterclockwise body rotation, plus a shape-local rotor with a fixed sibling.", 20, 40)
    love.graphics.print("Space: pause | R: restart | Up/Down: speed | B: hard/soft | F9: snapshot | F12: capture | Esc: exit",
        20, height - 42)
    love.graphics.print(snapshotMessage or string.format("%s | %s shadows | Speed %.2fx",
        paused and "Paused" or "Rotating", soft and "Soft" or "Hard", speed), 20, height - 23)
    local bx, by, bw, bh = snapshotButton()
    love.graphics.setColor(0.18, 0.32, 0.45, 1)
    love.graphics.rectangle("fill", bx, by, bw, bh, 4, 4)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Snapshot scene [F9]", bx, by + 7, bw, "center")
    if snapshotRequested then saveSnapshot() end
    if not verifySnapshot then capture.draw() end
end

---@description Handles animation, speed, softness, capture, and exit controls.
---@param key string Pressed key name.
---@return nil
function love.keypressed(key)
    if snapshotRequested or snapshotSaving then return end
    if key == "f9" then
        requestSnapshot()
    elseif key == "space" then
        paused = not paused
        snapshotMessage = nil
    elseif key == "r" then
        elapsed = 0
    elseif key == "up" then
        speed = math.min(4, speed * 2)
    elseif key == "down" then
        speed = math.max(0.25, speed / 2)
    elseif key == "b" then
        soft = not soft
        for _, entry in ipairs(lights) do entry.light.Blur = soft end
    else
        capture.keypressed(key)
    end
end

---@description Requests a scene snapshot when the on-screen button is left-clicked.
---@param x number Mouse x-coordinate in logical window units.
---@param y number Mouse y-coordinate in logical window units.
---@param button integer Mouse button index.
---@return nil
function love.mousepressed(x, y, button)
    local bx, by, bw, bh = snapshotButton()
    if button == 1 and x >= bx and x <= bx + bw and y >= by and y <= by + bh then
        requestSnapshot()
    end
end

---@description Resizes the world lighting canvas with the window.
---@param width number New logical window width.
---@param height number New logical window height.
---@return nil
function love.resize(width, height)
    world:Resize(width, height)
end
