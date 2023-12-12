@tool
class_name ChunkVaryingResolution extends MeshInstance3D
## Based on https://github.com/Chevifier/Inifinte-Terrain-Generation

@export var generate := false:
	set(value):
		if value:
			generate = false
			generateChunk(Vector3i.ZERO, chunkSize, marcherSettings)

@export_range(1, 400, 1) var chunkSize := 200
@export_range(1, 100, 1) var resolution := 60
@export var lods: Array[int] = [2, 4, 8, 16, 30, 60]
@export var lodDistance: Array[int] = [2000, 1500, 1050, 900, 790, 550] # Tweak distances

@export var marcherSettings: MarcherSettings
@export var material: Material

const CENTER_OFFSET := Vector3(.5, .5, .5)

var chunkPosition := Vector3()
var gridPosition := Vector3i()

#var material: StandardMaterial3D

#func _ready() -> void:
	#marcherSettings.noiseFunc = noiseFunc
	#material = StandardMaterial3D.new()
	#material.vertex_color_use_as_albedo = true

#func generatePlane() -> void:
#	var arrMesh: ArrayMesh
#	var surfaceTool := SurfaceTool.new()
#	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
#	
#	for z in resolution + 1:
#		for x in resolution + 1:
#			var percent = Vector2(x, z) / resolution
#			var pointOnMesh = Vector3(percent.x - .5, 0., percent.y - .5)
#			var vertex = pointOnMesh * chunkSize
#			
#			vertex.y = marcherSettings.noiseBase.get_noise_2d(position.x + vertex.x, position.z + vertex.z)
#			
#			surfaceTool.add_vertex(vertex)
#	
#	var vert = 0
#	for z in resolution:
#		for x in resolution:
#			surfaceTool.add_index(vert)
#			surfaceTool.add_index(vert + 1)
#			surfaceTool.add_index(vert + resolution + 1)
#			surfaceTool.add_index(vert + resolution + 1)
#			surfaceTool.add_index(vert + 1)
#			surfaceTool.add_index(vert + resolution + 2)
#			vert += 1
#		vert += 1
#	surfaceTool.generate_normals()
#	
#	arrMesh = surfaceTool.commit()
#	mesh = arrMesh

func generateChunk(coords: Vector3i, _chunkSize: int, marcherSettings: MarcherSettings) -> void:
	chunkSize = _chunkSize
	gridPosition = coords
	chunkPosition = gridPosition * chunkSize
	
	var polys: Array[Marcher.Triangle] = []
	polys.resize(10)
	
	var totalTriCount := 0
	
	var arrMesh: ArrayMesh
	var surfaceTool := SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	#surfaceTool.set_material(material)
	
	var minVal := 0.
	var maxVal := 0.
	
	for x in resolution:
		for y in resolution:
			for z in resolution:
				# Get the percentage of the currnet point
				var percent := Vector3(x, y, z) / resolution - CENTER_OFFSET
				var vertex := Vector3(percent.x, percent.y, percent.z) * chunkSize
				
				var gridCell := Marcher.GridCell.new(vertex.x, vertex.y, vertex.z)
				for i in 8:
					gridCell.value[i] = marcherSettings.noiseFunc.call(position + vertex + LookupTable.CornerOffsets[i] / resolution * chunkSize, marcherSettings)
					minVal = minf(minVal, gridCell.value[i])
					maxVal = maxf(maxVal, gridCell.value[i])
				
				var triCount := Marcher.polygoniseCube(gridCell, marcherSettings, polys, float(chunkSize) / float(resolution))
				if triCount == 0:
					continue
				
				for tri in polys:
					if tri == null:
						continue
					
					#var steepness = 1. - ((position + tri.vertices[2]).normalized().dot(tri.normal[2]) * .5 + .5)
					#var n = (noise.get_noise_2d(position.x + tri.vertices[2].x, position.z + tri.vertices[2].y) - .4) * .038
					#var rockWeight = smoothstep(.24 + n, .24 + .001 + n, steepness)
					#var color = marcherSettings.gradient.sample(rockWeight)
					
					#surfaceTool.set_color(color)
					surfaceTool.set_normal(tri.normal[2])
					surfaceTool.add_vertex(tri.vertices[2])
					
					surfaceTool.set_normal(tri.normal[1])
					surfaceTool.add_vertex(tri.vertices[1])
					
					surfaceTool.set_normal(tri.normal[0])
					surfaceTool.add_vertex(tri.vertices[0])
					totalTriCount += 1
	print("Triangles: %s" % totalTriCount)
	print("Min: %s, Max: %s" % [minVal, maxVal])
	
	#var vert = 0
	#for x in resolution:
	#	for y in resolution:
	#		for z in resolution:
	#			surfaceTool.add_index(vert)
	#			surfaceTool.add_index(vert + 1)
	#			surfaceTool.add_index(vert + resolution + 1)
	#			
	#			surfaceTool.add_index(vert + resolution + 1)
	#			surfaceTool.add_index(vert + 1)
	#			surfaceTool.add_index(vert + resolution + 2)
	#			
	#			surfaceTool.add_index(vert + resolution + 2)
	#			surfaceTool.add_index(vert + 3)
	#			surfaceTool.add_index(vert)
	#			vert += 1
	#		vert += 1
	#	vert += 1
	
	arrMesh = surfaceTool.commit()
	mesh = arrMesh
	mesh.surface_set_material(0, material)
	$StaticBody3D/CollisionShape3D.shape = arrMesh.create_trimesh_shape()





