@tool
class_name MarcherSettings
extends Resource

@export var isoLevel := 0.
@export var smoothMesh: bool = true
@export var smoothNormals: bool = false
@export var gradient: Gradient
var noiseFunc: Callable

func _init() -> void:
	if resource_name == "":
		resource_name = "Settings"
