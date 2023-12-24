@tool
extends Node3D

@export var setup := false:
	set(_value):
		_ready()
		setup = false
@export var generate := false:
	set(_value):
		generateMesh()
		generate = false
@export var randomHole := false:
	set(_value):
		digRandomHole()
		randomHole = false

@export_range(1., 200., 1.) var size := 100.
@export_range(1, 200, 1) var resolution := 60
@export_range(1, 200, 1) var lod := 60
@export var settings: MarcherSettings
@export var material: Material
var theoreticalMaxNoise: float

var valueArray: PackedByteArray

var meshInstance: MeshInstance3D

var random: RandomNumberGenerator

var minVal := 10.
var maxVal := 0.

func _ready() -> void:
	meshInstance = $MeshInstance3D
	
	var seed := settings.randomiseNoise("0")
	theoreticalMaxNoise = getMaxNoise(-(resolution / 2.), settings) / minf(settings.baseMul, settings.maskMul) / 2.
	print("Theoretical max noise value: ", theoreticalMaxNoise)
	
	random = RandomNumberGenerator.new()
	random.seed = seed
	
	var timeNow := Time.get_ticks_msec()
	var data: Array[Image] = []
	var dataNoTunnels: Array[Image] = []
	for z in resolution:
		data.append(createSlice(resolution, z, true))
		dataNoTunnels.append(createSlice(resolution, z, false))
	
	var texture := ImageTexture3D.new()
	texture.create(Image.FORMAT_L8, resolution, resolution, resolution, false, data)
	var textureNoTunnels := ImageTexture3D.new()
	textureNoTunnels.create(Image.FORMAT_L8, resolution, resolution, resolution, false, dataNoTunnels)
	print("Texture creation took %s miliseconds" % [Time.get_ticks_msec() - timeNow])
	print("Min: %s, Max: %s" % [minVal, maxVal])
	
	(material as ShaderMaterial).set_shader_parameter("chunkTexture", textureNoTunnels)
	(material as ShaderMaterial).set_shader_parameter("isoLevel", settings.isoLevel)
	(material as ShaderMaterial).set_shader_parameter("chunkSize", size)
	
	timeNow = Time.get_ticks_msec()
	valueArray = PackedByteArray()
	
	var mi := 10
	var ma := 0
	for z in resolution:
		var byteArray := texture.get_data()[z].get_data()
		for i in byteArray:
			mi = min(i, mi)
			ma = max(i, ma)
		valueArray.append_array(byteArray)
	print("Min: %s, Max: %s" % [mi, ma])
	print("Point array took %s miliseconds" % [Time.get_ticks_msec() - timeNow])
	print(valueArray[indexFromCoord(0, 0, 0, resolution)], " - ", valueArray[indexFromCoord(0, resolution, 0, resolution)])
	
	#var slice := texture.get_data()[0]
	#var array := slice.get_data()
	#for i in 10:
	#	print(valueArray[i], ", ", array[i])
	#print(array.size())
	#print(slice.get_pixel(0, 0).get_luminance(), " - ", array[0] / 255.)
	#print(slice.get_pixel(1, 0).get_luminance(), " - ", array[1] / 255.)
	
	#generateMesh()

func getMaxNoise(maxY: float, settings: MarcherSettings) -> float:
	var value := -maxY
	value += 1. * settings.baseMul
	value += 1. * settings.maskMul
	return absf(value)

func noiseFunc(pos: Vector3, hasTunnels: bool) -> float:
	#if pos.y <= -(chunkSize / 2.):
	#	return settings.isoLevel;
	var noiseVal: float = -pos.y
	noiseVal += settings.noiseBase.get_noise_3dv(pos) * settings.baseMul
	#noiseVal += marcherSettings.noiseMask.get_noise_3dv(pos) * marcherSettings.maskMul
	noiseVal += maxf(settings.minMaskHeight, settings.noiseMask.get_noise_3dv(pos)) * settings.maskMul
	
	noiseVal /= (settings.baseMul + settings.maskMul) # Bring values closer to -1 to 1
	# Bring to 0-1, given baseMul & maskMul are equal
	# If maskMul < baseMul then max > 1
	noiseVal = (noiseVal + theoreticalMaxNoise) / (theoreticalMaxNoise * 2.)
	
	if hasTunnels:
		var tunnel := settings.noiseTunnel.get_noise_3dv(pos)# * settings.tunnelMul
		if tunnel < 0. && noiseVal >= settings.isoLevel: # Check if tunnel value is negative & noiseVal is "filled"
			noiseVal *= tunnel
			noiseVal = (noiseVal + 1.) / 2. # Bring value back to 0-1
	
	#noiseVal = snappedf(noiseVal, .001)
	minVal = minf(minVal, noiseVal)
	maxVal = maxf(maxVal, noiseVal)
	return clampf(noiseVal, 0., 1.)

