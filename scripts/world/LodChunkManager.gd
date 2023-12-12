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

func _ready() -> void:
	if disabled:
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	
	var worldSeed = marcherSettings.randomiseNoise(seed)
	print("%s: Seed: %s" % [name, worldSeed])
	marcherSettings.noiseFunc = noiseFunc
	
	# Set the total chunks to be visible
	chunksVisible = roundi(viewDistance / chunkSize)
	print("%s: Chunks visible: %s" % [name, chunksVisible])
	
	currentChunkPos = _getPlayerChunk(viewer.global_position)
	updateVisibleChunks()

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

func _process(delta) -> void:
	if disabled:
		return
	
	currentChunkPos = _getPlayerChunk(viewer.global_position)
	
	if previousChunkPos != currentChunkPos:
		if !chunkLoaded:
			updateVisibleChunks()
	else:
		chunkLoaded = false
	
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

func updateVisibleChunks() -> void:
	var timeNow := Time.get_ticks_msec()
	var loadingCoord: Array[Vector3i] = []
	
	for xd in range(-chunksVisible + 1, chunksVisible):
		for zd in range(-chunksVisible + 1, chunksVisible):
			var chunkCoords := Vector3i(currentChunkPos.x + xd, 0, currentChunkPos.z + zd)
			loadingCoord.append(chunkCoords)
			
			# 'loadingCoord' stores the coords that are in the new chunk(s)
			# make sure only inactive coords are loaded
			var chunkIndex := activeCoords.find(chunkCoords)
			if chunkIndex == -1:
				var chunk = chunkScene.instantiate()
				var chunkPos = Vector3(chunkCoords.x * chunkSize, 0., chunkCoords.z * chunkSize)
				var pos := chunkCoords * chunkSize
				chunk.setup(Vector3(pos.x, 0., pos.z), currentChunkPos, chunkSize)
				chunk.updateLod(viewer.global_position)
				chunk.generateChunk(marcherSettings)
				activeChunks.append(chunk)
				activeCoords.append(chunkCoords)
				add_child(chunk)
			else:
				var chunk := activeChunks[chunkIndex]
				#chunk.updateChunk(viewer.global_position, viewDistance)
				if chunk.updateLod(viewer.global_position):
					chunk.generateChunk(marcherSettings)
	
	# Delete inactive (out of render distance) chunks
	var deletingChunks = []
	for dx in activeCoords:
		if loadingCoord.find(dx) == -1:
			deletingChunks.append(dx)
	for dx in deletingChunks:
		var i = activeCoords.find(dx)
		activeChunks[i].save()
		activeChunks.remove_at(i)
		activeCoords.remove_at(i)
	
	chunkLoaded = true
	
	print("%s: Loading chunks around %s took %s milliseconds" % [name, currentChunkPos, (Time.get_ticks_msec() - timeNow)])

func _exit_tree() -> void:
	if disabled:
		return
	
	pass


















