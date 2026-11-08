--- Provides screenshot capture controls shared by the LÖVE demos.
--- @class Capture
--- @field auto boolean Whether capture mode is enabled from startup.
--- @field draw fun() Starts automatic capture after the first drawn frame.
--- @field keypressed fun(key: string) Handles screenshot and exit keys.
local Capture = {}

--- @description Creates an object that saves a screenshot on request or at startup.
--- @param filename string PNG filename written to the LÖVE save directory.
--- @return Capture capture Screenshot controls.
function Capture.new(filename)
    local captureOnStart = false
    for _, argument in ipairs(arg or {}) do
        if argument == "--capture" then
            captureOnStart = true
        end
    end

    if captureOnStart then
        --- @description Reports capture failures to the console instead of opening an interactive error screen.
        --- @param message string Runtime error message.
        --- @return function quit Function returning the failing process exit code.
        love.errorhandler = function(message)
            print(debug.traceback(message, 2))
            --- @description Exits the automated capture with a failure status.
            --- @return integer status Failure exit code.
            return function() return 1 end
        end
        local newCanvas = love.graphics.newCanvas
        ---@diagnostic disable-next-line: duplicate-set-field
        --- @description Defaults capture canvases to DPI scale 2 while preserving explicit scale settings.
        --- @param width number Canvas width.
        --- @param height number Canvas height.
        --- @param settings table? Canvas settings; defaults to an empty table.
        --- @return love.Canvas canvas New high-DPI canvas.
        love.graphics.newCanvas = function(width, height, settings)
            settings = settings or {}
            settings.dpiscale = settings.dpiscale or 2
            return newCanvas(width, height, settings)
        end
    end

    local captureRequested = false
    --- @description Queues one screenshot save and exits after it is written.
    --- @return nil
    local function saveScreenshot()
        if captureRequested then
            return
        end

        captureRequested = true
        --- @description Writes the captured image as a PNG and exits the demo.
        --- @param imageData love.ImageData Captured screenshot data.
        --- @return nil
        love.graphics.captureScreenshot(function(imageData)
            assert(love.filesystem.write(filename, imageData:encode("png")))
            print("Saved screenshot to " .. love.filesystem.getSaveDirectory() .. "/" .. filename)
            love.event.quit()
        end)
    end

    return {
        auto = captureOnStart,
        --- @description Starts the automatic screenshot after a rendered frame.
        --- @return nil
        draw = function()
            if captureOnStart and not captureRequested then
                saveScreenshot()
            end
        end,
        --- @description Captures a screenshot on F12 or exits on Escape.
        --- @param key string Pressed key name.
        --- @return nil
        keypressed = function(key)
            if key == "f12" then
                saveScreenshot()
            elseif key == "escape" then
                love.event.quit()
            end
        end,
    }
end

return Capture
