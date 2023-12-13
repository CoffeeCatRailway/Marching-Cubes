class_name LodChunk extends MeshInstance3D
## Based on https://github.com/Chevifier/Inifinte-Terrain-Generation

var chunkSize := 200 # @export_range(1, 400, 1) 
var resolution := 30 # @export_range(1, 100, 1) 
const lods: Array[int] = [2, 4, 8, 16, 30]#[2, 4, 8, 16, 30, 60]
const lodDistance: Array[int] = [1750, 1500, 1100, 750, 500]#[2000, 1750, 1500, 1200, 750, 500] # Tweak distances

@export var material: Material

const CENTER_OFFSET := Vector3.ONE / 2.#Vector3(.5, .5, .5)
var chunkCoord := Vector3i.ZERO
var chunkData: Array = []
var generateCollision = false

const colors := [Color.WHITE, Color.YELLOW, Color.ORANGE, Color.ORANGE_RED, Color.RED]
var color := Color.WHITE
var vertexColMat: StandardMaterial3D

func setup(pos: Vector3, _chunkCoord: Vector3i, _chunkSize: int) -> void:
	position = pos
	chunkSize = _chunkSize
	chunkCoord = _chunkCoord
	
	vertexColMat = StandardMaterial3D.new()
	vertexColMat.vertex_color_use_as_albedo = true
	
	chunkData.resize(1)
	chunkData[0] = []
	
	WorldSaver.addChunk(chunkCoord)
	save()

func updateChunk(viewerPosition: Vector3, viewDistance) -> void:
	pass

func horizontalDistanceToChunk(viewerPosition: Vector3) -> float:
	return Vector2(position.x, position.z).distance_to(Vector2(viewerPosition.x, viewerPosition.z))

func updateLod(viewerPosition: Vector3) -> bool:
	var dist = horizontalDistanceToChunk(viewerPosition)
	var newLod := lods[0]
	var newColor := color
	if lods.size() != lodDistance.size():
		print("ERROR: Lods and distance count mismatch")
		return false
	
	for i in lods.size():
		var lodDist = lodDistance[i]
		if dist < lodDist:
			newLod = lods[i]
			newColor = colors[i]
	
	# If chunk is at highest resolution create collision shape
	generateCollision = newLod >= lods[lods.size() - 1]
	
	# If resolution is not equal to new resolution, return true
	if resolution != newLod:
		resolution = newLod
		color = newColor
		return true
	return false

func generateChunk(marcherSettings: MarcherSettings) -> void:
	var polys: Array[Marcher.Triangle] = []
	polys.resize(10)
	
	var isMaxResolution := resolution >= lods[lods.size() - 1]
	var gridCells: Array = []
	if isMaxResolution:
		gridCells = WorldSaver.retriveData(chunkCoord)[0]#chunkData[0]
	
	var shouldGenCells := gridCells.size() == 0
	if shouldGenCells && isMaxResolution:
		gridCells.resize(resolution * resolution * resolution)
	
	var arrMesh: ArrayMesh
	var surfaceTool := SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	surfaceTool.set_color(color)
	
	#var totalTriCount := 0
	#var minVal := 0.
	#var maxVal := 0.
	
	# When loading 'modified' terrain, only use chunkData for highest resolution
	# Regenerate mesh for low-resolution chunks
	for x in resolution:
		for y in resolution:
			for z in resolution:
				# Get the percentage of the currnet point
				var percent := Vector3(x, y, z) / resolution - CENTER_OFFSET
				var vertex := Vector3(percent.x, percent.y, percent.z) * chunkSize
				
				var gridCell: Marcher.GridCell
				var gcIndex = z * resolution * resolution + y * resolution + x
				if isMaxResolution && gcIndex > gridCells.size():
					push_warning("%s: Skipping cell %s,%s,%s at index %s!" % [name, x, y, z, gcIndex])
					continue
				
				if shouldGenCells:
					gridCell = Marcher.GridCell.new(vertex.x, vertex.y, vertex.z)
					for i in 8:
						gridCell.value[i] = marcherSettings.noiseFunc.call(position + vertex + LookupTable.CornerOffsets[i] / resolution * chunkSize, marcherSettings)
					if isMaxResolution:
						gridCells[gcIndex] = gridCell
				elif isMaxResolution:
					gridCell = gridCells[gcIndex]
				
				#var gridCell := Marcher.GridCell.new(vertex.x, vertex.y, vertex.z)
				#for i in 8:
				#	gridCell.value[i] = marcherSettings.noiseFunc.call(position + vertex + LookupTable.CornerOffsets[i] / resolution * chunkSize, marcherSettings)
					#minVal = minf(minVal, gridCell.value[i])
					#maxVal = maxf(maxVal, gridCell.value[i])
				
				var triCount := Marcher.polygoniseCube(gridCell, marcherSettings, polys, float(chunkSize) / float(resolution))
				if triCount == 0:
					continue
				
				for tri in polys:
					if tri == null:
						continue
					
					surfaceTool.set_normal(tri.normal[2])
					surfaceTool.add_vertex(tri.vertices[2])
					
					surfaceTool.set_normal(tri.normal[1])
					surfaceTool.add_vertex(tri.vertices[1])
					
					surfaceTool.set_normal(tri.normal[0])
					surfaceTool.add_vertex(tri.vertices[0])
					#totalTriCount += 1
	#print("Triangles: %s" % totalTriCount)
	#print("Min: %s, Max: %s" % [minVal, maxVal])
	
	#var vert = 0
	#for x in resolution:
	#	for y in resolution:
	#		for z in resolution:
	#			surfaceTool.add_index(vert)
	#			surfaceTool.add_index(vert + 1)
	#			surfaceTool.add_index(vert + resolution + 1)
	#			
	#			surfaceTool.add_index(vert + resolution + 1)
	#			surfaceTool.add_index(vert + 1)
	#			surfaceTool.add_index(vert + resolution + 2)
	#			
	#			surfaceTool.add_index(vert + resolution + 2)
	#			surfaceTool.add_index(vert + 3)
	#			surfaceTool.add_index(vert)
	#			vert += 1
	#		vert += 1
	#	vert += 1
	
	if isMaxResolution:
		chunkData[0] = gridCells
		save()
	
	surfaceTool.index()
	arrMesh = surfaceTool.commit()
	
	mesh = arrMesh
	if mesh.get_surface_count() > 0:
		#mesh.surface_set_material(0, material)
		mesh.surface_set_material(0, vertexColMat)
	
	if generateCollision:
		$StaticBody3D/CollisionShape3D.shape = arrMesh.create_trimesh_shape()

func save() -> void:
	WorldSaver.saveChunk(chunkCoord, chunkData)

func saveAndFree() -> void:
	save()
	queue_free()




