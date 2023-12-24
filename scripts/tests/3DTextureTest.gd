extends Node2D

@export_range(1, 200, 1, "or_greater") var size := 200
@export var settings: MarcherSettings
var theoreticalMaxNoise: float
var texture

var sprite: Sprite2D
var sprite2: Sprite2D
var updateSprie := true
var slice := 0

var minVal := 0.
var maxVal := 0.

func _ready():
	sprite = $Sprite2D
	sprite2 = $Sprite2D2
	$HSlider.max_value = size - 1
	$HSlider2.max_value = size
	$HSlider2.value = size / 10
	
	settings.randomiseNoise("0")
	theoreticalMaxNoise = getMaxNoise(-(size / 2.), settings) / minf(settings.baseMul, settings.maskMul) / 2.
	print("Theoretical max noise value: ", theoreticalMaxNoise)
	
	var timeNow := Time.get_ticks_msec()
	var data: Array[Image] = []
	for z in size:
		data.append(createSlice(size, z))
	
	texture = ImageTexture3D.new()
	texture.create(Image.FORMAT_RGB8, size, size, size, false, data)
	print("Texture creation took %s miliseconds" % [Time.get_ticks_msec() - timeNow])
	print("Min: %s, Max: %s" % [minVal, maxVal])

func getMaxNoise(maxY: float, settings: MarcherSettings) -> float:
	var value := -maxY
	value += 1. * settings.baseMul
	value += 1. * settings.maskMul
	return absf(value)

func noiseFunc(pos: Vector3) -> float:
	#if pos.y <= -(chunkSize / 2.):
	#	return settings.isoLevel;
	var noiseVal: float = -pos.y
	noiseVal += settings.noiseBase.get_noise_3dv(pos) * settings.baseMul
	#noiseVal += marcherSettings.noiseMask.get_noise_3dv(pos) * marcherSettings.maskMul
	noiseVal += maxf(settings.minMaskHeight, settings.noiseMask.get_noise_3dv(pos)) * settings.maskMul
	
	noiseVal /= (settings.baseMul + settings.maskMul) # Bring values closer to -1 to 1
	# Bring to 0-1, given baseMul & maskMul are equal
	# If maskMul < baseMul then max > 1
	#var max := getMaxNoise(-(size / 2.), settings) / settings.baseMul
	noiseVal = (noiseVal + theoreticalMaxNoise) / (theoreticalMaxNoise * 2.)
	
	#var tunnel := settings.noiseTunnel.get_noise_3dv(pos) * settings.tunnelMul
	#if tunnel < 0. && noiseVal >= settings.tunnelSurfacing:
	#	noiseVal *= tunnel
	
	var tunnel := 1. - (settings.noiseTunnel.get_noise_3dv(pos) + 1.) / 2.
	noiseVal *= tunnel / 2. + .5
	
	noiseVal = snappedf(noiseVal, .001)
	minVal = minf(minVal, noiseVal)
	maxVal = maxf(maxVal, noiseVal)
	return noiseVal

var tempPos: Vector3 = Vector3.ZERO
func createSlice(size: int, slice: int) -> Image:
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	for x in size:
		for y in size:
			tempPos.x = x
			tempPos.y = y - size / 2.
			tempPos.z = slice
			
			var value := noiseFunc(tempPos)
			#image.set_pixel(x, y, Color.from_hsv(0., 0., value))
			image.set_pixel(x, y, Color.from_hsv(value, 1., 1.))
	return image

var resScale := 1
func _process(delta):
	if updateSprie:
		var t: Image = texture.get_data()[slice]
		sprite.texture = ImageTexture.create_from_image(t)
		
		var halfRes := size / resScale
		var resMul := size / halfRes
		var halfResTex := Image.create(halfRes, halfRes, false, Image.FORMAT_RGB8)
		for x in halfRes:
			for y in halfRes:
				halfResTex.set_pixel(x, y, t.get_pixel(x * resMul, y * resMul))
		sprite2.texture = ImageTexture.create_from_image(halfResTex)
		sprite2.scale = Vector2.ONE * resMul
		
		updateSprie = false

func _on_slice_changed(value):
	slice = value
	#print(slice)
	updateSprie = true

func _on_res_changed(value):
	resScale = value#roundi((size + 1) / value)
	updateSprie = true
