--- Compiles and registers the shaders used by Shädows rendering.
module("shadows.Shaders", package.seeall)

---@type Shadows
Shadows = require("shadows")

Shadows.BlurShader = love.graphics.newShader [[
	// Size of the canvas on which the effect is applied
	extern vec2 Size;
	
	// Multiplier to the size factor (how far is the effect applied? 100% by default)
	const float Quality = 1.0;
	
	// The radius of the pixels that are analized
	const float Radius = 2.0;
	
	vec4 effect(vec4 color, Image tex, vec2 tc, vec2 pc) {
		
		vec4 Sum = vec4(0);
		vec2 SizeFactor = vec2(Quality / Size);
		
		for (float x = -Radius; x <= Radius; x++) {
			
			for (float y = -Radius; y <= Radius; y++) {
				
				Sum += Texel(tex, tc + vec2(x, y) * SizeFactor);
				
			}
		
		}
		
		float Delta = 2.0 * Radius + 1.0;
		
		return Sum / vec4( Delta * Delta );
		
	}
	
]]

Shadows.BloomShader = love.graphics.newShader [[
	// Size of the canvas
	extern vec2 Size;
	
	// Radius of the pixel
	const float Radius = 1.0;		// pixels per axis; higher = bigger glow, worse performance
	const float Quality = 5.0;			// lower = smaller glow, better quality

	vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
		
		// Summatory of the colors
		vec4 Sum = vec4(0);
		
		// Size multiplier (for Texel)
		vec2 SizeFactor = vec2(Quality / Size);
		
		// Number of samples used
		float Samples = 0.0;
		
		for (float x = -Radius; x <= Radius; x++){
		
			for (float y = -Radius; y <= Radius; y++) {
			
				// Add every pixel around to the summatory
				Sum += Texel(tex, tc + vec2(x, y) * SizeFactor);
				Samples++;
				
			}
			
		}
		
		// Return the sum divided by the number of samples and add the color of the pixel at the given point
		return (Sum / Samples + Texel(tex, tc) ) * color;
	}
	
]]

Shadows.DarkenShader = love.graphics.newShader [[
	
	vec4 effect(vec4 src, Image tex, vec2 tc, vec2 sc) {
		// Minimum between the color and the texture color
		return min(src, Texel(tex, tc) );
		
	}
	
]]

-- https://love2d.org/forums/viewtopic.php?t=81014#p189754
Shadows.AberrationShader = love.graphics.newShader [[
	
	// Size of the canvas
	extern vec2 Size;
	
	// Offset used for the effect
	extern float Aberration = 2.0;

	vec4 effect(vec4 col, Image texture, vec2 texturePos, vec2 screenPos){
		
		// Divide the offset by the size of the canvas
		vec2 offset = vec2(Aberration, 0) / Size;
		
		// Get the textures
		vec4 red = texture2D(texture, texturePos - offset);
		vec4 green = texture2D(texture, texturePos);
		vec4 blue = texture2D(texture, texturePos + offset);
		
		return vec4(red.r, green.g, blue.b, 1E0); //final color with alpha of 1
	}
	
]]

Shadows.LightShader = love.graphics.newShader [[
	
	extern float DpiScale;
	
	// Radius of the light effect
	extern float Radius;
	
	// Center of the light
	extern vec3 Center;

	vec4 effect(vec4 Color, Image Texture, vec2 tc, vec2 pc) {
		
		// Distance between the screen pixel and the center of the light
		vec3	Delta		=	vec3(pc / DpiScale, 0.0) - Center;
		float Distance =	length( Delta );
		
		// If the distance is lower than the radius
		if (Distance <= Radius) {
			
			// Return the 100% of the alpha, minus the distance from the light divided by the radius
			return vec4( vec3(1.0), 1.0 - length( Delta / Radius ) );
			
		}
		
		// Return black
		return vec4(0.0, 0.0, 0.0, 0.0);
	}
	
]]

Shadows.OccluderSeedShader = love.graphics.newShader [[
	vec4 effect(vec4 color, Image texture, vec2 tc, vec2 pc) {
		return Texel(texture, tc).a > 0.0 ? vec4(tc, 1.0, 1.0) : vec4(0.0);
	}
]]

