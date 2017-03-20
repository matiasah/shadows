local Shadows = ...

Shadows.BlurShader = love.graphics.newShader[[
	
	extern vec2 Size;
	#define Quality 1.0
	#define Radius 2.0
	
	vec4 effect(vec4 color, Image tex, vec2 tc, vec2 pc) {
		
		vec4 Sum = vec4(0);
		vec2 SizeFactor = vec2(Quality / Size);
		
		for (number x = -Radius; x <= Radius; x++) {
			
			for (number y = -Radius; y <= Radius; y++) {
				
				Sum += Texel(tex, tc + vec2(x, y) * SizeFactor);
				
			}
		
		}
		
		number Delta = 2.0 * Radius + 1.0;
		
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
		
		number Samples = 0.0;
		
		for (number x = -Radius; x <= Radius; x++){
		
			for (number y = -Radius; y <= Radius; y++) {
			
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
	extern number Aberration;

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
	
	extern number Radius;
	extern vec3 Center;

	vec4 effect(vec4 Color, Image Texture, vec2 tc, vec2 pc) {
		
		number Distance = length(vec3(pc, 0E0) - Center);
		
		if (Distance <= Radius) {
		
			number Mult = 1E0 - ( Distance / Radius );
			
			Color.r = Color.r * Mult;
			Color.g = Color.g * Mult;
			Color.b = Color.b * Mult;
		
			return Color;
			
		}
		
		return vec4(0E0, 0E0, 0E0, 0E0);
	}
	
]]

Shadows.RadialBlurShader = love.graphics.newShader [[
	
	extern vec2 Position;
	extern vec2 Size;
	extern number Radius;
	
	#define Quality 				1.6
	
	#define Pi						3.141592653589793238462643383279502884197169399375
	#define invPi					1 / Pi
	#define StandardDeviation 	1
	
	#define BlurRadius			8
	
	number gauss(int x, int y, number deviation) {
		
		number deviationSquare = pow(deviation, 2);
		number invDeviationSquare = 0.5 / deviationSquare;
		
		return exp( -( pow(x, 2) + pow(y, 2) ) * invDeviationSquare ) * invPi * invDeviationSquare;
		
	}
	
	vec4 effect(vec4 Color, Image Texture, vec2 textureCoord, vec2 pixelCoord) {
		
		number r = length(pixelCoord - Position) / Radius;
		number Deviation = 1 + 12 * r * smoothstep(0, 1, r);
		
		vec2 SizeFactor = vec2(Quality / Size);
		vec4 Gradient = vec4(0E0);
		
		for (int x = -BlurRadius; x <= BlurRadius; x++) {
			
			for (int y = -BlurRadius; y <= BlurRadius; y++) {
				
				Gradient += Texel( Texture, textureCoord + vec2(x, y) * SizeFactor ) * gauss(x, y, Deviation);
				
			}
			
		}
		
		return vec4( Gradient.rgb, 1E0 ) * Color;
		
	}
	
]]