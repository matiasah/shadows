# Contact-hardening penumbras

Soft shadows retain a sharp edge where they meet the casting shape and become
progressively softer farther from it. This replaces the old radial blur, which
based softness on distance from the light and could darken uniformly lit areas
because its Gaussian weights were not normalized.

## Settings and API

Both [Light and Star](Light.md) expose the same settings:

| Field | Default | Behavior |
|---|---|---|
| `Blur` | `true` | Enables contact-hardening filtering. Set `false` for the original hard shadow mask. |
| `SizeRadius` | `10` | Effective source radius in world units. Must be finite and nonnegative; `0` also disables filtering. |

Changing these fields directly refreshes cached rendering on the next world
update. Star filtering accounts for camera translation and zoom. Canvas DPI
changes sampling resolution, not softness in logical units.

```lua
local light = Light:new(world, 400)
light:SetPosition(100, 200, 1.2)
light.SizeRadius = 18

-- Hard-shadow comparison, without replacing the light.
light.Blur = false
world:Update()
```

## Rendering

The renderer retains the existing projected shadow geometry and height layers.
It renders an additional caster silhouette mask, then uses jump flooding to
build a nearest-occluder field. For each pixel the filter follows the field
toward the light and blends the footprints of candidates near that path,
weighted by their distance from it. This reduces abrupt changes when the search
crosses different surfaces. It blends back toward the nearest silhouette when
the candidates lie far from the path. Each candidate footprint grows with its
distance from the pixel relative to its distance from the light:

```text
minimum = min(distance(pixel, edge) * 0.5, 8 world units)
estimatedRadius = max(minimum, SizeRadius * min(distance(pixel, edge) /
                                                max(distance(light, edge), SizeRadius), 4))
filterRadius = estimatedRadius * 0.9
```

The unsmoothed footprint approaches zero at contact, but reaches a minimum
estimated radius of 8 world units away from the caster for any positive
`SizeRadius`, independent of the light's distance. The filter uses 90% of the
estimated radius, slightly tightening the penumbra while retaining its smooth
Gaussian transition. Larger sources and closer lights can add more softness.
Star camera zoom scales this minimum along with the source size.
The ratio is capped at four to bound the source-dependent filtering near the light and at large separations. A normalized
Gaussian filter preserves constant visibility and dark umbra interiors.
The estimated radius is stored in a separate canvas and smoothed over nearby
uncovered pixels before filtering visibility, avoiding sharp bands when
neighboring pixels calculate different footprints. This may slightly soften
the edge immediately outside a caster; the caster itself remains protected.
The smoothing distance is measured in world units and scales with star camera
zoom.
Mipmapped sampling avoids visible sample bands in wide penumbras. Filtering
applies only to shadow visibility, not the light's color or radial falloff.
Occluder silhouettes retain their original unfiltered visibility, including
normal-map shading; partially covered edge pixels blend with the filtered result.
Projected shadow render targets and occluder-mask canvases request 4x MSAA to
antialias diagonal edges, independently of the slightly tighter filter.
Projected shadows are resolved into a separate mipmapped canvas before filtering.

This is a **silhouette-based approximation**, not a physical area-light
simulation. The directional search is limited to 32 distance-field steps and
falls back to the nearest silhouette when it finds no candidate between the
pixel and light, or when the light center lies inside a silhouette. The selected shape can differ from the actual blocker in
overlapping or multi-height scenes; the filter does not reconstruct per-pixel
blocker heights or trace visibility to points on an extended light source.
The search gradually reduces the contribution of candidates very close to the
pixel, and stops on actual silhouette coverage rather than proximity alone.
This reduces bright streaks beside walls that run along the search path while
retaining the nearest-silhouette fallback.

Polygon and circle bodies supply their geometry. Textured shapes and the
world's `DrawSprites` callback supply silhouettes using `ShapeShader`'s existing
nontransparent, nonblack-pixel rule. `DrawSprites` is called an additional time
for the mask and must not have simulation side effects. Custom `DrawShadows`
geometry without a corresponding silhouette remains unfiltered when no
occluders are available.
Casters wholly outside the filtering canvas cannot contribute silhouette seeds;
shadows entering from such casters may remain hard.

## Graphics requirements and caching

The filter requires GLSL 3 support, `rgba16f` renderable canvases, and manual
canvas mipmaps, as provided by compatible LÖVE 11 graphics backends. Unsupported
shader or canvas creation fails explicitly; there is no silent fallback.

Each light uses an additional shadow render target, and that target and the
silhouette mask request 4x multisampling, increasing graphics memory use; the
actual sample count depends on backend support.
Each soft light allocates a silhouette mask and three floating-point buffers
matching its shadow canvas dimensions and DPI. The distance field, radius field,
and mipmaps are rebuilt only when the light or scene changes. Disabling filtering discards
the extra buffers. Invisible local lights discard them with their other
canvases; resizing a star recreates them on its next update.
The directional search adds up to 32 distance-field lookups per pixel when
rebuilding the radius field. Compositing additionally samples up to 25 nearby
radius values per filtered pixel.

## Comparison and regressions

```powershell
love . Penumbra
love . Penumbra --capture --verify
love . Standard --shadow-verify
love . Standard --shadow-verify --capture
love . Standard --stain-verify
love . Standard --stain-verify --capture
love . Standard --line-verify
love . Standard --line-verify --capture
love . Standard --wall-line-verify
love . Standard --wall-line-verify --capture
love . HighDPI --capture
busted spec/DPI_spec.lua spec/PenumbraSettings_spec.lua
```

The comparison demo shows matching polygon and circle casters with hard shadows
on the left and penumbras on the right. `+` and `-` adjust source size, the
left/right arrow keys move the light, `F12` captures a screenshot, and `Escape` exits.

`--verify` renders controlled masks at DPI scales 1 and 2 and checks that the
contact transition is at most 3 logical pixels wide, the distant transition is
at least 8 pixels and three times wider, and distant widths agree within one
logical pixel across DPI scales. It also checks occluder protection, full-light
and umbra preservation, zero-radius hard shadows, and missing occluders.
Positive radii as small as 0.001 are checked at near and far light positions
for a transition of at least 4 logical pixels, and the minimum is checked at
different camera zooms. Real local-light and star composites are also checked
with different light radii and positions.
It checks constant black, gray, and white visibility, plus star cache reuse,
camera-center scaling, setting toggles, and buffer recreation after resizing.
It also checks partially covered diagonal shadow and mask pixels for local
lights and stars at both DPI scales, including after a star resize.
Partial mask coverage is checked against the expected blend of filtered and
unfiltered visibility.
The Standard shadow regression also checks continuity across a captured
wall/crate nearest-occluder boundary at DPI scales 1 and 2. A synthetic
regression checks the fallback for a light inside an occluder.
The corner regression checks the wall and floor edges of a captured crate
penumbra for bright discontinuities at both DPI scales.
The line regression measures a zoomed crate's visible penumbra, and the
synthetic strip checks both shadow edges for bright seams.
The wall-line regression checks a captured vertical wall penumbra for an
internal brightness spike at both DPI scales.