Shadows.OccluderDistanceShader = love.graphics.newShader [[
	extern vec2 PixelSize;
	extern float Step;

	vec4 effect(vec4 color, Image texture, vec2 tc, vec2 pc) {
		vec4 nearest = Texel(texture, tc);
		float best = nearest.b > 0.5 ? length((nearest.xy - tc) * PixelSize) : 1.0e20;
		for (int x = -1; x <= 1; x++) {
			for (int y = -1; y <= 1; y++) {
				vec2 sampleCoord = tc + vec2(x, y) * Step / PixelSize;
				if (sampleCoord.x < 0.0 || sampleCoord.y < 0.0 ||
					sampleCoord.x >= 1.0 || sampleCoord.y >= 1.0) continue;
				vec4 candidate = Texel(texture, sampleCoord);
				float distance = length((candidate.xy - tc) * PixelSize);
				if (candidate.b > 0.5 && distance < best) {
					nearest = candidate;
					best = distance;
				}
			}
		}
		return nearest;
	}
]]

Shadows.PenumbraRadiusShader = love.graphics.newShader [[
	#pragma language glsl3
	extern float DpiScale;
	extern vec2 Position;
	extern vec2 Size;
	extern float SourceRadius;
	extern float MinimumRadius;
	extern Image Occluders;
	extern Image NearestOccluder;

	vec4 effect(vec4 color, Image Texture, vec2 tc, vec2 pc) {
		vec4 blocker = Texel(NearestOccluder, tc);
		float occluderCoverage = Texel(Occluders, tc).a;
		if (SourceRadius <= 0.0 || blocker.b < 0.5 || occluderCoverage >= 1.0)
			return vec4(0.0);

		vec2 pixel = tc * Size;
		vec2 nearestEdge = blocker.xy * Size;
		vec2 toLight = Position - pixel;
		float lightRange = length(toLight);
		float weightedRadius = 0.0;
		float weightedOffset = 0.0;
		float totalWeight = 0.0;
		vec2 lightCoord = Position / Size;
		bool lightInside = lightCoord.x >= 0.0 && lightCoord.y >= 0.0 &&
			lightCoord.x < 1.0 && lightCoord.y < 1.0 &&
			Texel(Occluders, lightCoord).a > 0.0;
		if (lightRange > 0.0 && !lightInside) {
			// Blend candidate footprints along the ray to avoid seams when the
			// closest candidate changes between surfaces.
			vec2 direction = toLight / lightRange;
			float travel = 0.0;
			for (int i = 0; i < 32; i++) {
				vec2 probe = pixel + direction * travel;
				vec2 probeCoord = probe / Size;
				if (travel > lightRange || probeCoord.x < 0.0 || probeCoord.y < 0.0 ||
					probeCoord.x >= 1.0 || probeCoord.y >= 1.0) break;
				vec4 candidate = Texel(NearestOccluder, probeCoord);
				if (candidate.b < 0.5) break;
				vec2 candidateEdge = candidate.xy * Size;
				vec2 delta = candidateEdge - pixel;
				float along = dot(delta, direction);
				float offset = length(delta - direction * along);
				float distance = length(candidateEdge - probe);
				float advance = max(distance - 2.0 / DpiScale, 1.0 / DpiScale);
				// Fade out candidates close to the pixel, such as adjacent walls.
				if (along >= 0.0 && along <= lightRange) {
					float candidateSeparation = length(delta);
					float candidateLightDistance = max(length(Position - candidateEdge), SourceRadius);
					float candidateRadius = max(min(candidateSeparation * 0.5, MinimumRadius),
						SourceRadius * min(candidateSeparation / candidateLightDistance, 4.0));
					float proximity = smoothstep(0.0, min(2.0 * MinimumRadius, lightRange * 0.5), along);
					float weight = proximity * exp(-offset / max(MinimumRadius, 0.001));
					weightedRadius += candidateRadius * weight;
					weightedOffset += offset * weight;
					totalWeight += weight;
				}
				if (Texel(Occluders, probeCoord).a > 0.5) break;
				travel += advance;
			}
		}
		float nearestSeparation = length(pixel - nearestEdge);
		float nearestLightDistance = max(length(Position - nearestEdge), SourceRadius);
		float nearestRadius = max(min(nearestSeparation * 0.5, MinimumRadius),
			SourceRadius * min(nearestSeparation / nearestLightDistance, 4.0));
		float radius = nearestRadius;
		if (totalWeight > 0.0) {
			float directionalRadius = weightedRadius / totalWeight;
			float offset = weightedOffset / totalWeight;
			float directionalWeight = 1.0 - smoothstep(0.5 / DpiScale,
				max(4.0 / DpiScale, min(directionalRadius, 2.0 * MinimumRadius)), offset);
			radius = mix(nearestRadius, directionalRadius, directionalWeight);
		}
		return vec4(radius, 0.0, 0.0, 1.0);
	}
]]

