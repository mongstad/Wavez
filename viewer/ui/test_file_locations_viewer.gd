extends "res://main.gd"
## Verify destination routing without relying on a rendering backend.

func _capture_inspection_png(path: String, _with_state: bool, _viewport_only: bool = false) -> Error:
	var image := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return image.save_png(path)
