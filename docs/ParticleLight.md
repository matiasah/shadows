# ParticleLight

`ParticleLight` uses a real LÖVE `ParticleSystem` as animated illumination instead
of a radial light texture. Particle colors and alpha accumulate additively, tint
the scene, and are masked by the library's existing hard or soft shadows.

```lua
local ParticleLight = require("shadows.ParticleLight")

-- Use a soft white glow image, not a fully opaque square.
local particles = love.graphics.newParticleSystem(glowImage, 256)
particles:setParticleLifetime(0.5, 1.5)
particles:setEmissionRate(60)
particles:setDirection(-math.pi / 2)
particles:setSpread(0.6)
particles:setSpeed(20, 60)
particles:setSizes(2, 0)
particles:setColors(1, 0.5, 0.1, 0.8, 1, 0.1, 0, 0)

local light = ParticleLight:new(world, 180, particles)
light:SetPosition(400, 300, 2)

function love.update(dt)
    world:Update(dt) -- Advances the emitter and recomposes its illumination.
end
```

## API

| Method | Description |
|---|---|
| `ParticleLight:new(world, radius, particles)` | Registers a local light with a finite positive radius and a LÖVE particle system. All three arguments are required. |
| `light:SetParticleSystem(particles)` | Replaces the emitter; returns the light. Does not rebuild shadows. |
| `light:GetParticleSystem()` | Returns the emitter for configuration or manual emission. |

Position, rotation, radius, tint/opacity (`SetColor`), `Blur`, `SizeRadius`,
transform parenting, and removal follow [Light](Light.md). Particle rendering
replaces radial falloff and custom images; `Arc` and `SetImage` do not control
its appearance. Configure particle texture, sizes, colors, and emission instead.

## Coordinates and simulation

- Configure the emitter around local `(0, 0)`. `SetPosition` places the light in
  the world and `SetAngle` rotates the whole effect, including particle motion.
  Do not set particle positions to world coordinates.
- Radius determines the `2 * radius` square canvas and shadow influence. Keep
  particle positions plus their visible texture extent within that radius;
  pixels beyond the canvas are clipped, not automatically resized.
- `world:Update(dt)` advances the attached emitter exactly once, including while
  offscreen. Pass finite nonnegative seconds. Do not separately update the same
  emitter or share it between automatically updated lights.
- To own simulation yourself, update the emitter externally and call
  `world:Update()` without `dt`. Calling with `0` refreshes without aging particles.
  Use the same convention consistently for all particle lights in that world.
- `stop`, `pause`, `start`, `reset`, and `emit` remain native particle-system
  operations. The next world update refreshes their visible output.

## Shadow model and cost

Shadows project from the **single light/emitter position and height**, not from
each individual particle. This is an animated light mask, not a collection of
independently shadow-casting lights. Use separate lights for separate origins.
Particle animation redraws illumination and the world canvas each update but
reuses shadow geometry, shadow pixels, and penumbra distance fields when the
scene and light position are unchanged. Standard light canvas costs still apply.

Run the [ParticleLights demo](../DEMOS/ParticleLights/main.lua):

```powershell
love . ParticleLights
love . ParticleLights --capture --verify
```

It includes fire, water spray, and sparks with nearby circle and polygon
casters. Press `Space` to pause, `B` to toggle soft shadows, `F12` to capture,
and `Escape` to exit. Capture uses a fixed warm-up duration at canvas DPI scale 2;
particle randomness is native to LÖVE. `--verify` checks animated illumination
from all three emitters and unchanged shadow pixels. The water light uses
tapered droplets with soft halos, velocity-aligned rotation, and gravity-driven
arcs. Verification measures blue illumination above the emitter during ascent
and below it during descent; this is a particle spray, not a fluid simulation.
