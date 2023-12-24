class_name LodRSChunk
## Based on https://github.com/Chevifier/Inifinte-Terrain-Generation

## Resolution
var chunkSize := 200 # @export_range(1, 400, 1) 
var resolution := 30 # @export_range(1, 100, 1) 
const lods: Array[int] = [2, 4, 8, 16, 30]#[2, 4, 8, 16, 30, 60]
const lodDistance: Array[int] = [1750, 1500, 1100, 750, 400]#[2000, 1750, 1500, 1200, 750, 500] # Tweak distances

var marcherSettings: MarcherSettings
var material: Material

## Position
const OFFSET := Vector3(0., .5, 0.)#Vector3.ONE / 2.
var chunkPos := Vector3.ZERO
var transform := Transform3D()
var chunkCoord := Vector3i.ZERO
var chunkData: Array = []

## RIDS
var instance: RID
var meshInstance: RID
var collisionBody: RID
var meshData = []
var mesh: ArrayMesh

var renderServer := RenderingServer
var physicsServer := PhysicsServer3D
var scenario: RID
var space: RID
var mutex := Mutex.new()

## Collision
var collisionShape: ConcavePolygonShape3D
var shouldGenerateCollision := false

## Debug
static var DEBUG_COLOR := false
const colors := [Color.WHITE, Color.YELLOW, Color.ORANGE, Color.ORANGE_RED, Color.RED]
var color := Color.WHITE
const vertexColMat: StandardMaterial3D = preload("res://materials/vertex_color_mat.tres")

func _init(_material: Material, _marcherSettings: MarcherSettings, _scenario: RID, _space: RID):
	material = _material
	marcherSettings = _marcherSettings
	scenario = _scenario
	space = _space

func setup(_chunkPos: Vector3, _chunkCoord: Vector3i, _chunkSize: int) -> void:
	chunkPos = _chunkPos
	chunkCoord = _chunkCoord
	chunkSize = _chunkSize
	
	chunkData.resize(1)
	var emptyGridArray: Array[Marcher.GridCell] = [] # Set type or shit gets angry
	chunkData[0] = emptyGridArray
	
	WorldSaver.addChunk(chunkCoord)
	save()

func horizontalDistanceToChunk(viewerPosition: Vector3) -> float:
	return Vector2(chunkPos.x, chunkPos.z).distance_to(Vector2(viewerPosition.x, viewerPosition.z))

func updateLod(viewerPosition: Vector3) -> bool:
	var dist = horizontalDistanceToChunk(viewerPosition)
	var newLod := lods[0]
	var newColor := colors[0]
	if lods.size() != lodDistance.size():
		print("ERROR: Lods and distance count mismatch")
		return false
	
	for i in lods.size():
		var lodDist = lodDistance[i]
		if dist < lodDist:
			newLod = lods[i]
			if DEBUG_COLOR:
				newColor = colors[i]
	
	# If chunk is at highest resolution create collision shape
	shouldGenerateCollision = newLod >= lods[lods.size() - 1]
	
	# If resolution is not equal to new resolution, return true
	if resolution != newLod:
		resolution = newLod
		if DEBUG_COLOR:
			color = newColor
		return true
	return false

func getGridCellAtPos(pos: Vector3) -> int:
	var meshPos = pos# / chunkSize
	#meshPos += CENTER_OFFSET
	#meshPos *= resolution
	var gcIndex = meshPos.z * resolution * resolution + meshPos.y * resolution + meshPos.x
	if gcIndex < chunkData[0].size():
		return gcIndex
	return -1

func generateChunk() -> void:
	mutex.lock()
	var polys: Array[Marcher.Triangle] = []
	polys.resize(10)
	
	var shouldSave := resolution >= lods[lods.size() - 1]
	var gridCells: Array[Marcher.GridCell] = []
	if shouldSave:
		gridCells = WorldSaver.retriveData(chunkCoord)[0]#chunkData[0]
	
	var shouldGenCells := gridCells.size() == 0
	if shouldGenCells && shouldSave:
		gridCells.resize(resolution * resolution * resolution)
	
	var lastInstance: RID
	var surfaceTool := SurfaceTool.new()
	
	if instance:
		lastInstance = instance
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	if DEBUG_COLOR:
		surfaceTool.set_color(color)
	
	#var totalTriCount := 0
	
	# When loading 'modified' terrain, only use chunkData for highest resolution
	# Regenerate mesh for low-resolution chunks
	for x in resolution:
		for y in resolution:
			for z in resolution:
				# Get the percentage of the currnet point
				var percent := Vector3(x, y, z) / resolution - OFFSET
				var vertex := Vector3(percent.x, percent.y, percent.z) * chunkSize
				
				var gridCell: Marcher.GridCell
				var gcIndex = z * resolution * resolution + y * resolution + x
				if shouldSave && gcIndex >= gridCells.size():
					push_warning("Chunk%s: Skipping cell %s,%s,%s at index %s!" % [chunkCoord, x, y, z, gcIndex])
					continue
				
				if shouldGenCells:
					gridCell = Marcher.GridCell.new(vertex.x, vertex.y, vertex.z)
					for i in 8:
						gridCell.value[i] = marcherSettings.noiseFunc.call(chunkPos + vertex + LookupTable.CornerOffsets[i] / resolution * chunkSize, marcherSettings)
					if shouldSave:
						gridCells[gcIndex] = gridCell
				elif shouldSave:
					gridCell = gridCells[gcIndex]
				
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
	
	if shouldSave:
		chunkData[0] = gridCells
		save()
	
	#surfaceTool.index()
	meshData = surfaceTool.commit_to_arrays()
	
	instance = renderServer.instance_create()
	meshInstance = renderServer.mesh_create()
	renderServer.instance_set_base(instance, meshInstance)
	renderServer.instance_set_scenario(instance, scenario)
	transform.origin = chunkPos
	renderServer.instance_set_transform(instance, transform)
	renderServer.mesh_add_surface_from_arrays(meshInstance, RenderingServer.PRIMITIVE_TRIANGLES, meshData)
	if DEBUG_COLOR:
		renderServer.mesh_surface_set_material(meshInstance, 0, vertexColMat)
	else:
		renderServer.mesh_surface_set_material(meshInstance, 0, material)
	
	mutex.unlock()
	
	if lastInstance:
		renderServer.free_rid(lastInstance)
	if shouldGenerateCollision:
		generateCollision()
	#else:
	#	clearCollision()

func generateCollision() -> void:
	clearCollision()
	collisionBody = physicsServer.body_create()
	physicsServer.body_set_space(collisionBody, space)
	physicsServer.body_set_mode(collisionBody, PhysicsServer3D.BODY_MODE_STATIC)
	physicsServer.body_set_collision_layer(collisionBody, 0b1)
	physicsServer.body_set_collision_mask(collisionBody, 0b1)
	physicsServer.body_set_state(collisionBody, PhysicsServer3D.BODY_STATE_TRANSFORM, transform)
	
	mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, meshData)
	collisionShape = mesh.create_trimesh_shape()
	physicsServer.body_add_shape(collisionBody, collisionShape, Transform3D.IDENTITY)

func clearCollision() -> void:
	if collisionBody:
		physicsServer.free_rid(collisionBody)

func save() -> void:
	WorldSaver.saveChunk(chunkCoord, chunkData)

func saveAndFree() -> void:
	save()
	
	if instance:
		renderServer.free_rid(instance)
	if meshInstance:
		renderServer.free_rid(meshInstance)
	
	#free()







