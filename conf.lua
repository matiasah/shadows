--- Configures the LÖVE demo launcher window.
--- @description Sets the demo title, default dimensions, high-DPI mode, and window options.
--- @param t table LÖVE configuration table.
--- @return nil
function love.conf(t)
    t.window.title = "Shadows Demos"
    t.window.width = 1024
    t.window.height = 768
    t.window.resizable = true
    t.window.highdpi = true
    t.window.vsync = 1
end
