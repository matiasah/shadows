local Shadows = ...

Shadows.BlurShader = love.graphics.newShader [[
	extern number radius = 2;
	extern vec2 size;

	vec4 effect(vec4 color, Image tex, vec2 tc, vec2 pc)
	{
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
]]

Shadows.BloomShader = love.graphics.newShader [[
	extern vec2 size;
	extern int samples = 2; // pixels per axis; higher = bigger glow, worse performance
	extern float quality = 4; // lower = smaller glow, better quality

	vec4 effect(vec4 colour, Image tex, vec2 tc, vec2 sc)
	{
	  vec4 source = Texel(tex, tc);
	  vec4 sum = vec4(0);
	  int diff = (samples - 1) / 2;
	  vec2 sizeFactor = vec2(1) / size * quality;
	  
	  for (int x = -diff; x <= diff; x++)
	  {
		 for (int y = -diff; y <= diff; y++)
		 {
			vec2 offset = vec2(x, y) * sizeFactor;
			sum += Texel(tex, tc + offset);
		 }
	  }
	  
	  return ((sum / (samples * samples)) + source) * colour;
	}
]]

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