var tempPos: Vector3 = Vector3.ZERO
func createSlice(size: int, slice: int, hasTunnels: bool) -> Image:
	var image := Image.create(size, size, false, Image.FORMAT_L8)
	for x in size:
		for y in size:
			tempPos.x = x
			tempPos.y = (y - size / 2.)
			tempPos.z = slice
			tempPos += position
			#tempPos.y *= -1.
			
			var value := noiseFunc(tempPos, hasTunnels)
			image.set_pixel(x, y, Color.from_hsv(0., 0., value))
	return image

func digRandomHole() -> void:
	var holePos := Vector3(random.randi_range(0, resolution - 1), random.randi_range(0, resolution - 1), random.randi_range(0, resolution - 1))
	var radius := float(random.randi() % 10 + 1)
	print("Hole position: ", holePos)
	print("Hole radius: ", radius)
	for x in resolution:
		for y in resolution:
			for z in resolution:
				var pos := Vector3(x, y, z)
				var dist := holePos.distance_to(pos)
				if dist <= radius:
					var index := indexFromCoord(x, y, z, resolution)
					valueArray[index] = 0 # 1 (255) is filled, 0 is empty

#const OFFSET := Vector3(0., .5, 0.)#Vector3.ONE / 2.
func generateMesh() -> void:
	var timeNow := Time.get_ticks_msec()
	meshInstance.mesh = null
	
	var surfaceTool := SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var totalTris := 0
	for x in lod:
		for y in lod:
			for z in lod:
				var samplePos := Vector3i(x, y, z)
				var polys: Array[Marcher.Triangle] = polygoniseCubeFromTexture(samplePos, resolution, lod, size, valueArray, settings)
				if polys.size() == 0:
					continue
				totalTris += polys.size()
				
				for tri in polys:
					surfaceTool.set_normal(tri.normal[2])
					#surfaceTool.set_color(Color(tri.normal[2].x, tri.normal[2].y, tri.normal[2].z))
					surfaceTool.add_vertex(tri.vertices[2])
					
					surfaceTool.set_normal(tri.normal[1])
					surfaceTool.add_vertex(tri.vertices[1])
					
					surfaceTool.set_normal(tri.normal[0])
					surfaceTool.add_vertex(tri.vertices[0])
				
				#var index := indexFromCoord(x, y, z, resolution)
				#(material as ShaderMaterial).set_shader_parameter("underground", valueArray[index] >= settings.isoLevel)
	
	print("Triangles: ", totalTris)
	meshInstance.mesh = surfaceTool.commit()
	if meshInstance.mesh.get_surface_count() > 0:
		meshInstance.mesh.surface_set_material(0, material)
	print("Mesh generation took %s miliseconds" % [Time.get_ticks_msec() - timeNow])

func roundToNearest(f: float) -> int:
	var fract: float = f - floorf(f)
	if fract < .6:
		return floori(f)
	return floori(f) + 1

func indexFromCoord(x: float, y: float, z: float, resolution: int) -> int:
	x = roundf(x)#clampi(x, 0, resolution - 1)
	y = roundf(y)#clampi(y, 0, resolution - 1)
	z = roundf(z)#clampi(z, 0, resolution - 1)
	return z * resolution * resolution + y * resolution + x

func vertexInterp(v1: Vector4, v2: Vector4, isoLevel: float) -> Vector3:
	#p1 + (iso - valp1) * (p2 - p1) / (valp2 - valp1)
	var v1p := Vector3(v1.x, v1.y, v1.z)
	var v2p := Vector3(v2.x, v2.y, v2.z)
	
	if is_equal_approx(isoLevel - v1.w, 0.) || is_equal_approx(v1.w - v2.w, 0.):
		return v1p
	if is_equal_approx(isoLevel - v2.w, 0.):
		return v2p
	
	#var mu := (isoLevel - v1.w) / (v2.w - v1.w)
	#return v1p + mu * (v2p - v1p)
	return v1p + (isoLevel - v1.w) * (v2p - v1p) / (v2.w - v1.w)

func vertexInterpMid(v1: Vector4, v2: Vector4) -> Vector3:
	var v1p := Vector3(v1.x, v1.y, v1.z)
	var v2p := Vector3(v2.x, v2.y, v2.z)
	return (v1p + v2p) / 2.

