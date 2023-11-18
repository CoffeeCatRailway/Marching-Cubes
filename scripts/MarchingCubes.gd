@tool
class_name Commandar
extends Node

@export var generate: bool = false:
	set(value):
		_ready()
		generate = false
@export var clear: bool = false:
	set(value):
		meshInstance.mesh = null
		clear = false

@export var useRandomSeed: bool = true
@export_range(1, 100, 1, "or_greater") var worldSize: int = 20
@export var smooth: bool = false
@export var smoothNormals: bool = false

@export var meshInstance: MeshInstance3D
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
	
	func _init():
		vertices.resize(3)
		vertices.fill(Vector3.ZERO)
		normal.resize(3)
		normal.fill(Vector3.ZERO)

func _ready() -> void:
	if useRandomSeed:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		noise.seed = rng.randi()
	
	var surfaceTool := SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Sample density (noise) & create GridCell object
	# Pass GridCell into polygoniseCube, construct triangles
	# Pass triangles into surfaceTool
	
	var isoLevel := 0.
	var gridCell := GridCell.new()
	
	var polys: Array[Triangle] = []
	polys.resize(10)
	
	var triangles: Array[Triangle] = []
	var triCount := 0
	
	for x in worldSize:
		for y in worldSize:
			for z in worldSize:
				gridCell.pos.x = x
				gridCell.pos.y = y
				gridCell.pos.z = z
				for i in 8:
					gridCell.value[i] = calcGridCellValue(gridCell.pos + LookupTable.CornerOffsets[i])
				
				var polyCount := polygoniseCube(gridCell, isoLevel, polys)
				triangles.resize(triCount + polyCount)
				for i in polyCount:
					triangles[triCount + i] = polys[i]
				triCount += polyCount
	print("Total triangles: %s" % [triCount])
	
	for i in triangles.size():
		surfaceTool.set_normal(triangles[i].normal[2])
		surfaceTool.add_vertex(triangles[i].vertices[2])
		
		surfaceTool.set_normal(triangles[i].normal[1])
		surfaceTool.add_vertex(triangles[i].vertices[1])
		
		surfaceTool.set_normal(triangles[i].normal[0])
		surfaceTool.add_vertex(triangles[i].vertices[0])
	
	surfaceTool.index()
	meshInstance.mesh = surfaceTool.commit()
	
	#generateSphere()

func calcGridCellValue(pos: Vector3) -> float:
	if smooth:
		return noise.get_noise_3dv(pos)
	else:
		return -1. if noise.get_noise_3dv(pos) < 0. else 1.

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
	meshInstance.mesh = ArrayMesh.new()
	
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
	meshInstance.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surfaceArray)
