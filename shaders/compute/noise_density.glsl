#[compute]
#version 450

//#include "res://shaders/includes/noise.gdshaderinc"

//const int numThreads = 8;

layout(set = 0, binding = 0, std430) buffer PointsBuffer {
	vec4 points[];
}
//layout(set = 0, binding = 1, std140) uniform PointsPerAxis {
//	int numPointsPerAxis;
//};
//layout(set = 0, binding = 2, std140) uniform Position {
//	vec3 position;
//};

//const int octaves = 8;
//const float lacunarity = 2.;
//const float persistance = .54;
//const float scale = 2.71;
//const float weight = 11.24;
//const float multiplier = 10.;

//int indexFromCoord(uint x, uint y, uint z) {
//	return z * numPointsPerAxis * numPointsPerAxis + y * numPointsPerAxis + x;
//}

layout(local_size_x = numThreads, local_size_y = numThreads, local_size_z = numThreads) in;
void main() {
	//if (gl_GlobalInvocationID.x > numPointsPerAxis || gl_GlobalInvocationID.y > numPointsPerAxis || gl_GlobalInvocationID.z > numPointsPerAxis) {
	//	return;
	//}
	
	//vec3 pos = position + gl_GlobalInvocationID;
	//float noise = 0.;//snoise3(pos);
	
	//int index = indexFromCoord(gl_GlobalInvocationID.x, gl_GlobalInvocationID.y, gl_GlobalInvocationID.z);
	//points[index] = vec4(pos, noise);
}
