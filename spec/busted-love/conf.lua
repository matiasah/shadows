---@module Configures the separate LOVE test application.

---@description Creates a deterministic-size graphics window and isolates test screenshots from demos.
---@param t love.Conf LOVE configuration table.
---@return nil
function love.conf(t)
    t.identity = "shadows-tests"
    t.window.title = "Shadows Busted tests"
    t.window.width = 256
    t.window.height = 192
    t.window.highdpi = false
    t.window.vsync = 0
    t.modules.audio = false
end
