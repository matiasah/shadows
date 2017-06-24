module("shadows.Shaders", package.seeall)

Shadows = require("shadows")

Shadows.BlurShader = love.graphics.newShader[[
	
	extern vec2 Size;
	#define Quality 1.0
	#define Radius 2.0
	
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
	
	extern vec2 Size;
	
	#define Radius 1.0		// pixels per axis; higher = bigger glow, worse performance
	#define Quality 5.0			// lower = smaller glow, better quality

	vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
		
		vec4 Sum = vec4(0);
		vec2 SizeFactor = vec2(Quality / Size);
		
		float Samples = 0.0;
		
		for (float x = -Radius; x <= Radius; x++){
		
			for (float y = -Radius; y <= Radius; y++) {
			
				Sum += Texel(tex, tc + vec2(x, y) * SizeFactor);
				Samples++;
				
			}
			
		}
		
		return (Sum / Samples + Texel(tex, tc) ) * color;
	}
	
]]

Shadows.DarkenShader = love.graphics.newShader [[
	
	vec4 effect(vec4 src, Image tex, vec2 tc, vec2 sc) {
		
		return min(src, Texel(tex, tc) );
		
	}
	
]]

-- https://love2d.org/forums/viewtopic.php?t=81014#p189754
Shadows.AberrationShader = love.graphics.newShader[[
	
	extern vec2 Size;
	extern float Aberration;

	vec4 effect(vec4 col, Image texture, vec2 texturePos, vec2 screenPos){
		vec2 coords = texturePos;
		vec2 offset = vec2(Aberration, 0) / Size;
		
		vec4 red = texture2D(texture, coords - offset);
		vec4 green = texture2D(texture, coords);
		vec4 blue = texture2D(texture, coords + offset);
		
		return vec4(red.r, green.g, blue.b, 1E0); //final color with alpha of 1
	}
	
]]; Shadows.AberrationShader:send("Aberration", 2)

Shadows.LightShader = love.graphics.newShader [[
	
	extern float Radius;
	extern vec3 Center;

	vec4 effect(vec4 Color, Image Texture, vec2 tc, vec2 pc) {
		
		float Distance = length( vec3(pc, 0.0) - Center);
		
		if (Distance <= Radius) {
		
			float Mult = 1.0 - ( Distance / Radius );
			
			Color.rgb = Color.rgb * Mult;
		
			return Color;
			
		}
		
		return vec4(0.0, 0.0, 0.0, 0.0);
	}
	
]]

Shadows.RadialBlurShader = love.graphics.newShader [[
	
	extern vec2 Position;
	extern vec2 Size;
	extern float Radius;
	
	#define Quality 				1.3
	
	#define Pi						3.141592653589793238462643383279502884197169399375
	#define invPi					1.0 / Pi
	
	#define BlurRadius			5
	
	float gauss(vec2 vec, float deviation) {
		
		float deviationSquare = pow(deviation, 2.0);
		float invDeviationSquare = 0.5 / deviationSquare;
		float len = pow(vec.x, 2.0) + pow(vec.y, 2.0);
		
		return exp( -len * invDeviationSquare ) * invPi * invDeviationSquare;
		
	}
	
	vec4 effect(vec4 Color, Image Texture, vec2 textureCoord, vec2 pixelCoord) {
		
		float r = length(pixelCoord - Position) / Radius;
		float Deviation = 1.0 + 12.0 * r * smoothstep(0.0, 1.0, r);
		
		vec2 SizeFactor = vec2(Quality / Size);
		vec4 Gradient = vec4(0E0);
		
		for (int x = -BlurRadius; x <= BlurRadius; x++) {
			
			for (int y = -BlurRadius; y <= BlurRadius; y++) {
				
				vec2 vec = vec2(x, y);
				
				Gradient += Texel( Texture, textureCoord + vec * SizeFactor ) * gauss(vec, Deviation);
				
			}
			
		}
		
		return vec4( Gradient.rgb, 1E0 ) * Color;
		
	}
	
]]

Shadows.ShapeShader = love.graphics.newShader [[
	
	vec4 effect(vec4 Color, Image Texture, vec2 textureCoord, vec2 pixelCoord) {
		
		vec4 pixel = Texel(Texture, textureCoord);
		
		if ( pixel.a > 0.0 ) {
			
			if ( pixel.r > 0.0 || pixel.g > 0.0 || pixel.b > 0.0 ) {
				
				return Color;
				
			}
			
		}
		
		return vec4(0.0, 0.0, 0.0, 0.0);
		
	}
	
]]

Shadows.NormalShader = love.graphics.newShader [[
	
	extern vec3 LightPos;
	
	vec4 effect(vec4 Color, Image Texture, vec2 textureCoord, vec2 pixelCoord) {
		
		vec4 NormalMap = Texel(Texture, textureCoord);
		
		vec3 LightDir = vec3( LightPos.xy - pixelCoord.xy, LightPos.z);
		
		vec3 N = normalize(NormalMap.rgb * 2.0 - 1.0);
		vec3 L = normalize(LightDir);
		
		return Color * ( 1.0 - max(dot(N, L), 0.0) );
		
	}
	
]]

return Shadows