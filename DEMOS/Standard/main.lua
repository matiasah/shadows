--- Runs the interactive map, physics-import, and shadow-type showcase.
local capture       = require("Capture").new("standard-capture.png")
local shadows       = require("shadows")
local sti           = require("sti")

local LightWorld    = require("shadows.LightWorld")
local Light         = require("shadows.Light")
local NormalShadow  = require("shadows.ShadowShapes.NormalShadow")
local HeightShadow  = require("shadows.ShadowShapes.HeightShadow")
local Star          = require("shadows.Star")
local Body          = require("shadows.Body")
local PolygonShadow = require("shadows.ShadowShapes.PolygonShadow")
local CircleShadow  = require("shadows.ShadowShapes.CircleShadow")
local ImageShadow   = require("shadows.ShadowShapes.ImageShadow")

---@type boolean
local snapshotRequested = false
---@type string?
local snapshotMessage
---@type number
local snapshotMessageUntil = 0
---@type boolean
local verifySnapshot = false
---@type boolean
local verifyStarted = false
---@type boolean
local verifyShadow = false
---@type boolean
local verifyStain = false
---@type boolean
local verifyLines = false
---@type boolean
local verifyWallLines = false

for _, argument in ipairs(arg or {}) do
	if argument == "--verify" then verifySnapshot = true end
	if argument == "--shadow-verify" then verifyShadow = true end
	if argument == "--stain-verify" then verifyStain = true end
	if argument == "--line-verify" then verifyLines = true end
	if argument == "--wall-line-verify" then verifyWallLines = true end
end

if verifySnapshot or verifyShadow or verifyStain or verifyLines or verifyWallLines then
	--- @description Reports automated snapshot failures and exits with a failure status.
	--- @param message string Error message.
	--- @return function quit Function returning the failing process exit code.
	love.errorhandler = function(message)
		print(debug.traceback(message, 2))
		--- @description Returns a failing process exit code.
		--- @return integer status Failure exit code.
		return function() return 1 end
	end
end

---@class StandardTranslation
---@field x number Camera x-coordinate.
---@field y number Camera y-coordinate.
---@field z number Camera zoom factor.
---@type StandardTranslation
translation         = { x = 0, y = 0, z = 1 }

---@type LightWorld
LWorld              = LightWorld:new()
LWorld:SetColor(40, 40, 40, 255)
---@type Light
L = Light:new(LWorld, 500)
L:SetColor(255, 255, 255, 255)
L:SetPosition(400, 400, 20)

--local S = Star:new(LWorld, 50000)
--S:SetColor(255, 255, 255, 255)
--S:SetPosition(-5000, -5000, 400)

---@type Body
testBody = Body:new(LWorld)
testBody:SetPosition(0, 0, 1.3)

---@type Body
testBody2 = Body:new(LWorld)
testBody2:SetPosition(0, 0, 1.3)

---@type Body
testBody3 = Body:new(LWorld)
testBody3:SetPosition(0, 0, 1.3)

---@type Body
testBody4 = Body:new(LWorld)
testBody4:SetPosition(0, 0, 1.3)

CircleShadow:new(testBody, 200, 180, 50)

---@type NormalShadow
nm = NormalShadow:new(testBody2, love.graphics.newImage("DEMOS/Standard/normalmap.png"))
---@type love.Image
nm.Img = love.graphics.newImage("DEMOS/Standard/texture.png")
nm:SetPosition(500, 600)

---@type HeightShadow
hm = HeightShadow:new(testBody3, love.graphics.newImage("DEMOS/Standard/heightmap.png"))
---@type love.Image
hm.Img = love.graphics.newImage("DEMOS/Standard/heightmaptexture.png")
hm:SetPosition(200, 200)

---@type ImageShadow
is = ImageShadow:new(testBody4, love.graphics.newImage("DEMOS/Standard/heightmap.png"))
is:SetPosition(500, 200)

