---@module Shows hard and contact-hardening shadows side by side with adjustable source size.
local capture = require("Capture").new("penumbra-capture.png")
local LightWorld = require("shadows.LightWorld")
local Star = require("shadows.Star")
local Body = require("shadows.Body")
local PolygonShadow = require("shadows.ShadowShapes.PolygonShadow")
local CircleShadow = require("shadows.ShadowShapes.CircleShadow")

--- @type LightWorld[]
local worlds = {}
--- @type Star[]
local lights = {}
--- @type number
local lightX = 80
--- @type string[]
local qualityPresets = { "high", "medium", "low" }

--- @description Applies the selected preset to both comparison worlds.
--- @param Preset string Rendering preset name.
--- @return nil
local function setQuality(Preset)
	for _, world in ipairs(worlds) do
		world.Settings:SetQuality(Preset)
	end
end

--- @description Cycles both comparison worlds through the available presets.
--- @return nil
local function cycleQuality()
	local current = worlds[1].Settings:GetQuality()
	local index = 1
	for i, preset in ipairs(qualityPresets) do
		if current == preset then
			index = i
			break
		end
	end
	setQuality(qualityPresets[index % #qualityPresets + 1])
end

--- @description Creates matching hard and soft polygon/circle shadow scenes.
--- @return nil
function love.load()
    for _, argument in ipairs(arg or {}) do
        if argument == "--verify" then
            require("Regression").run()
            require("AntialiasRegression").run()
            require("CacheRegression").run()
        end
    end
    for i = 1, 2 do
        local world = LightWorld:new()
        local light = Star:new(world, 1400)
        light:SetPosition(lightX, 240, 1)
        light.Blur = i == 2
        light.SizeRadius = 18
        local body = Body:new(world)
        body:SetPosition(190, 170, 2)
        PolygonShadow:new(body, -12, -22, 12, -22, 12, 22, -12, 22)
        CircleShadow:new(body, 0, 120, 20)
        worlds[i], lights[i] = world, light
    end
end

--- @description Regenerates cached scene illumination.
--- @return nil
function love.update()
    for _, world in ipairs(worlds) do world:Update() end
end

--- @description Draws a labeled hard-shadow and penumbra comparison.
--- @return nil
function love.draw()
    for i, world in ipairs(worlds) do
        love.graphics.push("all")
        love.graphics.origin()
        love.graphics.setScissor((i - 1) * 500, 0, 500, 480)
        love.graphics.translate((i - 1) * 500, 0)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 0, 0, 500, 480)
        love.graphics.setBlendMode("multiply", "premultiplied")
        love.graphics.draw(world.Canvas)
        love.graphics.setBlendMode("alpha", "alphamultiply")
        love.graphics.setColor(0.1, 0.1, 0.1, 1)
        love.graphics.print(i == 1 and "Hard shadows" or "Contact-hardening penumbras", 12, 12)
        love.graphics.pop()
    end
        local quality = worlds[1].Settings:GetQuality()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 454, 1000, 26)
    love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(string.format("Quality: %s | Q quality | Source radius: %.0f | Light x: %.0f | +/- size | Left/Right move light | F12 capture | Esc exit",
            quality, lights[2].SizeRadius, lightX), 12, 460)
    capture.draw()
end

--- @description Adjusts source radius or forwards screenshot and exit controls.
--- @param key string Pressed key name.
--- @return nil
function love.keypressed(key)
    if key == "q" then
        cycleQuality()
    elseif key == "=" or key == "+" or key == "kp+" then
        lights[2].SizeRadius = lights[2].SizeRadius + 2
    elseif key == "-" or key == "kp-" then
        lights[2].SizeRadius = math.max(0, lights[2].SizeRadius - 2)
    elseif key == "left" or key == "right" then
        lightX = math.max(-500, math.min(160, lightX + (key == "left" and -20 or 20)))
        for _, light in ipairs(lights) do light:SetPosition(lightX, 240, 1) end
    else
        capture.keypressed(key)
    end
end
