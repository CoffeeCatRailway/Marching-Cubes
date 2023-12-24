@tool
extends Node

const vertexColMat: StandardMaterial3D = preload("res://materials/vertex_color_mat.tres")

class GridCell:
	var pos: Vector3
	var value: Array[float]
	
	func _init(x: float = 0., y: float = 0., z: float = 0., _value: Array[float] = [0., 0., 0., 0., 0., 0., 0., 0.]):
		pos = Vector3(x, y, z)
		value = _value

class Triangle:
	var vertices: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	var normal: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	var color: Array[Color] = [Color.DIM_GRAY, Color.DIM_GRAY, Color.DIM_GRAY]

func march(pos: Vector3, size: Vector3i, marcherSettings: MarcherSettings, gridCells: Array[GridCell] = []) -> Dictionary:
	var timeNow: int
	if pos == Vector3.ZERO:
		timeNow = Time.get_ticks_msec()
		
	var surfaceTool := SurfaceTool.new()
	
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
						gridCell.value[i] = marcherSettings.noiseFunc.call(gridCell.pos + pos + LookupTable.CornerOffsets[i])
					gridCells[index] = gridCell
				else:
					gridCell = gridCells[index]
				
				var triCount := polygoniseCube(gridCell, marcherSettings, polys)
				if triCount == 0:
					continue
				
				triangles.resize(totalTriCount + triCount)
				for i in triCount:
					triangles[totalTriCount + i] = polys[i]
					var colorIndex := (y + size.y) / 2. / size.y
					#var colorIndex := (y + size.z) / (size.y + size.z)
					var color := marcherSettings.gradient.sample(colorIndex)
					triangles[totalTriCount + i].color[0] = color
					triangles[totalTriCount + i].color[1] = color
					triangles[totalTriCount + i].color[2] = color
				totalTriCount += triCount
	if pos == Vector3.ZERO:
		print("%s: Marching %s took %s milliseconds" % [name, pos, (Time.get_ticks_msec() - timeNow)])
	
	surfaceTool.clear()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	surfaceTool.set_material(vertexColMat)
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
func polygoniseCube(gridCell: GridCell, marcherSettings: MarcherSettings, triangles: Array[Triangle], resolustion: float = 1.) -> int:
	# Determine the index into the edge table which tells us which vertices are inside of the surface
	var cubeIndex: int = 0
	if gridCell.value[0] < marcherSettings.isoLevel: cubeIndex |= 1
	if gridCell.value[1] < marcherSettings.isoLevel: cubeIndex |= 2
	if gridCell.value[2] < marcherSettings.isoLevel: cubeIndex |= 4
	if gridCell.value[3] < marcherSettings.isoLevel: cubeIndex |= 8
	if gridCell.value[4] < marcherSettings.isoLevel: cubeIndex |= 16
	if gridCell.value[5] < marcherSettings.isoLevel: cubeIndex |= 32
	if gridCell.value[6] < marcherSettings.isoLevel: cubeIndex |= 64
	if gridCell.value[7] < marcherSettings.isoLevel: cubeIndex |= 128
	
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
		if marcherSettings.smoothMesh:
			triangles[triCount].vertices[0] = vertexInterp(marcherSettings.isoLevel, LookupTable.CornerOffsets[e00] * resolustion, LookupTable.CornerOffsets[e01] * resolustion, gridCell.value[e00], gridCell.value[e01]) + gridCell.pos
			triangles[triCount].vertices[1] = vertexInterp(marcherSettings.isoLevel, LookupTable.CornerOffsets[e10] * resolustion, LookupTable.CornerOffsets[e11] * resolustion, gridCell.value[e10], gridCell.value[e11]) + gridCell.pos
			triangles[triCount].vertices[2] = vertexInterp(marcherSettings.isoLevel, LookupTable.CornerOffsets[e20] * resolustion, LookupTable.CornerOffsets[e21] * resolustion, gridCell.value[e20], gridCell.value[e21]) + gridCell.pos
		else:
			triangles[triCount].vertices[0] = (LookupTable.CornerOffsets[e00] * resolustion + LookupTable.CornerOffsets[e01] * resolustion) / 2. + gridCell.pos
			triangles[triCount].vertices[1] = (LookupTable.CornerOffsets[e10] * resolustion + LookupTable.CornerOffsets[e11] * resolustion) / 2. + gridCell.pos
			triangles[triCount].vertices[2] = (LookupTable.CornerOffsets[e20] * resolustion + LookupTable.CornerOffsets[e21] * resolustion) / 2. + gridCell.pos
		
		if marcherSettings.smoothNormals:
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
