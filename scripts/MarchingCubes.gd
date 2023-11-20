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

@export_group("Mesh settings")
@export var smoothMesh: bool = true
@export var smoothNormals: bool = false
@export var gradient: Gradient

@export_group("Noise settings")
@export var useRandomSeed: bool = false
@export var sphereical: bool = true
@export var multiplier: float = 20.
@export var noise: FastNoiseLite

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
	if useRandomSeed:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		noise.seed = rng.randi()
	
	if generateOnStart:
		march()

func march() -> void:
	# Sample density (noise) & create GridCell object
	# Pass GridCell into polygoniseCube, construct triangles
	# Pass triangles into surfaceTool
	
	var timeNow: int = Time.get_ticks_msec()
	
	var isoLevel := 0.
	var gridCell := GridCell.new()
	
	var polys: Array[Triangle] = []
	polys.resize(10)
	
	var triangles: Array[Triangle] = []
	var totalTriCount := 0
	
	for x in range(-size.x, size.x):
		for y in range(-size.y, size.y):
			for z in range(-size.x, size.x):
				gridCell.pos.x = x
				gridCell.pos.y = y
				gridCell.pos.z = z
				for i in 8:
					gridCell.value[i] = calcGridCellValue(gridCell.pos + LookupTable.CornerOffsets[i])
				
				var triCount := polygoniseCube(gridCell, isoLevel, polys)
				triangles.resize(totalTriCount + triCount)
				for i in triCount:
					triangles[totalTriCount + i] = polys[i]
					var colorIndex := (y + size.y) / 2. / size.y
					triangles[totalTriCount + i].color[0] = gradient.sample(colorIndex)
					triangles[totalTriCount + i].color[1] = gradient.sample(colorIndex)
					triangles[totalTriCount + i].color[2] = gradient.sample(colorIndex)
				totalTriCount += triCount
	print("Triangles: %s" % [totalTriCount * 3])
	
	var surfaceTool := SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	surfaceTool.set_material(material)
	for i in triangles.size():
		surfaceTool.set_color(triangles[i].color[2])
		surfaceTool.set_normal(triangles[i].normal[2])
		surfaceTool.add_vertex(triangles[i].vertices[2])
		
		surfaceTool.set_color(triangles[i].color[1])
		surfaceTool.set_normal(triangles[i].normal[1])
		surfaceTool.add_vertex(triangles[i].vertices[1])
		
		surfaceTool.set_color(triangles[i].color[0])
		surfaceTool.set_normal(triangles[i].normal[0])
		surfaceTool.add_vertex(triangles[i].vertices[0])
	
	surfaceTool.index()
	self.mesh = surfaceTool.commit()
	$StaticBody3D/CollisionShape3D.shape = self.mesh.create_trimesh_shape()
	print("Vertices: %s" % [totalTriCount])
	
	#generateSphere()
	
	var timeElapsed: int = Time.get_ticks_msec() - timeNow
	if OS.is_debug_build():
		print("%s: Cube march took %s seconds" % [name, float(timeElapsed) / 100])

func calcGridCellValue(pos: Vector3) -> float:
	var noiseVal := -1. if noise.get_noise_3dv(pos) < 0. else 1.
	if smoothMesh:
		noiseVal = noise.get_noise_3dv(pos)
	
	if sphereical:
		return (size.x / 2.) - pos.length() + noiseVal * multiplier
	return -pos.y + noiseVal * multiplier# + fmod(pos.y, 2.) # Add 'pos.y % terraceHeight' for terracing

# Given a grid cell and an isoLevel, calcularte the triangular facets requied to represent the isosurface through the cell.
# Return the number of triangular facets, array "triangles" will be loaded up with the vertices at most 5 triangular facets.
# 0 will be returned if the grid cell is eiter totally above or below the isoLevel
func polygoniseCube(grid: GridCell, iso: float, triangles: Array[Triangle]) -> int:
	# Determine the index into the edge table which tells us which vertices are inside of the surface
	var cubeIndex: int = 0
	if grid.value[0] < iso: cubeIndex |= 1
	if grid.value[1] < iso: cubeIndex |= 2
	if grid.value[2] < iso: cubeIndex |= 4
	if grid.value[3] < iso: cubeIndex |= 8
	if grid.value[4] < iso: cubeIndex |= 16
	if grid.value[5] < iso: cubeIndex |= 32
	if grid.value[6] < iso: cubeIndex |= 64
	if grid.value[7] < iso: cubeIndex |= 128
	
	var edges := LookupTable.TriTable[cubeIndex]
	var triCount := 0
	var i := 0
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
		
		triangles[triCount] = Triangle.new()
		triangles[triCount].vertices[0] = vertexInterp(iso, LookupTable.CornerOffsets[e00], LookupTable.CornerOffsets[e01], grid.value[e00], grid.value[e01]) + grid.pos
		triangles[triCount].vertices[1] = vertexInterp(iso, LookupTable.CornerOffsets[e10], LookupTable.CornerOffsets[e11], grid.value[e10], grid.value[e11]) + grid.pos
		triangles[triCount].vertices[2] = vertexInterp(iso, LookupTable.CornerOffsets[e20], LookupTable.CornerOffsets[e21], grid.value[e20], grid.value[e21]) + grid.pos
		
		if smoothNormals:
			triangles[triCount].normal[0] = triangles[triCount].vertices[0].normalized()
			triangles[triCount].normal[1] = triangles[triCount].vertices[1].normalized()
			triangles[triCount].normal[2] = triangles[triCount].vertices[2].normalized()
		else:
			var normal := (triangles[triCount].vertices[1] - triangles[triCount].vertices[0]).cross(triangles[triCount].vertices[2] - triangles[triCount].vertices[0])
			triangles[triCount].normal[0] = normal
			triangles[triCount].normal[1] = normal
			triangles[triCount].normal[2] = normal
		
		triCount += 1
		i += 3
	return triCount

# Return the point between two points in the same ratio as isoLevel is between valp1 & valp2
func vertexInterp(iso: float, p1: Vector3, p2: Vector3, valp1: float, valp2: float) -> Vector3:
	return p1 + (iso - valp1) * (p2 - p1) / (valp2 - valp1)

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
