shader_type spatial;

uniform vec4 grassLightColor : source_color;
uniform vec4 grassDarkColor : source_color;
uniform vec4 rockLightColor : source_color;
uniform vec4 rockDarkColor : source_color;

uniform sampler2D noiseTex;

uniform float offset : hint_range(-1., 1., .05) = .5;
uniform float fade : hint_range(0., 1., .05) = 0.;

varying vec3 worldPos;

void vertex() {
	worldPos = (MODEL_MATRIX * vec4(VERTEX, 1.)).xyz;
}

void fragment() {
	vec4 noiseXZ = texture(noiseTex, worldPos.xz / 30.);
	vec4 noiseXY = texture(noiseTex, worldPos.xy / 30.);
	
	float dotProduct = dot(mat3(VIEW_MATRIX) * vec3(0., -1., 0.), NORMAL);
	float mask = smoothstep(offset - fade, offset + fade, dotProduct);
	
	vec4 grassColor = mix(grassLightColor, grassDarkColor, noiseXZ.r);
	vec4 rockColor = mix(rockLightColor, rockDarkColor, noiseXY.r);
	
	ALBEDO = mix(grassColor, rockColor, mask).rgb;
}
