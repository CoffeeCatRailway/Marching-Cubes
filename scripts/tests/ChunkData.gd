class_name ChunkData
extends Resource
# https://github.com/gdquest-demos/godot-demos-2022/blob/main/save-game/resources/SaveGame.gd

@export var settings: MarcherSettings # Marcher settings will be stored seperatly not in chunk data

@export var format: Image.Format = Image.FORMAT_L8
@export var resolution: int = 60

@export var values: PackedByteArray = PackedByteArray()
@export var valuesWithoutTUnnels: PackedByteArray = PackedByteArray()
