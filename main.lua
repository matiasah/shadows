--- Selects and launches one repository demo with its required module paths and window size.
local demos = {
    HighDPI = "DEMOS/HighDPI/main.lua",
    Standard = "DEMOS/Standard/main.lua",
    HeightMap = "DEMOS/HeightMap/main.lua",
    NormalMap = "DEMOS/NormalMap/main.lua",
    Penumbra = "DEMOS/Penumbra/main.lua",
}

local demoName = "HighDPI"
for _, argument in ipairs(arg) do
    if demos[argument] then
        demoName = argument
        break
    end
end

local demoMain = assert(demos[demoName], "Unknown demo: " .. tostring(demoName))

local windowSizes = {
    HighDPI = { 800, 600 },
    Standard = { 1000, 600 },
    HeightMap = { 1024, 1024 },
    NormalMap = { 1024, 720 },
    Penumbra = { 1000, 480 },
}

local requirePath = love.filesystem.getRequirePath()
love.filesystem.setRequirePath("src/?.lua;src/?/init.lua;DEMOS/?.lua;DEMOS/?/init.lua;DEMOS/" ..
demoName .. "/?.lua;DEMOS/" .. demoName .. "/?/init.lua;" .. requirePath)

local size = windowSizes[demoName]
love.window.setMode(size[1], size[2], { highdpi = true, resizable = true })

assert(love.filesystem.load(demoMain))()
