@tool
extends Node

var surfaceTool: SurfaceTool
var material: StandardMaterial3D

class GridCell:
	var pos: Vector3i
	var value: Array[float]
	
	func _init(x: int = 0, y: int = 0, z: int = 0, _value: Array[float] = [0., 0., 0., 0., 0., 0., 0., 0.]):
		pos = Vector3i(x, y, z)
		value = _value

class Triangle:
	var vertices: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	var normal: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	var color: Array[Color] = [Color.DIM_GRAY, Color.DIM_GRAY, Color.DIM_GRAY]

func _ready() -> void:
	surfaceTool = SurfaceTool.new()
	material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true

func march(pos: Vector3, size: Vector3i, settings: MarcherSettings, gridCells: Array[GridCell] = []) -> Dictionary:
	var timeNow: int
	if pos == Vector3.ZERO:
		timeNow = Time.get_ticks_msec()
	
	var genGridCells = gridCells.size() == 0
	if genGridCells:
		gridCells.resize(size.x * (size.y + size.z) * size.x)
	
	var polys: Array[Triangle] = []
	polys.resize(10)
	
	var triangles: Array[Triangle] = []
	var totalTriCount := 0
	
	# size=(10,60,30), chunk is 10x90x10, 9000 iterations ~= 150 milliseconds
	for x in range(size.x):
		for y in range(-size.z, size.y): # size.y=10, -10 to 9, y+size.y = 0 to 19
			for z in range(size.x):
				var gridCell: GridCell
				var index = z * size.x * (size.y + size.z) + y * size.x + x
				if index >= gridCells.size():
					push_warning("%s: Skipping cell %s,%s,%s at index %s!" % [name, x, y, z, index])
					continue
				
				if genGridCells:
					gridCell = GridCell.new(x, y, z)
					for i in 8:
						gridCell.value[i] = settings.noiseFunc.call((gridCell.pos as Vector3) + pos + LookupTable.CornerOffsets[i])
					gridCells[index] = gridCell
				else:
					gridCell = gridCells[index]
				
				var triCount := polygoniseCube(gridCell, settings.isoLevel, polys, settings.smoothMesh, settings.smoothNormals)
				if triCount == 0:
					continue
				
				triangles.resize(totalTriCount + triCount)
				for i in triCount:
					triangles[totalTriCount + i] = polys[i]
					var colorIndex := (y + size.y) / 2. / size.y
					#var colorIndex := (y + size.z) / (size.y + size.z)
					var color := settings.gradient.sample(colorIndex)
					triangles[totalTriCount + i].color[0] = color
					triangles[totalTriCount + i].color[1] = color
					triangles[totalTriCount + i].color[2] = color
				totalTriCount += triCount
	if pos == Vector3.ZERO:
		print("%s: Marching %s took %s milliseconds" % [name, pos, (Time.get_ticks_msec() - timeNow)])
	
	surfaceTool.clear()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
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
	
	#surfaceTool.index()
	var mesh = surfaceTool.commit()
	if pos == Vector3.ZERO:
		print("%s: Mesh gen for %s took %s milliseconds" % [name, pos, (Time.get_ticks_msec() - timeNow)])
	return {
		"mesh" = mesh,
		"gridCells" = gridCells,
		"triCount" = totalTriCount
	}

# Given a grid cell and an isoLevel, calcularte the triangular facets requied to represent the isosurface through the cell.
# Return the number of triangular facets, array "triangles" will be loaded up with the vertices at most 5 triangular facets.
# 0 will be returned if the grid cell is eiter totally above or below the isoLevel
func polygoniseCube(grid: GridCell, iso: float, triangles: Array[Triangle], smoothMesh: bool, smoothNormals: bool) -> int:
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
	
	if cubeIndex == 0 || cubeIndex == 255:
		return 0
	
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
		var gridPos := grid.pos as Vector3
		if smoothMesh:
			triangles[triCount].vertices[0] = vertexInterp(iso, LookupTable.CornerOffsets[e00], LookupTable.CornerOffsets[e01], grid.value[e00], grid.value[e01]) + gridPos
			triangles[triCount].vertices[1] = vertexInterp(iso, LookupTable.CornerOffsets[e10], LookupTable.CornerOffsets[e11], grid.value[e10], grid.value[e11]) + gridPos
			triangles[triCount].vertices[2] = vertexInterp(iso, LookupTable.CornerOffsets[e20], LookupTable.CornerOffsets[e21], grid.value[e20], grid.value[e21]) + gridPos
		else:
			triangles[triCount].vertices[0] = (LookupTable.CornerOffsets[e00] + LookupTable.CornerOffsets[e01]) / 2. + gridPos
			triangles[triCount].vertices[1] = (LookupTable.CornerOffsets[e10] + LookupTable.CornerOffsets[e11]) / 2. + gridPos
			triangles[triCount].vertices[2] = (LookupTable.CornerOffsets[e20] + LookupTable.CornerOffsets[e21]) / 2. + gridPos
		
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
