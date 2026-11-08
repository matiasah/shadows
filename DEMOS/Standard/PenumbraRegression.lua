--- Reproduces and checks a shadow edge near adjacent map occluders.
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

return Regression