Shadows.PenumbraShader = love.graphics.newShader [[
	#pragma language glsl3
	extern float DpiScale;
	extern vec2 Size;
	extern float RadiusScale;
	extern Image Occluders;
	extern Image NearestOccluder;
	extern Image FilterRadius;

	vec4 effect(vec4 color, Image Texture, vec2 tc, vec2 pc) {
		vec4 original = Texel(Texture, tc);
		vec4 blocker = Texel(NearestOccluder, tc);
		float occluderCoverage = Texel(Occluders, tc).a;
		if (blocker.b < 0.5 || occluderCoverage >= 1.0)
			return original * color;

		float radiusSum = 0.0;
		float radiusWeights = 0.0;
		for (int x = -2; x <= 2; x++) {
			for (int y = -2; y <= 2; y++) {
				vec2 sampleCoord = tc + vec2(x, y) * (2.0 * RadiusScale) / Size;
				if (sampleCoord.x < 0.0 || sampleCoord.y < 0.0 ||
					sampleCoord.x >= 1.0 || sampleCoord.y >= 1.0) continue;
				float coverage = Texel(Occluders, sampleCoord).a;
				float weight = exp(-0.5 * float(x * x + y * y)) * (1.0 - coverage);
				radiusSum += Texel(FilterRadius, sampleCoord).r * weight;
				radiusWeights += weight;
			}
		}
		float radius = radiusWeights > 0.0 ? radiusSum / radiusWeights : 0.0;
		// Prefilter wide footprints so the fixed sampling grid cannot form bands.
		float lod = max(log2(max(radius * DpiScale / 4.0, 1.0)), 0.0);
		vec4 sum = vec4(0.0);
		float weights = 0.0;
		for (int x = -4; x <= 4; x++) {
			for (int y = -4; y <= 4; y++) {
				vec2 offset = vec2(x, y) / 4.0;
				float weight = exp(-2.0 * dot(offset, offset));
				vec2 sampleCoord = tc + offset * radius / Size;
				vec4 sampleColor = vec4(1.0);
				if (sampleCoord.x >= 0.0 && sampleCoord.y >= 0.0 &&
					sampleCoord.x < 1.0 && sampleCoord.y < 1.0)
					sampleColor = textureLod(Texture, sampleCoord, lod);
				sum += sampleColor * weight;
				weights += weight;
			}
		}
		return mix(sum / weights, original, occluderCoverage) * color;
	}
]]

Shadows.ShapeShader = love.graphics.newShader [[
	
	// Effect that renders the shape of a image
	vec4 effect(vec4 Color, Image Texture, vec2 textureCoord, vec2 pixelCoord) {
		
		// Get the pixel color at the given texture
		vec4 pixel = Texel(Texture, textureCoord);
		
		// If it's alpha is higher than zero
		if ( pixel.a > 0.0 ) {
			
			// If it's not black
			if ( pixel.r > 0.0 || pixel.g > 0.0 || pixel.b > 0.0 ) {
				
				// Return the setColor value
				return Color;
				
			}
			
		}
		
		// Return invisible color
		return vec4(0.0, 0.0, 0.0, 0.0);
		
	}
	
]]

-- Normal Map shader
Shadows.NormalShader = love.graphics.newShader [[
	
	extern float DpiScale;
	
	// Position of the light
	extern vec3 LightPos;
	
	vec4 effect(vec4 Color, Image Texture, vec2 textureCoord, vec2 pixelCoord) {
		
		// Color of the pixel (the normal)
		vec4 NormalMap = Texel(Texture, textureCoord);
		
		// Direction of the light
		// I don't know why but the formula for the 'y' coordinate seems to solve a issue here
		vec2 logicalPixelCoord = pixelCoord / DpiScale;
		vec3 LightDir = vec3( LightPos.x - logicalPixelCoord.x, -abs(LightPos.y - logicalPixelCoord.y), LightPos.z);
		
		// Normalize the normal map
		vec3 N = normalize(NormalMap.rgb * 2.0 - 1.0);
		
		// Normalize the light direction
		vec3 L = normalize(LightDir);
		
		// Get the dot product between the both and return the output color
		return Color * ( 1.0 - dot(N, L) );
		
	}
	
]]

