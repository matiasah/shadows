---@module Runs native Busted specs after LOVE initializes its graphics runtime.

---@description Discovers the selected specs and propagates Busted failures to the process exit status.
---@param args string[] Spec paths or Busted options supplied to LOVE; defaults to spec when empty.
---@return nil
function love.load(args)
    love.filesystem.setRequirePath("src/?.lua;src/?/init.lua;" .. love.filesystem.getRequirePath())
    package.path = "src/?.lua;src/?/init.lua;" .. package.path
    arg = { [0] = "busted" }
    for _, argument in ipairs(args) do
        arg[#arg + 1] = argument
    end
    if #arg == 0 then
        arg[1] = "spec"
    end

    ---@description Invokes Busted without its standalone interpreter bootstrap.
    ---@return nil
    local function runTests()
        require("busted.runner")({ standalone = false })
    end

    local ok, message = pcall(runTests)
    if not ok then
        io.stderr:write("Busted failed: " .. (message and tostring(message) or "see the Busted report above") .. "\n")
        love.event.quit(1)
        return
    end
    love.event.quit(0)
end
