---@module Reproduces and checks shadow edges near Standard map occluders.
local Regression = {}

--- @description Checks continuity where the nearest silhouette changes from a wall to a casting crate.
--- @param world LightWorld Standard demo world containing the imported map.
--- @param light Light Active light whose shadow is checked.
--- @return nil
function Regression.run(world, light)
    world:SetPosition(259.4365, 1157.86405, 1)
    light:SetPosition(691.4365, 1506.86405, 1)
    world:Update()
    local field = light.Penumbra.Field:newImageData()
    local canvas = light.Canvas:newImageData()
    local dpi = light.Canvas:getDPIScale()
    for _, y in ipairs({ 318, 322, 326, 330, 334, 338, 342 }) do
        local py = math.floor((y - 349 + 300) * dpi)
        local left = math.floor((328 - 432 + 300) * dpi)
        local right = math.floor((336 - 432 + 300) * dpi)
        local switched = false
        for px = left, right - 1 do
            local blocker = field:getPixel(px, py)
            local nextBlocker = field:getPixel(px + 1, py)
            local current = canvas:getPixel(px, py)
            local nextValue = canvas:getPixel(px + 1, py)
            if (nextBlocker - blocker) * 600 > 100 then
                switched = true
                assert(current > 0.05 and nextValue > 0.05, "Both sides must retain a visible penumbra")
                assert(math.abs(current - nextValue) < 0.03, string.format(
                    "Penumbra must remain continuous at y=%d, DPI=%.1f (%.3f vs %.3f)",
                    y, dpi, current, nextValue))
            end
        end
        assert(switched, "Regression scene must switch nearest occluders across the seam")
    end
    print(string.format("Standard shadow continuity regression passed at DPI %.1f", dpi))
end

--- @description Checks that a nearby wall does not leave a bright streak in the crate penumbra.
--- @param world LightWorld Standard demo world containing the imported map.
--- @param light Light Active light whose shadow is checked.
--- @return nil
function Regression.checkStain(world, light)
    world:SetPosition(476.3674, 1101.48365, 1)
    light:SetPosition(580.3674, 1588.48365, 1)
    world:Update()
    local dpi = light.Canvas:getDPIScale()
    local canvas = light.Canvas:newImageData()
    for _, y in ipairs({ 520, 530, 540, 550, 557 }) do
        local py = math.floor((y - 487 + 300) * dpi)
        local left = math.floor((37 - 104 + 300) * dpi)
        local right = math.floor((41 - 104 + 300) * dpi)
        for px = left, right - 1 do
            local current, nextValue = canvas:getPixel(px, py), canvas:getPixel(px + 1, py)
            assert(current < 0.8 and math.abs(current - nextValue) < 0.1, string.format(
                "Wall penumbra must not contain a bright streak at y=%d, DPI=%.1f (%.3f vs %.3f)",
                y, dpi, current, nextValue))
        end
    end
    for _, x in ipairs({ 45, 50, 55, 60, 65 }) do
        local px = math.floor((x - 104 + 300) * dpi)
        local top = math.floor((558 - 487 + 300) * dpi)
        local bottom = math.floor((561 - 487 + 300) * dpi)
        for py = top, bottom - 1 do
            local current, nextValue = canvas:getPixel(px, py), canvas:getPixel(px, py + 1)
            assert(current < 0.8 and math.abs(current - nextValue) < 0.1, string.format(
                "Floor penumbra must not contain a bright streak at x=%d, DPI=%.1f (%.3f vs %.3f)",
                x, dpi, current, nextValue))
        end
    end
    print(string.format("Standard corner penumbra regression passed at DPI %.1f", dpi))
end

--- @description Checks a zoomed crate penumbra for bright seams across the visible shadow edge.
--- @param world LightWorld Standard demo world containing the imported map.
--- @param light Light Active light whose shadow is checked.
--- @return nil
function Regression.checkLines(world, light)
    world:SetPosition(833.36115, 1042.5998, 1.45)
    light:SetPosition(1062.32666724138, 1244.66876551724, 1)
    world:Update()
    local dpi = light.Canvas:getDPIScale()
    local canvas = light.Canvas:newImageData()
    for _, x in ipairs({ 150, 180, 210, 240, 260 }) do
        local px = math.floor(((x - 332) / 1.45 + 300) * dpi)
        local first = math.floor(((275 - 293) / 1.45 + 300) * dpi)
        local last = math.floor(((310 - 293) / 1.45 + 300) * dpi)
        for py = first, last - 1 do
            local current, nextValue = canvas:getPixel(px, py), canvas:getPixel(px, py + 1)
            assert(nextValue - current < 0.06, string.format(
                "Crate penumbra must not brighten toward the shadow at x=%d DPI=%.1f (%.3f to %.3f)",
                x, dpi, current, nextValue))
        end
    end
    print(string.format("Standard internal penumbra regression passed at DPI %.1f", dpi))
end