Shadows.HeightShader = love.graphics.newShader [[
	
	extern float DpiScale;
	
	// Position of the light
	extern vec3 LightPos;
	
	// Supposed center of the canvas
	extern vec3 LightCenter;
	
	// Texture position in map
	extern vec3 MapPos;
	
	// Size of the canvas
	extern vec2 Size;
	
	// Height map texture
	extern Image Texture;
	
	vec4 effect(vec4 Color, Image tex, vec2 tc, vec2 pixelCoord) {
		
		vec2 logicalPixelCoord = pixelCoord / DpiScale;
		
		// Size factor
		vec2 inverseSize = 1.0 / Size;
		
		// Calculating moved 'tc'
		vec2 textureCoord = ( LightPos.xy - LightCenter.xy + logicalPixelCoord - MapPos.xy ) / Size;
		
		// Height on the height map at this point
		float pointHeight = Texel(Texture, textureCoord).r;
		
		// Light direction
		vec3 LightDir = vec3( LightCenter.xy - logicalPixelCoord.xy, LightPos.z );
		
		// Normalized light direction
		vec3 L = normalize(LightDir);
		
		// Distance from the light
		float Distance = length(LightDir);
		
		// From the source position to the given point
		for (float i = 0.0; i < Distance; i++) {
			
			// Calculate every point within
			vec2 position = textureCoord + L.xy * i / Size;
			
			// If it's within the canvas
			if ( position.x > 0.0 && position.y > 0.0 && position.x < 1.0 && position.y < 1.0 ) {
			
				// Get the pixel height at the given position
				float pixelHeight = Texel(Texture, position).r;
				
				// If it's lower thatn the height at some point
				if (pixelHeight > pointHeight) {
				
					// Check if it's covered by it
					if ( LightPos.z / Distance <= pixelHeight * MapPos.z / i ) {
					
						// Return white (this point will be darken)
						return vec4(1.0, 1.0, 1.0, 1.0);
						
					}
					
				}
				
			}
			
		}
		
		// Return invisible color (alpha zero)
		return vec4(0.0, 0.0, 0.0, 0.0);
		
	}
	
]]

Shadows.DropShadows = love.graphics.newShader [[
	extern float DpiScale;

	extern vec3	lightPosition;
	extern number	lightRadius;
	extern number	lightRadiusMult;

	extern Image	texure;
	extern vec2	textureSize;
	extern number	textureZ;

	vec4 effect(vec4 color, Image _t, vec2 texture_coords, vec2 screen_coords) {
		// Calculate offset on canvas
		number	scale		= lightPosition.z / ( lightPosition.z - textureZ );
		number	textureOffset	= ( scale - 1.0 ) * 0.5;
		
		// Inverse of the texture size
		vec2	iTextureSize	= 1.0 / textureSize;
		
		// Position of the pixel
		vec3	textureCoord3	= vec3((screen_coords / DpiScale) * iTextureSize, 0.0);
		
		// Alpha of the shadow
		number	pointDarken	= 0.0;
		number	pointCount	= 0.0;
		
		// Inverse of the light radius
		number	iLightRadius	= 1.0 / lightRadius;
		
		// For each pixel offset on the light's position
		for (number x = -lightRadius; x < lightRadius; x++) {
			for (number y = -lightRadius; y < lightRadius; y++) {
				
				vec2	vec		= vec2(x, y);
				number	vecLength	= length(vec);
				
				if ( vecLength <= lightRadius ) {
					
					// Which position on the light source
					vec3 position		= lightPosition + textureOffset + vec3(vec * lightRadiusMult * iTextureSize, 0.0);
					
					// Direction from the pixel position, to the light position
					vec3 direction		= normalize(position - textureCoord3);
					
					// Position on the texture's layer
					vec3 point		= textureCoord3 + ( direction / direction.z ) * textureZ;
					
					// Color on the texture
					vec4 pixelColor		= Texel(texure, point.xy - textureOffset);
					
					// Is it not a color?
					if (pixelColor.r > 0.0 || pixelColor.g > 0.0 || pixelColor.b > 0.0 || pixelColor.a > 0.0) {
						// Make the pixel darker
						pointDarken += vecLength * iLightRadius;
					}
					
					// Increment the number of pixels used
					pointCount++;
				}
			}
		}
		
		return vec4(0.0, 0.0, 0.0, pointDarken / pointCount);
		
	}
]]

return Shadows
