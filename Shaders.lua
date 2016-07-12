local Shadows = ...

Shadows.PenumbraShader = love.graphics.newShader [[
	extern number twopi;
	extern number Source;
	extern number Goal;
	extern vec2 vSource;
	
	vec4 effect(vec4 Color, Image Texture, vec2 tc, vec2 pc){
		vec2 Direction = pc - vSource;
		float Heading = atan(Direction.y, Direction.x);
		
		if (Heading - Source > twopi){
			Heading = Heading - twopi;
		}else if (Heading - Source < -twopi){
			Heading = Heading + twopi;
		}
		float Alpha = abs(Source - Heading)/abs(Source - Goal);
		
		return vec4(Alpha, Alpha, Alpha, 1);
	}
]]; Shadows.PenumbraShader:send("twopi", math.pi * 2)

Shadows.BlurShader = love.graphics.newShader [[
	extern number radius = 1;
	extern vec2 size;

	vec4 effect(vec4 color, Image tex, vec2 tc, vec2 pc){
		color = vec4(0);
		vec2 st;

		for (float x = -radius; x <= radius; x++) {
			for (float y = -radius; y <= radius; y++) {
				// to texture coordinates
				st.xy = vec2(x,y) / size;
				color += Texel(tex, tc + st);
			}
		}
		return color / ((2.0 * radius + 1.0) * (2.0 * radius + 1.0));
	}
]]; Shadows.BlurShader:send("size", {love.graphics.getDimensions()})

Shadows.BloomShader = love.graphics.newShader [[
	extern vec2 size;
	extern int samples = 4; // pixels per axis; higher = bigger glow, worse performance
	extern float quality = 2; // lower = smaller glow, better quality

	vec4 effect(vec4 colour, Image tex, vec2 tc, vec2 sc){
		vec4 source = Texel(tex, tc);
		vec4 sum = vec4(0);
		int diff = (samples - 1) / 2;
		vec2 sizeFactor = vec2(1) / size * quality;
	  
		for (int x = -diff; x <= diff; x++){
			for (int y = -diff; y <= diff; y++)
			{
				vec2 offset = vec2(x, y) * sizeFactor;
				sum += Texel(tex, tc + offset);
			}
		}
		return ((sum / (samples * samples)) + source) * colour;
	}
]]; Shadows.BloomShader:send("size", {love.graphics.getDimensions()})

-- https://love2d.org/forums/viewtopic.php?t=81014#p189754
Shadows.AberrationShader = love.graphics.newShader([[
	extern number aberration = 0.002;

	vec4 effect(vec4 col, Image texture, vec2 texturePos, vec2 screenPos){
		vec2 coords = texturePos;
		vec2 offset = vec2(aberration, 0);

		vec4 red = texture2D(texture , coords - offset);
		vec4 green = texture2D(texture, coords);
		vec4 blue = texture2D(texture, coords + offset);

		vec4 finalColor = vec4(red.r, green.g, blue.b, 1.0f);
		return finalColor;
	}
]])

Shadows.LightShader = love.graphics.newShader [[
	extern vec3 Center;
	extern vec3 LightColor;
	extern float LightRadius;

	vec4 effect(vec4 Color, Image Texture, vec2 TextureCords, vec2 PixelCords){
		float Distance = length(vec3(PixelCords.x, PixelCords.y, 0.0) - Center);
		if (Distance <= LightRadius) {
			return vec4(LightColor, 1 - (Distance / LightRadius));
		}
		return vec4(0, 0, 0, 0);
	}
]]