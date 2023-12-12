#@tool
class_name LodChunk extends MeshInstance3D
## Based on https://github.com/Chevifier/Inifinte-Terrain-Generation

#@export var generate := false:
#	set(value):
#		if value:
#			generate = false
#			generateChunk(Vector3i.ZERO, chunkSize, marcherSettings)

var chunkSize := 200 # @export_range(1, 400, 1) 
var resolution := 20 # @export_range(1, 100, 1) 
var lods: Array[int] = [2, 4, 8, 16]#[2, 4, 8, 16, 30, 60]
var lodDistance: Array[int] = [1050, 900, 790, 550]#[2000, 1500, 1050, 900, 790, 550] # Tweak distances

#@export var marcherSettings: MarcherSettings
@export var material: Material

const CENTER_OFFSET := Vector3(.5, .5, .5)
var chunkCoord := Vector3i()
var chunkData: Array = []
var generateCollision = false

#func _ready() -> void:
	#marcherSettings.noiseFunc = noiseFunc

func setup(pos: Vector3, _chunkCoord: Vector3i, _chunkSize: int) -> void:
	position = pos
	chunkSize = _chunkSize
	chunkCoord = _chunkCoord
	WorldSaver.addChunk(chunkCoord)

func updateChunk(viewerPosition: Vector3, viewDistance) -> void:
	pass

func distanceToChunk(viewerPosition: Vector3) -> float:
	return Vector2(position.x, position.z).distance_to(Vector2(viewerPosition.x, viewerPosition.z))

func updateLod(viewerPosition: Vector3) -> bool:
	var dist = distanceToChunk(viewerPosition)
	var newLod = lods[0]
	if lods.size() != lodDistance.size():
		print("ERROR: Lods and distance count mismatch")
		return false
	
	for i in lods.size():
		var lodDist = lodDistance[i]
		if dist < lodDist:
			newLod = lods[i]
	
	# If chunk is at highest resolution create collision shape
	generateCollision = newLod >= lods[lods.size() - 1]
	
	# If resolution is not equal to new resolution, return true
	if resolution != newLod:
		resolution = newLod
		return true
	return false

func generateChunk(marcherSettings: MarcherSettings) -> void:
	var polys: Array[Marcher.Triangle] = []
	polys.resize(10)
	
	var arrMesh: ArrayMesh
	var surfaceTool := SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	#var totalTriCount := 0
	#var minVal := 0.
	#var maxVal := 0.
	
	for x in resolution:
		for y in resolution:
			for z in resolution:
				# Get the percentage of the currnet point
				var percent := Vector3(x, y, z) / resolution - CENTER_OFFSET
				var vertex := Vector3(percent.x, percent.y, percent.z) * chunkSize
				
				var gridCell := Marcher.GridCell.new(vertex.x, vertex.y, vertex.z)
				for i in 8:
					gridCell.value[i] = marcherSettings.noiseFunc.call(position + vertex + LookupTable.CornerOffsets[i] / resolution * chunkSize, marcherSettings)
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
	
	surfaceTool.index()
	arrMesh = surfaceTool.commit()
	mesh = arrMesh
	mesh.surface_set_material(0, material)
	if generateCollision:
		$StaticBody3D/CollisionShape3D.shape = arrMesh.create_trimesh_shape()

func save() -> void:
	WorldSaver.saveChunk(chunkCoord, chunkData)
	queue_free()




