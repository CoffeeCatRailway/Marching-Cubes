extends AspectRatioContainer

var fps := 0
var drawCalls := 0
var frameTime := 0.
var vram := 0.
var objects := 0

func _process(delta):
	fps = Engine.get_frames_per_second()
	drawCalls = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	frameTime = delta
	vram = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1024. / 1024.
	objects = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	
	$Label.text = "FPS: %d\nDraw Calls: %d\n" % [fps, drawCalls]
	$Label.text += "Frame Time: %.5f\nVRAM: %.2fMB\n" % [frameTime, vram]
	$Label.text += "Objects: %d\n" % [objects]
