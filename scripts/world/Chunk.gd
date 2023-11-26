class_name Chunk
extends Node3D

var chunkCoord: Vector3i
var chunkData: Array = []

func setup(generateCollisionShape: bool, _chunkCoord: Vector3i, chunkSize: Vector2, marcherSettings: MarcherSettings) -> void:
	chunkCoord = _chunkCoord
	var meshInstance: MeshInstance3D = $MeshInstance3D
	var collisionShape: CollisionShape3D = $MeshInstance3D/StaticBody3D/CollisionShape3D
	
	if WorldSaver.loadedChunks.find(chunkCoord) == -1: # Initialize chunk if new
		var timeNow := Time.get_ticks_msec()
		chunkData.resize(2)
		
		# Generate mesh
		meshInstance.mesh = Marcher.march(position, chunkSize, marcherSettings)
		chunkData[0] = meshInstance.mesh
		
		# Generate collision shape
		if generateCollisionShape && meshInstance.mesh != null:
			collisionShape.shape = meshInstance.mesh.create_trimesh_shape()
			chunkData[1] = collisionShape.shape
		WorldSaver.addChunk(chunkCoord)
		print("%s: Generating chunk %s took %s miliseconds" % [name, chunkCoord, (Time.get_ticks_msec() - timeNow)])
	else: # Load chunk if already generated
		chunkData = WorldSaver.retriveData(chunkCoord)
		meshInstance.mesh = chunkData[0]
		collisionShape.shape = chunkData[1]
		#print("%s: %s loaded" % [name, chunkCoord])
	

func save() -> void:
	WorldSaver.saveChunk(chunkCoord, chunkData)
	queue_free()
