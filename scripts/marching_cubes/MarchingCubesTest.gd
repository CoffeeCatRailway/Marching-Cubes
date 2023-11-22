@tool
class_name MarchingCubes
extends MeshInstance3D

@export var generate: bool = false:
	set(_value):
		march()
		generate = false
@export var generateOnStart: bool = false
@export var clear: bool = false:
	set(_value):
		self.mesh = null
		$StaticBody3D/CollisionShape3D.shape = null
		clear = false

@export var size: Vector2 = Vector2(60, 40):
	set(value):
		size = value.abs()

@export var marcherSettings: MarcherSettings

@export_group("Noise settings")
@export var useRandomSeed: bool = false:
	set(value):
		useRandomSeed = value
		randomiseNoise()
@export var sphereical: bool = false
@export var noiseMultiplier: float = 10.
@export var noiseMaskMultiplier: float = 20.
@export var noiseTunnelMultiplier: float = 2.
@export var noise: FastNoiseLite
@export var noiseMask: FastNoiseLite
@export var noiseTunnel: FastNoiseLite

class GridCell:
	var pos := Vector3.ZERO
	var value: Array[float] = []
	
	func _init():
		value.resize(8)
		value.fill(0.)

class Triangle:
	var vertices: Array[Vector3] = []
	var normal: Array[Vector3] = []
	var color: Array[Color] = []
	
	func _init():
		vertices.resize(3)
		vertices.fill(Vector3.ZERO)
		normal.resize(3)
		normal.fill(Vector3.ZERO)
		color.resize(3)
		color.fill(Color.DIM_GRAY)

func _ready() -> void:
	randomiseNoise()
	marcherSettings.noiseFunc = Callable(self, "calcGridCellValue")
	
	if generateOnStart:
		march()

func randomiseNoise() -> void:
	if useRandomSeed:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		noise.seed = rng.randi()
		noiseMask.seed = rng.randi()
		noiseTunnel.seed = rng.randi()

func march() -> void:
	# Sample density (noise) & create GridCell object
	# Pass GridCell into polygoniseCube, construct triangles
	# Pass triangles into surfaceTool
	
	var timeNow: int = Time.get_ticks_msec()
	
	self.mesh = Marcher.march(Vector3.ZERO, size, marcherSettings, true)
	$StaticBody3D/CollisionShape3D.shape = self.mesh.create_trimesh_shape()
	
	#generateSphere()
	
	var timeElapsed: int = Time.get_ticks_msec() - timeNow
	if OS.is_debug_build():
		print("%s: Cube march took %s seconds" % [name, float(timeElapsed) / 100.])

func calcGridCellValue(pos: Vector3) -> float:
	var noiseVal: float = 0.
	noiseVal += noise.get_noise_3dv(pos) * noiseMultiplier
	noiseVal += absf(noiseMask.get_noise_3dv(pos) * noiseMaskMultiplier)
	
	if (-pos.y) + noiseVal > (noiseMultiplier + noiseMaskMultiplier) / 21.:
		noiseVal *= noiseTunnel.get_noise_3dv(pos) * noiseTunnelMultiplier
	
	if sphereical:
		return (size.x / 2.) - pos.length() + noiseVal
	return (-pos.y) + noiseVal# + fmod(pos.y, 4.) # Add 'pos.y % terraceHeight' for terracing

func generateSphere(rings: int = 10, radialSegments: int = 10, radius: float = 1.) -> void:
	self.mesh = ArrayMesh.new()
	
	var surfaceArray := []
	surfaceArray.resize(Mesh.ARRAY_MAX)
	
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	
	# Vertex indices.
	var thisrow = 0
	var prevrow = 0
	var point = 0

	# Loop over rings.
	for i in range(rings + 1):
		var v = float(i) / rings
		var w = sin(PI * v)
		var y = cos(PI * v)

		# Loop over segments in ring.
		for j in range(radialSegments):
			var u = float(j) / radialSegments
			var x = sin(u * PI * 2.0)
			var z = cos(u * PI * 2.0)
			var vert = Vector3(x * radius * w, y * radius, z * radius * w)
			vertices.append(vert)
			normals.append(vert.normalized())
			uvs.append(Vector2(u, v))
			point += 1

			# Create triangles in ring using indices.
			if i > 0 and j > 0:
				indices.append(prevrow + j - 1)
				indices.append(prevrow + j)
				indices.append(thisrow + j - 1)

				indices.append(prevrow + j)
				indices.append(thisrow + j)
				indices.append(thisrow + j - 1)

		if i > 0:
			indices.append(prevrow + radialSegments - 1)
			indices.append(prevrow)
			indices.append(thisrow + radialSegments - 1)

			indices.append(prevrow)
			indices.append(prevrow + radialSegments)
			indices.append(thisrow + radialSegments - 1)

		prevrow = thisrow
		thisrow = point
	
	surfaceArray[Mesh.ARRAY_VERTEX] = vertices
	surfaceArray[Mesh.ARRAY_TEX_UV] = uvs
	surfaceArray[Mesh.ARRAY_NORMAL] = normals
	surfaceArray[Mesh.ARRAY_INDEX] = indices
	
	# No blendshapes, lods, or compression used
	self.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surfaceArray)
