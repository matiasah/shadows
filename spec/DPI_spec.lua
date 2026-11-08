--- Tests DPI scale lookup for canvases and the active LÖVE display.
---@diagnostic disable: undefined-global, undefined-field
package.path = "src/?.lua;" .. package.path

local DPI = require("shadows.DPI")

describe("DPI.getCanvasScale",
    --- @description Defines test cases with an isolated fake LÖVE graphics API.
    --- @return nil
    function()
        local previousLove

        before_each(
        --- @description Saves and replaces the global LÖVE API for this test.
        --- @return nil
            function()
                previousLove = _G.love
                _G.love = {
                    graphics = {
                        --- @description Returns the stubbed display DPI scale.
                        --- @return number scale Display scale factor.
                        getDPIScale = function()
                            return 1.5
                        end,
                    },
                }
            end)

        after_each(
        --- @description Restores the original global LÖVE API.
        --- @return nil
            function()
                _G.love = previousLove
            end)

        it("uses the active Canvas scale",
            --- @description Verifies the canvas-specific scale takes precedence.
            --- @return nil
            function()
                local canvas = {
                    --- @description Returns the stubbed canvas DPI scale.
                    --- @return number scale Canvas scale factor.
                    getDPIScale = function()
                        return 2
                    end,
                }

                assert.equals(2, DPI.getCanvasScale(canvas))
            end)

        it("falls back to the screen scale when the Canvas has no scale method",
            --- @description Verifies display DPI is used for canvases without a scale method.
            --- @return nil
            function()
                assert.equals(1.5, DPI.getCanvasScale({}))
            end)
    end)
