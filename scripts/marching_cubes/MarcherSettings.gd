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

func _init() -> void:
	if resource_name == "":
		resource_name = "Settings"
