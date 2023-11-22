#class_name WorldSaver
extends Node

# Added method for saveing data to disk and loading, later

var loadedChunks: Array[Vector3i] = []
var chunkData: Array[Array] = [] # Possibly make this a dictionary

func addChunk(coords: Vector3i) -> void:
	loadedChunks.append(coords)
	chunkData.append([])

func saveChunk(coords: Vector3i, data) -> void:
	chunkData[loadedChunks.find(coords)] = data

func retriveData(coords: Vector3i) -> Array:
	var data = chunkData[loadedChunks.find(coords)]
	return data