func polygoniseCubeFromTexture(pos: Vector3i, resolution: int, lod: int, size: float, valueArray: PackedByteArray, marcherSettings: MarcherSettings) -> Array[Marcher.Triangle]:
	# Stop one point before the end of voxel grid
	if pos.x >= lod - 1 || pos.y >= lod - 1 || pos.z >= lod - 1:
		return []
	
	# Get the percentage of the currnet point
	#var percent: Vector3 = pos / lod
	#var vertex: Vector3 = percent * size
	var resMul := resolution / lod
	var spacing := size / float(lod)
	# 8 corners of the current cube
	#if pos == Vector3i.ZERO:
	#	print("Resolution multiplier: ", resMul)
	#	print("Spacing: ", spacing)
	var cubeCorners: Array = [
		Vector4(pos.x * spacing, 		pos.y * spacing, 		pos.z * spacing, 		valueArray[indexFromCoord(pos.x * resMul, 		pos.y * resMul, 		pos.z * resMul, 		resolution)] / 255.),
		Vector4((pos.x + 1.) * spacing, pos.y * spacing, 		pos.z * spacing, 		valueArray[indexFromCoord((pos.x + 1) * resMul, pos.y * resMul, 		pos.z * resMul, 		resolution)] / 255.),
		Vector4((pos.x + 1.) * spacing, (pos.y + 1.) * spacing, pos.z * spacing, 		valueArray[indexFromCoord((pos.x + 1) * resMul, (pos.y + 1) * resMul, 	pos.z * resMul, 		resolution)] / 255.),
		Vector4(pos.x * spacing, 		(pos.y + 1.) * spacing, pos.z * spacing, 		valueArray[indexFromCoord(pos.x * resMul, 		(pos.y + 1) * resMul, 	pos.z * resMul, 		resolution)] / 255.),
		Vector4(pos.x * spacing, 		pos.y * spacing, 		(pos.z + 1.) * spacing, valueArray[indexFromCoord(pos.x * resMul, 		pos.y * resMul, 		(pos.z + 1) * resMul, 	resolution)] / 255.),
		Vector4((pos.x + 1.) * spacing, pos.y * spacing, 		(pos.z + 1.) * spacing, valueArray[indexFromCoord((pos.x + 1) * resMul, pos.y * resMul, 		(pos.z + 1) * resMul, 	resolution)] / 255.),
		Vector4((pos.x + 1.) * spacing, (pos.y + 1.) * spacing, (pos.z + 1.) * spacing, valueArray[indexFromCoord((pos.x + 1) * resMul, (pos.y + 1) * resMul, 	(pos.z + 1) * resMul, 	resolution)] / 255.),
		Vector4(pos.x * spacing, 		(pos.y + 1.) * spacing, (pos.z + 1.) * spacing, valueArray[indexFromCoord(pos.x * resMul, 		(pos.y + 1) * resMul, 	(pos.z + 1) * resMul, 	resolution)] / 255.)
	]
	
	# Calculate unique index for each configuration
	var cubeIndex := 0
	if cubeCorners[0].w < marcherSettings.isoLevel: cubeIndex |= 1
	if cubeCorners[1].w < marcherSettings.isoLevel: cubeIndex |= 2
	if cubeCorners[2].w < marcherSettings.isoLevel: cubeIndex |= 4
	if cubeCorners[3].w < marcherSettings.isoLevel: cubeIndex |= 8
	if cubeCorners[4].w < marcherSettings.isoLevel: cubeIndex |= 16
	if cubeCorners[5].w < marcherSettings.isoLevel: cubeIndex |= 32
	if cubeCorners[6].w < marcherSettings.isoLevel: cubeIndex |= 64
	if cubeCorners[7].w < marcherSettings.isoLevel: cubeIndex |= 128
	
	if cubeIndex == 0 || cubeIndex == 255:
		return []
	
	var edges := LookupTable.TriTable[cubeIndex]
	var triangles: Array[Marcher.Triangle] = []
	var i := 0
	#var posVec3 := Vector3(pos)
	while edges[i] != -1:
		# First edge lies between vertex e00 & e01
		var e00: int = LookupTable.EdgeConnections[edges[i]][0]
		var e01: int = LookupTable.EdgeConnections[edges[i]][1]
		
		# Second edge lies between vertex e10 & e11
		var e10: int = LookupTable.EdgeConnections[edges[i + 1]][0]
		var e11: int = LookupTable.EdgeConnections[edges[i + 1]][1]
		
		# Third edge lies between vertex e20 & e21
		var e20: int = LookupTable.EdgeConnections[edges[i + 2]][0]
		var e21: int = LookupTable.EdgeConnections[edges[i + 2]][1]
		
		var triangle = Marcher.Triangle.new()
		if marcherSettings.smoothMesh:
			triangle.vertices[0] = vertexInterp(cubeCorners[e00], cubeCorners[e01], marcherSettings.isoLevel)# + posVec3
			triangle.vertices[1] = vertexInterp(cubeCorners[e10], cubeCorners[e11], marcherSettings.isoLevel)# + posVec3
			triangle.vertices[2] = vertexInterp(cubeCorners[e20], cubeCorners[e21], marcherSettings.isoLevel)# + posVec3
		else:
			triangle.vertices[0] = vertexInterpMid(cubeCorners[e00], cubeCorners[e01])# + posVec3
			triangle.vertices[1] = vertexInterpMid(cubeCorners[e10], cubeCorners[e11])# + posVec3
			triangle.vertices[2] = vertexInterpMid(cubeCorners[e20], cubeCorners[e21])# + posVec3
		
		var normal: Vector3 = (triangle.vertices[1] - triangle.vertices[0]).cross(triangle.vertices[2] - triangle.vertices[0]).normalized()
		triangle.normal[0] = normal
		triangle.normal[1] = normal
		triangle.normal[2] = normal
		
		#triangle.normal[0] = triangle.vertices[0].normalized()
		#triangle.normal[1] = triangle.vertices[1].normalized()
		#triangle.normal[2] = triangle.vertices[2].normalized()
		
		triangles.append(triangle)
		i += 3
	return triangles
