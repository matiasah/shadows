--- Provides DPI-scale lookup for canvases and the active LÖVE display.
--- @class shadows.DPI
local DPI = {}

--- @description Returns a canvas-specific DPI scale, falling back to the display scale.
--- @param canvas love.Canvas? Canvas to inspect; defaults to the active display when absent or unsupported.
--- @return number scale DPI scale factor.
function DPI.getCanvasScale(canvas)
    if canvas and type(canvas.getDPIScale) == "function" then
        return canvas:getDPIScale()
    end

    return love.graphics.getDPIScale()
end

return DPI