--- @description Checks for an internal bright band along a captured wall-edge penumbra.
--- @param world LightWorld Standard demo world containing the imported map.
--- @param light Light Active light whose shadow is checked.
--- @return nil
function Regression.checkWallLines(world, light)
    world:SetPosition(641.5133, 1335.01265, 1)
    light:SetPosition(1186.5133, 1737.01265, 1)
    world:Update()
    local dpi = light.Canvas:getDPIScale()
    local image = light.Canvas:newImageData()
    for _, y in ipairs({ 275, 300, 325, 350 }) do
        local py = math.floor((y - 402 + 300) * dpi)
        local first = math.floor((545 - 545 + 300) * dpi)
        local last = math.floor((551 - 545 + 300) * dpi)
        local firstValue = image:getPixel(first, py)
        local lastValue = image:getPixel(last, py)
        assert(firstValue - lastValue < 0.06, string.format(
            "Wall penumbra must not contain a bright band at y=%d, DPI=%.1f (%.3f vs %.3f)",
            y, dpi, firstValue, lastValue))
    end
    print(string.format("Standard wall-edge penumbra regression passed at DPI %.1f", dpi))
end

--- @description Checks wall contact at the saved square wall scene at two DPI scales.
--- @param world LightWorld Standard demo world containing the imported map.
--- @param light Light Active light whose shadow is checked.
--- @return nil
function Regression.checkContact(world, light)
    world:SetPosition(125.091, 759.1683, 1)
    light:SetPosition(521.091, 1031.1683, 20)
    for _, dpi in ipairs({ 1, 2 }) do
        light:DestroyCanvas()
        light.Canvas = love.graphics.newCanvas(1000, 1000, { dpiscale = dpi })
        light.ShadowCanvas = love.graphics.newCanvas(1000, 1000, { dpiscale = dpi, mipmaps = "manual" })
        light.ShadowCanvas:setMipmapFilter("linear")
        light.ShadowRenderCanvas = love.graphics.newCanvas(1000, 1000, { dpiscale = dpi, msaa = 4 })
        light.Shapes = {}
        light.Blur = false
        world:ForceUpdate()
        world:Update()
        local hard = light.Canvas:newImageData()
        light.Blur = true
        world:Update()
        local soft = light.Canvas:newImageData()
        for _, point in ipairs({
            { 565, 425 }, { 580, 425 }, { 595, 425 }, { 610, 425 }, { 625, 425 },
            { 643, 340 }, { 643, 355 }, { 643, 370 }, { 643, 385 }, { 643, 400 },
        }) do
            local px = math.floor((point[1] + 104) * dpi)
            local py = math.floor((point[2] + 228) * dpi)
            local hardValue, softValue = hard:getPixel(px, py), soft:getPixel(px, py)
            assert(hardValue < 0.02 and softValue < 0.03, string.format(
                "Wall contact must remain dark at (%d,%d), DPI %d: hard %.3f soft %.3f",
                point[1], point[2], dpi, hardValue, softValue))
        end
        local casterX, casterY = math.floor((580 + 104) * dpi), math.floor((420 + 228) * dpi)
        assert(math.abs(hard:getPixel(casterX, casterY) - soft:getPixel(casterX, casterY)) < 0.01,
            "The lit wall surface must retain its original brightness")
        local clearX, clearY = math.floor((580 + 104) * dpi), math.floor((435 + 228) * dpi)
        assert(soft:getPixel(clearX, clearY) > 0.2, "The shadow's distant edge must still soften")
    end
    print("Standard wall-contact regression passed at DPI 1 and 2")
end

---@description Checks the composed map for light leaking outside the pixel-aligned wall.
---@param world LightWorld Standard world with the camera and light synchronized.
---@param light Light Active light in the captured scene.
---@param map table Loaded STI tile map.
---@return nil
function Regression.checkCameraAlignment(world, light, map)
    local x, y, zoom = world:GetPosition()
    local output = love.graphics.newCanvas(1000, 600, { dpiscale = 1 })
    love.graphics.push("all")
    for _, blur in ipairs({ false, true }) do
        light.Blur = blur
        world:Update()
        love.graphics.setCanvas(output)
        love.graphics.origin()
        love.graphics.setColor(1, 1, 1, 1)
        map:draw(-x, -y, zoom, zoom)
        love.graphics.setCanvas()
        local diffuse = output:newImageData()
        love.graphics.setCanvas(output)
        world:Draw()
        love.graphics.setCanvas()
        local composed = output:newImageData()
        for _, point in ipairs({ { 580, 450 }, { 642, 380 } }) do
            local r = diffuse:getPixel(point[1], point[2])
            local lit = composed:getPixel(point[1], point[2])
            assert(math.abs(lit - r * world.R) < 0.01, string.format(
                "The floor beside the wall must be shadowed at (%d,%d), blur=%s: %.3f vs %.3f",
                point[1], point[2], tostring(blur), lit, r * world.R))
        end
    end
    love.graphics.setCanvas()
    love.graphics.pop()
    print("Standard map and shadow camera-alignment regression passed")
end

return Regression
