class_name ChunkManager extends Node3D
## Chunk loading system based on https://github.com/NesiAwesomeneess/ChunkLoader/tree/main

# Each chunk has a parent node whish is 'chunk.tscn'
# Instanced for every chunk that hasn't been loaded
const chunkNode := preload("res://scenes/chunk.tscn")
@export_group("Noise settings")
@export var useRandomSeed: bool = false
@export var seed: String = "0"
@export var noiseMultiplier: float = 10.
@export var noiseMaskMultiplier: float = 20.
@export var noiseTunnelMultiplier: float = 2.
@export var noise: FastNoiseLite
@export var noiseMask: FastNoiseLite
@export var noiseTunnel: FastNoiseLite

@export_group("")
@export var disabled := false
@export var generateCollision := true
@export var marcherSettings: MarcherSettings

# Reference player to track location
@export_node_path() var playerPath
var player: Node

@export_range(2, 2, 1, "or_greater") var renderDistance: int = 3
@export var chunkSize: Vector3i = Vector3i(10., 60., 30.): # x: width & depth, yz: +height & -height
	set(value):
		chunkSize = value.abs()
var currentChunkPos := Vector3i.ZERO
var previousChunkPos := Vector3i.ZERO
var chunkLoaded := false

@onready var activeCoords: Array[Vector3i] = []
@onready var activeChunks: Array[Chunk] = []

var mutex: Mutex
var semaphore: Semaphore
var thread: Thread # Make thread always running in background with queue of chunks to load
var exitThread := false

var renderWireframe := false

# Checks if the chunks within the render distance have been loaded
func _ready() -> void:
	if disabled:
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	
	mutex = Mutex.new()
	semaphore = Semaphore.new()
	thread = Thread.new()
	
	randomiseNoise()
	marcherSettings.noiseFunc = noiseFunc#Callable(self, "noiseFunc")
	
	player = get_node(playerPath)
	currentChunkPos = _getPlayerChunk(player.global_position)
	
	thread.start(chunkThreadProcess)
	semaphore.post()

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
		loadChunks()

func loadChunks() -> void:
	var timeNow := Time.get_ticks_msec()
	var renderBounds := (float(renderDistance) * 2.) + 1.
	var loadingCoord: Array[Vector3i] = []
	
	var x := 0
	var z := 0
	var xx := 0
	var zz := -1
	
	for i in renderDistance**2:
		mutex.lock()
		var shouldExit = exitThread
		mutex.unlock()
		
		if shouldExit:
			break
		
		if (-renderDistance / 2 < x && x <= renderDistance / 2) && (-renderDistance / 2 < z && z <= renderDistance / 2):
			mutex.lock()
			var dx = x + currentChunkPos.x
			var dz = z + currentChunkPos.z
			mutex.unlock()
			var chunkCoords = Vector3i(dx, 0, dz)
			loadingCoord.append(chunkCoords)
			
			# 'loadingCoord' stores the coords that are in the new chunk(s)
			# make sure only inactive coords are loaded
			if activeCoords.find(chunkCoords) == -1:
				var chunk = chunkNode.instantiate()
				var chunkPos = Vector3(chunkCoords.x * chunkSize.x, 0., chunkCoords.z * chunkSize.x)
				chunk.call_deferred("set_position", chunkPos)
				#chunk.position.x = chunkCoords.x * chunkSize.x
				#chunk.position.z = chunkCoords.z * chunkSize.x
				activeChunks.append(chunk)
				activeCoords.append(chunkCoords)
				chunk.setup(generateCollision, chunkPos, chunkCoords, chunkSize, marcherSettings)
				#add_child(chunk)
				call_deferred("add_child", chunk)
		
		if x == z || (x < 0 && x == -z) || (x > 0 && x == 1-z):
			var t = xx
			xx = -zz
			zz = t
		x = x + xx
		z = z + zz
	
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
	
	mutex.lock()
	chunkLoaded = true
	mutex.unlock()
	
	print("%s: Loading chunks around %s with render distance %s took %s milliseconds" % [name, currentChunkPos, renderDistance, (Time.get_ticks_msec() - timeNow)])

func _exit_tree() -> void:
	if disabled:
		return
	
	print(name, ": Stopping chunk thread!")
	
	# Set thread exit condition
	mutex.lock()
	exitThread = true
	mutex.unlock()
	
	# Unblock by posting
	semaphore.post()
	
	# Wait for thread to finish
	thread.wait_to_finish()

func randomiseNoise() -> void:
	var rng := RandomNumberGenerator.new()
	if useRandomSeed:
		rng.randomize()
	else:
		if seed.is_valid_int():
			rng.seed = int(seed)
		else:
			rng.seed = seed.hash()
	print("%s: Seed: %s" % [name, rng.seed])
	noise.seed = rng.randi()
	noiseMask.seed = rng.randi()
	noiseTunnel.seed = rng.randi()

func noiseFunc(pos: Vector3) -> float:
	var noiseVal: float = 0.
	noiseVal += noise.get_noise_3dv(pos) * noiseMultiplier
	noiseVal += absf(noiseMask.get_noise_3dv(pos) * noiseMaskMultiplier)
	
	if noiseTunnelMultiplier != 0. && -pos.y + noiseVal > (noiseMultiplier + noiseMaskMultiplier) / 21.:
		#var falloff := 1. - (pos.y + chunkSize.z) / (chunkSize.y + chunkSize.z) * .75
		noiseVal *= noiseTunnel.get_noise_3dv(pos) * noiseTunnelMultiplier# * falloff
	return snappedf((-pos.y) + noiseVal, .001)# + fmod(pos.y, 4.) # Add 'pos.y % terraceHeight' for terracing

func _process(_delta) -> void:
	if disabled:
		return
	
	if Input.is_action_just_released("ui_end"):
		renderWireframe = !renderWireframe
		if renderWireframe:
			get_viewport().debug_draw = Viewport.DEBUG_DRAW_WIREFRAME
		else:
			get_viewport().debug_draw = Viewport.DEBUG_DRAW_DISABLED
	
	mutex.lock()
	currentChunkPos = _getPlayerChunk(player.global_position)
	
	if previousChunkPos != currentChunkPos:
		if !chunkLoaded:
			semaphore.post()
	else:
		chunkLoaded = false
	mutex.unlock()
	previousChunkPos = currentChunkPos

# Convert player position to chunk position
func _getPlayerChunk(pos: Vector3) -> Vector3i:
	var chunkPos := Vector3i.ZERO
	chunkPos.x = int(pos.x / chunkSize.x)
	chunkPos.z = int(pos.z / chunkSize.x)
	if pos.x < 0.:
		chunkPos.x -= 1
	if pos.z < 0.:
		chunkPos.z -= 1
	return chunkPos


















