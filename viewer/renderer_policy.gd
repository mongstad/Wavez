extends RefCounted
## The supported renderer is also the renderer for every offline GPU worker.
const METHOD := "forward_plus"
const DRIVER := "vulkan"
const REQUIREMENT := "Wavez requires Forward+ Vulkan and a Vulkan-capable GPU with working drivers. OpenGL/Compatibility and Mobile rendering are unsupported."

static func runtime() -> Dictionary:
	return {"rendering_method":RenderingServer.get_current_rendering_method(), "rendering_driver":RenderingServer.get_current_rendering_driver_name(), "gpu":RenderingServer.get_video_adapter_name()}

static func problem(allow_unit_test := false) -> String:
	# Dummy-renderer tests may inspect CPU contracts. They never certify rendering
	# and cannot turn a standalone/headless viewer or export into a supported path.
	if allow_unit_test and DisplayServer.get_name() == "headless" and OS.has_feature("editor") and OS.get_cmdline_args().has("--script"):
		return ""
	var actual := runtime()
	if DisplayServer.get_name() == "headless" or actual.rendering_method != METHOD or actual.rendering_driver != DRIVER:
		return REQUIREMENT + " Detected %s / %s (%s). Update the GPU driver and run on a graphical desktop with Vulkan support." % [actual.rendering_method,actual.rendering_driver,DisplayServer.get_name()]
	return ""
