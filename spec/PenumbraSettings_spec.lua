--- Tests public penumbra settings, invalidation, and hard-shadow buffer cleanup.
---@diagnostic disable: undefined-global
package.path = "src/?.lua;src/?/init.lua;" .. package.path

describe("Light penumbra settings",
    --- @description Defines isolated setting tests without a graphics runtime.
    --- @return nil
    function()
        local previousShadows, previousLight, Light

        before_each(
            --- @description Loads the light class without initializing GPU shaders.
            --- @return nil
            function()
                previousShadows = package.loaded["shadows"]
                previousLight = package.loaded["shadows.Light"]
                package.loaded["shadows"] = {}
                package.loaded["shadows.Light"] = nil
                Light = require("shadows.Light")
            end)

        after_each(
            --- @description Restores package entries used by the setting tests.
            --- @return nil
            function()
                package.loaded["shadows"] = previousShadows
                package.loaded["shadows.Light"] = previousLight
            end)

        --- @description Creates a light instance without registration or canvas allocation.
        --- @return Light light Unregistered light for setting tests.
        local function newLight()
            return setmetatable({}, Light)
        end

        it("invalidates once for initial settings and leaves unchanged settings cached",
            --- @description Verifies the default effective source radius and stable cache.
            --- @return nil
            function()
                local light = newLight()
                light:UpdatePenumbraSettings()
                assert.equals(10, light.PreviousSizeRadius)
                assert.is_true(light.Changed)
                light.Changed = nil
                light:UpdatePenumbraSettings()
                assert.is_nil(light.Changed)
            end)

        it("invalidates when blur is toggled directly",
            --- @description Verifies the existing public Blur field updates cached rendering.
            --- @return nil
            function()
                local light = newLight()
                light:UpdatePenumbraSettings()
                light.Changed = nil
                light.Blur = false
                light:UpdatePenumbraSettings()
                assert.is_true(light.Changed)
                assert.is_false(light.PreviousBlur)
            end)

        it("invalidates when the source radius changes directly",
            --- @description Verifies direct SizeRadius changes regenerate the penumbra.
            --- @return nil
            function()
                local light = newLight()
                light:UpdatePenumbraSettings()
                light.Changed = nil
                light.SizeRadius = 24
                light:UpdatePenumbraSettings()
                assert.is_true(light.Changed)
                assert.equals(24, light.PreviousSizeRadius)
            end)

        it("rejects negative, infinite, nonnumeric, and NaN source radii",
            --- @description Verifies invalid source radii raise an explicit error.
            --- @return nil
            function()
                for _, radius in ipairs({ -1, math.huge, "wide", 0 / 0 }) do
                    local light = newLight()
                    light.SizeRadius = radius
                    assert.has_error(
                        --- @description Attempts to validate an invalid radius.
                        --- @return nil
                        function() light:UpdatePenumbraSettings() end,
                        "SizeRadius must be a finite nonnegative number")
                end
            end)

        it("discards filtering buffers for a zero source radius or disabled blur",
            --- @description Verifies both hard-shadow controls skip GPU buffer generation.
            --- @return nil
            function()
                local light = newLight()
                light.Penumbra = {}
                light.SizeRadius = 0
                light:GeneratePenumbra()
                assert.is_nil(light.Penumbra)
                light.Penumbra = {}
                light.SizeRadius = 10
                light.Blur = false
                light:GeneratePenumbra()
                assert.is_nil(light.Penumbra)
            end)

        it("discards filtering buffers when the light canvases are destroyed",
            --- @description Verifies invisible local lights release all cached filtering state.
            --- @return nil
            function()
                local light = newLight()
                light.Canvas, light.ShadowCanvas, light.ShadowRenderCanvas, light.Penumbra = {}, {}, {}, {}
                light:DestroyCanvas()
                assert.is_nil(light.Canvas)
                assert.is_nil(light.ShadowCanvas)
                assert.is_nil(light.ShadowRenderCanvas)
                assert.is_nil(light.Penumbra)
            end)
    end)
