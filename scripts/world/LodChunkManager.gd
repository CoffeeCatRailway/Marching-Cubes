class_name LodChunkManager extends Node3D
## Chunk loading system based on https://github.com/Chevifier/Inifinte-Terrain-Generation/blob/main/EndlessTerrain/EndlessTerrain.gd

const chunkScene := preload("res://scenes/lod_chunk.tscn")

@export var disabled := false

@export var seed: String = "0"
@export_range(1, 400, 1) var chunkSize := 200
@export_range(100, 2000, 100) var viewDistance := 2000
@export var marcherSettings: MarcherSettings

@export var viewer: CharacterBody3D

var chunksVisible := 0
var currentChunkPos := Vector3i.ZERO
var previousChunkPos := Vector3i.ZERO
var chunkLoaded := false

@onready var activeCoords: Array[Vector3i] = []
@onready var activeChunks: Array[LodChunk] = []

var mutex: Mutex
var semaphore: Semaphore
var thread: Thread # Make thread always running in background with queue of chunks to load
var exitThread := false

func _ready() -> void:
	if disabled:
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	
	mutex = Mutex.new()
	semaphore = Semaphore.new()
	thread = Thread.new()
	
	var worldSeed = marcherSettings.randomiseNoise(seed)
	print("%s: Seed: %s" % [name, worldSeed])
	marcherSettings.noiseFunc = noiseFunc
	
	# Set the total chunks to be visible
	chunksVisible = roundi(viewDistance / chunkSize)
	print("%s: Chunks visible: %s" % [name, chunksVisible])
	
	currentChunkPos = _getPlayerChunk(viewer.global_position)
	#updateVisibleChunks()
	
	thread.start(chunkThreadProcess)
	semaphore.post()

func noiseFunc(pos: Vector3, marcherSettings: MarcherSettings) -> float:
	if pos.y <= -(chunkSize / 2.):
		return 0.;
	var noiseVal: float = -pos.y
	noiseVal += marcherSettings.noiseBase.get_noise_3dv(pos) * marcherSettings.baseMul
	#noiseVal += marcherSettings.noiseMask.get_noise_3dv(pos) * marcherSettings.maskMul
	noiseVal += maxf(marcherSettings.minMaskHeight, marcherSettings.noiseMask.get_noise_3dv(pos)) * marcherSettings.maskMul
	
	noiseVal /= (marcherSettings.baseMul + marcherSettings.maskMul) # Bring values closer to -1 to 1
	
	var tunnel := marcherSettings.noiseTunnel.get_noise_3dv(pos) * marcherSettings.tunnelMul
	if tunnel < 0. && noiseVal >= marcherSettings.tunnelSurfacing:
		noiseVal *= tunnel
	return snappedf(noiseVal, .001)

func chunkThreadProcess() -> void:
	Thread.set_thread_safety_checks_enabled(false)
	while true:
		semaphore.wait() # Wait until posted
		
		mutex.lock()
		var shouldExit = exitThread
		mutex.unlock()
		
		if shouldExit:
			break
		
		## DO SHIT!
		updateVisibleChunks()

func _process(delta) -> void:
	if disabled:
		return
	
	mutex.lock()
	currentChunkPos = _getPlayerChunk(viewer.global_position)
	
	if previousChunkPos != currentChunkPos:
		if !chunkLoaded:
			#updateVisibleChunks()
			semaphore.post()
	else:
		chunkLoaded = false
	mutex.unlock()
	
	if Input.is_action_just_released("ui_page_down") && WorldSaver.retriveData(Vector3i.ZERO).size() > 0:
		var data: Array[Marcher.GridCell] = WorldSaver.retriveData(Vector3i.ZERO)[0]
		var file = FileAccess.open("user://Chunk000.gd", FileAccess.WRITE)
		file.store_line("extends Node")
		file.store_string("var data: Array[Marcher.GridCell] = [")
		for i in data.size():
			var cell := data[i]
			file.store_string("Marcher.GridCell.new(%s,%s,%s,%s)" % [cell.pos.x, cell.pos.y, cell.pos.z, cell.value])
			if i == data.size() - 1:
				file.store_string("]")
			else:
				file.store_string(",\n")
		file.close()
		print("%s: Exported chunk 0,0,0 data" % name)
	
	previousChunkPos = currentChunkPos

# Convert player position to chunk position
func _getPlayerChunk(pos: Vector3) -> Vector3i:
	var chunkPos := Vector3i.ZERO
	chunkPos.x = int(pos.x / chunkSize)
	chunkPos.z = int(pos.z / chunkSize)
	if pos.x < 0.:
		chunkPos.x -= 1
	if pos.z < 0.:
		chunkPos.z -= 1
	return chunkPos

func loadChunk(chunkCoords: Vector3i) -> void:
	# 'loadingCoord' stores the coords that are in the new chunk(s)
	# make sure only inactive coords are loaded
	var chunkIndex := activeCoords.find(chunkCoords)
	if chunkIndex == -1:
		var chunk = chunkScene.instantiate()
		var pos := chunkCoords * chunkSize
		chunk.setup(Vector3(pos.x, 0., pos.z), chunkCoords, chunkSize)
		chunk.updateLod(viewer.global_position)
		chunk.generateChunk(marcherSettings)
		activeChunks.append(chunk)
		activeCoords.append(chunkCoords)
		#add_child(chunk)
		call_deferred("add_child", chunk)
	else:
		var chunk := activeChunks[chunkIndex]
		#chunk.updateChunk(viewer.global_position, viewDistance)
		if chunk.updateLod(viewer.global_position):
			chunk.generateChunk(marcherSettings)

func updateVisibleChunks() -> void:
	var timeNow := Time.get_ticks_msec()
	var loadingCoord: Array[Vector3i] = [currentChunkPos]
	
	loadChunk(currentChunkPos)
	
	for xd in range(-chunksVisible + 1, chunksVisible):
		#mutex.lock()
		#var shouldExit = exitThread
		#mutex.unlock()
		
		#if shouldExit:
		#	break
		
		for zd in range(-chunksVisible + 1, chunksVisible):
			if xd == 0 && zd == 0:
				continue
			
			var chunkCoords := Vector3i(currentChunkPos.x + xd, 0, currentChunkPos.z + zd)
			loadingCoord.append(chunkCoords)
			loadChunk(chunkCoords)
	
	# Delete inactive (out of render distance) chunks
	var deletingChunks = []
	for dx in activeCoords:
		if loadingCoord.find(dx) == -1:
			deletingChunks.append(dx)
	for dx in deletingChunks:
		var i = activeCoords.find(dx)
		activeChunks[i].saveAndFree()
		activeChunks.remove_at(i)
		activeCoords.remove_at(i)
	
	mutex.lock()
	chunkLoaded = true
	mutex.unlock()
	
	print("%s: Loading chunks around %s took %s milliseconds" % [name, currentChunkPos, (Time.get_ticks_msec() - timeNow)])

func _exit_tree() -> void:
	if disabled:
		return
	
	# Set thread exit condition
	mutex.lock()
	exitThread = true
	mutex.unlock()
	
	# Unblock by posting
	semaphore.post()
	
	print(name, ": Stopping chunk thread!")
	
	# Wait for thread to finish
	thread.wait_to_finish()

















