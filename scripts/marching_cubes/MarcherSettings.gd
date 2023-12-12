@tool
class_name MarcherSettings
extends Resource

@export var isoLevel := 0.
@export var gradient: Gradient

@export_subgroup("Mesh Settings")
@export var smoothMesh: bool = true
@export var smoothNormals: bool = false

@export_subgroup("Noise Settings")
@export var baseMul := 1.
@export var noiseBase: FastNoiseLite # Base height map noise
@export var maskMul := 1.
@export_range(-1., 1., .05) var minMaskHeight := 0.
@export var noiseMask: FastNoiseLite # Mask noise, low resolution noise used for hills & valleys
@export var tunnelMul := 1.
@export var tunnelSurfacing := 0. # What y level do 'cave entrences' surface
@export var noiseTunnel: FastNoiseLite # Used to dig out 'caves'

var noiseFunc: Callable

func randomiseNoise(seed: String = "") -> int:
	var rng := RandomNumberGenerator.new()
	if seed.is_empty():
		rng.randomize()
	else:
		if seed.is_valid_int():
			rng.seed = int(seed)
		else:
			rng.seed = seed.hash()
	noiseBase.seed = rng.randi()
	noiseMask.seed = rng.randi()
	noiseTunnel.seed = rng.randi()
	return rng.seed

func _init() -> void:
	if resource_name == "":
		resource_name = "Settings"