--- @description Records the current rendered scene and queues its matching screenshot.
--- @return nil
local function saveSceneSnapshot()
	local cameraX, cameraY, zoom = LWorld:GetPosition()
	local mouseX, mouseY = love.mouse.getPosition()
	local width, height = love.graphics.getDimensions()
	local pixelWidth, pixelHeight = love.graphics.getPixelDimensions()
	local major, minor, revision = love.getVersion()
	local lines = {
		"Standard demo scene snapshot",
		string.format("LÖVE version: %d.%d.%d", major, minor, revision),
		string.format("Window logical size: %d x %d", width, height),
		string.format("Window pixel size: %d x %d", pixelWidth, pixelHeight),
		string.format("World canvas DPI scale: %.17g", LWorld.Canvas:getDPIScale()),
		string.format("Camera x y zoom: %.17g %.17g %.17g", cameraX, cameraY, zoom),
		string.format("Mouse x y: %.17g %.17g", mouseX, mouseY),
		string.format("Circle sample removed: %s", tostring(testBody.World == nil)),
	}
	for index, light in ipairs(LWorld.Lights) do
		local x, y, z = light:GetPosition()
		local r, g, b, a = light:GetColor()
		lines[#lines + 1] = string.format(
			"Light %d: position=%.17g,%.17g,%.17g radius=%.17g sizeRadius=%.17g blur=%s color=%d,%d,%d,%d active=%s canvasDPI=%s",
			index, x, y, z, light:GetRadius(), light.SizeRadius, tostring(light.Blur),
			r, g, b, a, tostring(light == L),
			light.Canvas and string.format("%.17g", light.Canvas:getDPIScale()) or "not allocated")
	end
	local text = table.concat(lines, "\n") .. "\n"
	local base = verifySnapshot and ("standard-scene-verify-" .. tostring(love.timer.getTime())) or "standard-scene"
	--- @description Writes the screenshot and state from the same rendered frame.
	--- @param image love.ImageData Captured window pixels.
	--- @return nil
	love.graphics.captureScreenshot(function(image)
		assert(love.filesystem.write(base .. ".png", image:encode("png")))
		assert(love.filesystem.write(base .. ".txt", text))
		local path = love.filesystem.getSaveDirectory()
		print("Saved scene snapshot to " .. path .. "/" .. base .. ".png and .txt")
		snapshotMessage = "Saved standard-scene.png and standard-scene.txt in the LOVE save directory"
		snapshotMessageUntil = love.timer.getTime() + 5
		snapshotRequested = false
		if verifySnapshot then
			assert(love.filesystem.read(base .. ".txt") == text, "Scene snapshot text did not round-trip")
			assert(love.filesystem.getInfo(base .. ".png", "file"), "Scene snapshot screenshot was not saved")
			assert(image:getWidth() == pixelWidth and image:getHeight() == pixelHeight,
				"Scene screenshot dimensions must match the captured window")
			assert(text:find("Camera x y zoom: 180 210 1", 1, true), "Camera state must be recorded")
			assert(text:find("Circle sample removed: true", 1, true), "Removed sample must be recorded")
			assert(text:find("Light 1: position=400,400,20 radius=500", 1, true),
				"Previous light position and radius must be recorded")
			assert(text:find("Light 2:", 1, true) and text:find("active=true", 1, true),
				"Added active light must be recorded")
			assert(love.filesystem.remove(base .. ".txt"))
			assert(love.filesystem.remove(base .. ".png"))
			print("Standard scene snapshot regression passed")
			love.event.quit()
		end
	end)
end

--- @description Creates the map and physics world and imports map fixtures.
--- @return nil
function love.load()
	---@type number
	windowWidth, windowHeight = love.graphics.getDimensions()

	love.physics.setMeter(32)

	---@type table
	map = sti("DEMOS/Standard/as_snow/as_snow.lua", { "box2d" })

	---@type love.World
	world = love.physics.newWorld(0, 0)

	map:box2d_init(world)
	LWorld:InitFromPhysics(world)

	testBody4:Remove()
	if verifySnapshot then
		translation.x, translation.y, translation.z = 180, 210, 1
		testBody:Remove()
		love.mousepressed(0, 0, 1)
	end
	if verifyShadow or verifyStain or verifyLines or verifyWallLines then
		local light = Light:new(LWorld, 300)
		light:SetColor(203, 178, 151, 255)
		if verifyShadow then
			require("PenumbraRegression").run(LWorld, light)
			translation.x, translation.y, translation.z = 259.4365, 1157.86405, 1
		elseif verifyStain then
			require("PenumbraRegression").checkStain(LWorld, light)
			translation.x, translation.y, translation.z = 476.3674, 1101.48365, 1
		elseif verifyLines then
			require("PenumbraRegression").checkLines(LWorld, light)
			translation.x, translation.y, translation.z = 833.36115, 1042.5998, 1.45
		else
			require("PenumbraRegression").checkWallLines(LWorld, light)
			translation.x, translation.y, translation.z = 641.5133, 1335.01265, 1
		end
	end
