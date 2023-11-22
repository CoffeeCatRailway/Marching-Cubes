class_name Chunk
extends Node3D

var chunkCoord: Vector3i
var chunkData: Array = []

func setup(generateCollisionShape: bool, _chunkCoord: Vector3i) -> void:
	chunkCoord = _chunkCoord
	var meshInstance: MeshInstance3D = $MeshInstance3D
	var collisionShape: CollisionShape3D = $MeshInstance3D/StaticBody3D/CollisionShape3D
	
	if WorldSaver.loadedChunks.find(chunkCoord) == -1: # Initialize chunk if new
		chunkData.resize(2)
		
		# Generate mesh
		meshInstance.mesh = BoxMesh.new()
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(randf_range(.3, 1.), randf_range(.3, 1.), randf_range(.3, 1.))
		(meshInstance.mesh as BoxMesh).material = mat
		chunkData[0] = meshInstance.mesh
		
		# Generate collision shape
		if generateCollisionShape && meshInstance.mesh != null:
			collisionShape.shape = meshInstance.mesh.create_trimesh_shape()
			chunkData[1] = collisionShape.shape
		WorldSaver.addChunk(chunkCoord)
	else: # Load chunk if already generated
		chunkData = WorldSaver.retriveData(chunkCoord)
		meshInstance.mesh = chunkData[0]
		collisionShape.shape = chunkData[1]
	

func save() -> void:
	WorldSaver.saveChunk(chunkCoord, chunkData)
	queue_free()
