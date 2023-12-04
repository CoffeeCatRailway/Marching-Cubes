class_name Chunk
extends Node3D

var chunkCoord: Vector3i
var chunkData: Array = []

func setup(generateCollisionShape: bool, chunkPos: Vector3, _chunkCoord: Vector3i, chunkSize: Vector3i, marcherSettings: MarcherSettings) -> void:
	chunkCoord = _chunkCoord
	var meshInstance: MeshInstance3D = $MeshInstance3D
	var collisionShape: CollisionShape3D = $MeshInstance3D/StaticBody3D/CollisionShape3D
	
	if WorldSaver.loadedChunks.find(chunkCoord) == -1: # Initialize chunk if new
		var timeNow := Time.get_ticks_msec()
		chunkData.resize(3)
		
		# Generate mesh
		var marched := Marcher.march(chunkPos, chunkSize, marcherSettings)#, Chunk000.data)
		meshInstance.mesh = marched["mesh"]
		chunkData[0] = meshInstance.mesh
		#chunkData[2] = marched["gridCells"]
		
		#if chunkCoord == Vector3i.ZERO && true:
		#	var data: Array[Marcher.GridCell] = chunkData[2]
		#	var file = FileAccess.open("user://Chunk000.gd", FileAccess.WRITE)
		#	file.store_line("extends Node")
		#	file.store_string("var data: Array[Marcher.GridCell] = [")
		#	for i in data.size():
		#		var cell := data[i]
		#		file.store_string("Marcher.GridCell.new(%s,%s,%s,%s)" % [cell.pos.x, cell.pos.y, cell.pos.z, cell.value])
		#		if i == data.size() - 1:
		#			file.store_string("]")
		#		else:
		#			file.store_string(",\n")
		#	file.close()
		
		# Generate collision shape
		if generateCollisionShape && meshInstance.mesh != null:
			collisionShape.shape = meshInstance.mesh.create_trimesh_shape()
			chunkData[1] = collisionShape.shape
		WorldSaver.addChunk(chunkCoord)
		print("%s: Generating chunk %s took %s milliseconds" % [name, chunkCoord, (Time.get_ticks_msec() - timeNow)])
	else: # Load chunk if already generated
		chunkData = WorldSaver.retriveData(chunkCoord)
		#var marched := Marcher.march(chunkPos, chunkSize, marcherSettings, chunkData[2])
		#meshInstance.mesh = marched["mesh"]
		meshInstance.mesh = chunkData[0]
		collisionShape.shape = chunkData[1]
		print("%s: %s loaded" % [name, chunkCoord])
	

func save() -> void:
	WorldSaver.saveChunk(chunkCoord, chunkData)
	queue_free()