end

--- @description Updates camera input, map animation, light position, and the world.
--- @param dt number Elapsed frame time in seconds.
--- @return nil
function love.update(dt)
	if verifyShadow or verifyStain or verifyLines or verifyWallLines then return end
	if love.keyboard.isDown("w") then
		translation.y = translation.y - 500 * love.timer.getDelta()
	elseif love.keyboard.isDown("s") then
		translation.y = translation.y + 500 * love.timer.getDelta()
	end

	if love.keyboard.isDown("a") then
		translation.x = translation.x - 500 * love.timer.getDelta()
	elseif love.keyboard.isDown("d") then
		translation.x = translation.x + 500 * love.timer.getDelta()
	end

	local tx, ty = testBody:GetPosition()

	--testBody:SetPosition(tx + 20 * love.timer.getDelta(), ty)

	map:update(dt)

	L:SetPosition(translation.x + love.mouse.getX() / translation.z, translation.y + love.mouse.getY() / translation.z)
	LWorld:SetPosition(translation.x, translation.y, translation.z)

	LWorld:Update()
	if verifySnapshot and not verifyStarted then
		verifyStarted = true
		love.keypressed("f9")
	end
end

--- @description Adjusts the demo zoom from mouse-wheel input.
--- @param id number Wheel x delta in this legacy callback signature.
--- @param direction number Wheel y delta in this legacy callback signature.
--- @return nil
function love.wheelmoved(id, direction)
	if id == 0 then
		translation.z = translation.z - direction / 20
	end
end

love.graphics.maxFramerate = 100

--- @description Draws the map, sample textures, and lit scene.
--- @return nil
function love.draw()
	love.graphics.setColor(255, 255, 255, 255)

	map:draw(-translation.x, -translation.y, translation.z, translation.z)

	love.graphics.translate(-translation.x * translation.z, -translation.y * translation.z)
	love.graphics.scale(translation.z, translation.z)

	local x, y = nm:GetPosition()

	love.graphics.draw(nm.Img, x, y)

	local x, y = hm:GetPosition()

	love.graphics.draw(hm.Img, x, y)

	love.graphics.origin()
	LWorld:Draw()
	if verifyShadow or verifyStain or verifyLines or verifyWallLines then
		--- @description Saves the verified wall-and-crate scene and exits.
		--- @param image love.ImageData Captured window pixels.
		--- @return nil
		love.graphics.captureScreenshot(function(image)
			local filename = verifyShadow and "standard-shadow-verify.png" or
				(verifyStain and "standard-stain-verify.png" or
				(verifyLines and "standard-line-verify.png" or "standard-wall-line-verify.png"))
			assert(love.filesystem.write(filename, image:encode("png")))
			print("Saved shadow regression screenshot to " ..
				love.filesystem.getSaveDirectory() .. "/" .. filename)
			love.event.quit()
		end)
		return
	end
	if snapshotRequested then
		saveSceneSnapshot()
	end
	if not snapshotRequested and snapshotMessage and love.timer.getTime() < snapshotMessageUntil then
		love.graphics.setColor(0, 0, 0, 0.8)
		love.graphics.rectangle("fill", 0, 0, 760, 24)
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.print(snapshotMessage, 6, 4)
	end
	capture.draw()
end

--- @description Requests a scene snapshot or forwards shared screenshot controls.
--- @param key string Pressed key name.
--- @return nil
function love.keypressed(key)
	if key == "f9" then
		if not snapshotRequested then snapshotRequested = true end
	else
		capture.keypressed(key)
	end
end

--- @description Adds a random light on left click or removes a sample body otherwise.
--- @param x number Mouse x-coordinate.
--- @param y number Mouse y-coordinate.
--- @param b integer Mouse button.
--- @return nil
function love.mousepressed(x, y, b)
	if b == 1 then
		L = Light:new(LWorld, 300)
		L:SetColor(math.random(0, 255), math.random(0, 255), math.random(0, 255), 255)
	else
		testBody:Remove()
	end
end
