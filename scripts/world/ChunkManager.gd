class_name ChunkManager
extends Node3D
## Chunk loading system based on https://github.com/NesiAwesomeneess/ChunkLoader/tree/main

# Each chunk has a parent node whish is 'chunk.tscn'
# Instanced for every chunk that hasn't been loaded
const chunkNode := preload("res://scenes/chunk.tscn")

@export var generateCollision := true
@export var marcherSettings: MarcherSettings

@export_group("Noise settings")
@export var useRandomSeed: bool = false:
	set(value):
		useRandomSeed = value
@export var seed: String = "0"
@export var noiseMultiplier: float = 10.
@export var noiseMaskMultiplier: float = 20.
@export var noiseTunnelMultiplier: float = 2.
@export var noise: FastNoiseLite
@export var noiseMask: FastNoiseLite
@export var noiseTunnel: FastNoiseLite

# Reference player to track location
@export_group("")
@export_node_path() var playerPath
var player: Node

@export_range(1, 10) var renderDistance: int = 3
@export var chunkSize: Vector2 = Vector2(20., 100.)
var currentChunkPos := Vector3i.ZERO
var previousChunkPos := Vector3i.ZERO
var chunkLoaded := false

@onready var activeCoords: Array[Vector3i] = []
@onready var activeChunks: Array[Chunk] = []

# Checks if the chunks within the render distance have been loaded
func _ready() -> void:
	randomiseNoise()
	marcherSettings.noiseFunc = Callable(self, "noiseFunc")
	
	player = get_node(playerPath)
	currentChunkPos = _getPlayerChunk(player.global_position)
	loadChunk()

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
	
	if (-pos.y) + noiseVal > (noiseMultiplier + noiseMaskMultiplier) / 21.:
		noiseVal *= noiseTunnel.get_noise_3dv(pos) * noiseTunnelMultiplier
	return (-pos.y) + noiseVal# + fmod(pos.y, 4.) # Add 'pos.y % terraceHeight' for terracing

func _process(_delta) -> void:
	currentChunkPos = _getPlayerChunk(player.global_position)
	if previousChunkPos != currentChunkPos:
		if !chunkLoaded:
			loadChunk()
	else:
		chunkLoaded = false
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

func loadChunk() -> void:
	var renderBounds := (float(renderDistance) * 2.) + 1.
	var loadingCoord: Array[Vector3i] = []
	
	# if x=0, then x+1 = 1
	# if 'renderBounds' = 5 (renderDistance = 2), then 5/2 = 2.5, round(2.5) = 3
	# then 1 - 3 = -2 which is the x coord in the chunk space
	for x in range(renderBounds):
		for z in range(renderBounds):
			var dx = (x + 1.) - round(renderBounds / 2.) + currentChunkPos.x
			var dz = (z + 1.) - round(renderBounds / 2.) + currentChunkPos.z
			
			var chunkCoords = Vector3i(dx, 0, dz)
			loadingCoord.append(chunkCoords)
			
			# 'loadingCoord' stores the coords that are in the new chunk(s)
			# make sure only inactive coords are loaded
			if activeCoords.find(chunkCoords) == -1:
				var chunk = chunkNode.instantiate()
				chunk.position.x = chunkCoords.x * chunkSize.x
				chunk.position.z = chunkCoords.z * chunkSize.x
				activeChunks.append(chunk)
				activeCoords.append(chunkCoords)
				chunk.setup(generateCollision, chunkCoords, chunkSize, marcherSettings)
				add_child(chunk)
	
	# Delete inactive (out of render distance) chunks
	var deletingChunks = []
	for x in activeCoords:
		if loadingCoord.find(x) == -1:
			deletingChunks.append(x)
	for x in deletingChunks:
		var i = activeCoords.find(x)
		activeChunks[i].save()
		activeChunks.remove_at(i)
		activeCoords.remove_at(i)
	chunkLoaded = true



















