shader_type spatial;

uniform vec4 grassLightColor : source_color;
uniform vec4 grassDarkColor : source_color;

uniform vec4 dirtLightColor : source_color;
uniform vec4 dirtDarkColor : source_color;

uniform vec4 rockLightColor : source_color;
uniform vec4 rockDarkColor : source_color;

uniform sampler2D noiseTex;

uniform float dirtOffset : hint_range(-1., 1., .05) = -.35;
uniform float dirtFade : hint_range(0., 1., .05) = 0.;

uniform float rockOffset : hint_range(-1., 1., .05) = .05;
uniform float rockFade : hint_range(0., 1., .05) = 0.;

uniform sampler3D chunkTexture : source_color, repeat_disable;
uniform float isoLevel = 0.;
uniform float isoMargin : hint_range(0., 1., .01) = .02;
uniform float chunkSize = 100.;

varying vec3 worldPos;

void vertex() {
	worldPos = (MODEL_MATRIX * vec4(VERTEX, 1.)).xyz;
}

void fragment() {
	vec4 noiseXZ = texture(noiseTex, worldPos.xz / 30.);
	vec4 noiseXY = texture(noiseTex, worldPos.xy / 30.);
	
	float dirtDotProduct = dot(mat3(VIEW_MATRIX) * vec3(0., -1., 0.), NORMAL);
	float dirtMask = smoothstep(dirtOffset - dirtFade, dirtOffset + dirtFade, dirtDotProduct);
	
	float rockDotProduct = dot(mat3(VIEW_MATRIX) * vec3(0., 1., 0.), NORMAL);
	float rockMask = smoothstep(rockOffset - rockFade, rockOffset + rockFade, rockDotProduct);
	
	vec4 grassColor = mix(grassLightColor, grassDarkColor, noiseXZ.r);
	vec4 dirtColor = mix(dirtLightColor, dirtDarkColor, noiseXY.r);
	vec4 rockColor = mix(rockLightColor, rockDarkColor, noiseXY.r);
	
	//vec4 groundColor = mix(rockColor, dirtColor, rockMask);
	//ALBEDO = mix(grassColor, groundColor, dirtMask).rgb;
	
	vec3 worldValue = texture(chunkTexture, worldPos / chunkSize).xyz;
	
	bool underground = worldValue.y > isoLevel + isoMargin;
	//ALBEDO = mix(mix(dirtColor, rockColor, rockMask).rgb, mix(grassColor, dirtColor, dirtMask).rgb, underground ? 0. : 1.);
	if (underground)
		ALBEDO = mix(dirtColor, rockColor, rockMask).rgb;
	else
		ALBEDO = mix(grassColor, dirtColor, dirtMask).rgb;
	
	//ALBEDO = underground ? vec3(1.) : vec3(0.);
}
