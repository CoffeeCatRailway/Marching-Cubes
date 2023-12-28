shader_type spatial;

uniform vec3 grassLightColor : source_color;
uniform vec3 grassDarkColor : source_color;

uniform vec3 dirtLightColor : source_color;
uniform vec3 dirtDarkColor : source_color;

uniform vec3 rockLightColor : source_color;
uniform vec3 rockDarkColor : source_color;

uniform sampler2D noiseTex;

uniform float dirtOffset : hint_range(-1., 1., .05) = -.35;
uniform float dirtFade : hint_range(0., 1., .05) = 0.;

uniform float rockOffset : hint_range(-1., 1., .05) = .05;
uniform float rockFade : hint_range(0., 1., .05) = 0.;

uniform sampler3D chunkTexture : source_color, repeat_disable;
uniform float isoLevel = 0.;
uniform float isoMargin : hint_range(0., 1., .01) = .01;
uniform float isoOffset : hint_range(-1., 1., .01) = .02;
uniform float chunkSize = 100.;

varying vec3 worldPos;

void vertex() {
	worldPos = (MODEL_MATRIX * vec4(VERTEX, 1.)).xyz;
}

void fragment() {
	float noiseXZ = texture(noiseTex, worldPos.xz / 30.).r;
	float noiseXY = texture(noiseTex, worldPos.xy / 30.).r;
	
	vec3 grassColor = mix(grassLightColor, grassDarkColor, noiseXZ);
	vec3 dirtColor = mix(dirtLightColor, dirtDarkColor, noiseXY);
	vec3 rockColor = mix(rockLightColor, rockDarkColor, (noiseXY + noiseXZ) / 2.);
	
	float normalDotProduct = dot(mat3(VIEW_MATRIX) * vec3(0., -1., 0.), NORMAL);
	float dirtMask = smoothstep(dirtOffset - dirtFade, dirtOffset + dirtFade, normalDotProduct);
	float rockMask = smoothstep(rockOffset - rockFade, rockOffset + rockFade, -normalDotProduct);
	
	vec3 grassDirtColor = mix(grassColor, dirtColor, dirtMask);
	vec3 dirtRockColor = mix(dirtColor, rockColor, rockMask);
	
	//vec3 groundColor = mix(rockColor, dirtColor, rockMask);
	//ALBEDO = mix(grassColor, groundColor, dirtMask);
	
	float worldYValue = texture(chunkTexture, worldPos / chunkSize).y;
	float undergroundMix = smoothstep(isoLevel + isoOffset, isoLevel + isoOffset + isoMargin, worldYValue);
	ALBEDO = mix(grassDirtColor, dirtRockColor, undergroundMix);
	//ALBEDO = vec3(undergroundMix);
}
