extends Node
## Outer-surface and flush header/body pixel regression, not scientific viewport masking.
const Viewer = preload("res://main.gd")
const Visual = preload("res://scene/visual_state.gd")
var checks := 0
var failures: Array[String] = []
var output := ""
var layouts: Array = []
@onready var root: Window = get_tree().root

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)

func _ready() -> void: run.call_deferred()
func settle() -> void:
	for i in 10: await get_tree().process_frame
	await get_tree().create_timer(.15).timeout
	await RenderingServer.frame_post_draw

func picture(name: String) -> Image:
	var image := root.get_texture().get_image()
	image.save_png(output.path_join(name+".png"))
	return image

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--rounded-output="): output = arg.trim_prefix("--rounded-output=")
	if output.is_empty(): queue_free(); return
	get_tree().create_timer(120).timeout.connect(func(): push_error("Rounded surface test timed out"); get_tree().quit(1))
	await get_tree().process_frame
	var viewer = get_tree().current_scene
	if viewer == null:
		viewer = Viewer.new(); root.add_child(viewer)
	viewer.set_process(false)
	var shell = viewer.shell
	shell.edge_reveal.set_process(false)
	for side in shell.edge_reveal.states: shell.edge_reveal.set_pinned(side, true)
	var state: Dictionary = Visual.snapshot(viewer)
	var camera: Transform3D = viewer.camera.transform
	var theme = shell.style_slice.theme
	var body: StyleBoxFlat = theme.get_stylebox("panel", "AcceptDialog")
	var header: StyleBoxFlat = theme.get_stylebox("embedded_border", "Window")
	check(body.corner_radius_top_left == 0 and body.corner_radius_top_right == 0, "Dialog body joins header without internal corner cutouts")
	check(body.corner_radius_bottom_left == theme.OUTER_RADIUS and header.corner_radius_top_left == theme.OUTER_RADIUS, "About outer radius is shared")
	for mode in [Window.MODE_WINDOWED, Window.MODE_MAXIMIZED, Window.MODE_FULLSCREEN, Window.MODE_WINDOWED]:
		root.mode = mode; await settle(); shell.layout(); await settle()
		var status: StyleBoxFlat = shell.status_ui.get_theme_stylebox("panel")
		check(status.corner_radius_bottom_left == (theme.OUTER_RADIUS if mode == Window.MODE_WINDOWED else 0), "Only windowed outer bottom corners rounded: "+str(mode))
		check(status.corner_radius_top_left == 0 and status.corner_radius_top_right == 0, "Viewport/status internal join stays square: "+str(mode))
		check(shell.bar.get_theme_stylebox("panel") == (shell.window_chrome.rounded_bar if mode == Window.MODE_WINDOWED else shell.window_chrome.square_bar), "Native mode selects cached outer top style: "+str(mode))
		check(viewer.camera.transform == camera and Visual.snapshot(viewer) == state, "Native mode style preserves camera/scientific state: "+str(mode))
		picture("shell-mode-"+str(mode))
	var cached: StyleBox = shell.bar.get_theme_stylebox("panel")
	for i in 20: shell.window_chrome.refresh()
	check(shell.bar.get_theme_stylebox("panel") == cached and theme.rounded_tones.size() == 1, "Repeated layout reuses cached styles/textures")
	for layout in [[Vector2i(1440,900),1.0],[Vector2i(970,600),1.0],[Vector2i(3840,2160),2.0],[Vector2i(3840,2160),2.5]]:
		root.content_scale_factor = layout[1]; root.size = layout[0]; await settle(); shell.layout(); await settle()
		var id := str(layout[0].x)+"-"+str(layout[1])
		check(shell.navigation.get_global_rect().position.x == 12, "Camera controls keep normal margin: "+id)
		check(shell.bar.size.y == 48, "Corner treatment preserves top-bar geometry: "+id)
		picture("shell-"+id)
		shell.about.open(); await settle()
		var image := picture("about-"+id)
		var seam := Vector2(shell.about.position)*root.content_scale_factor
		var width := float(shell.about.size.x)*root.content_scale_factor
		var color: Color = theme.c(&"surface.3")
		# Sample both edges across the header/body boundary, away from text.
		for side in [0,1]:
			for y in [-2,-1,0,1,2,3,4]:
				var x: float = seam.x+2*root.content_scale_factor
				# Width is already in device pixels; only the inset is scaled.
				if side == 1: x = seam.x+width-3*root.content_scale_factor
				var pixel := image.get_pixel(int(x), int(seam.y+y*root.content_scale_factor))
				check(Vector3(pixel.r,pixel.g,pixel.b).distance_to(Vector3(color.r,color.g,color.b)) < .025, "No header/body seam leak side %s y %s: %s" % [side,y,id])
		shell.about.hide(); await settle()
		shell.edit_shortcuts(); await settle()
		var editor = shell.shortcuts_editor
		var style: StyleBoxFlat = editor.panel.get_theme_stylebox("panel")
		check(style.corner_radius_top_left == theme.OUTER_RADIUS and style.corner_radius_bottom_left == theme.OUTER_RADIUS, "Single custom shortcut surface shares outer radius: "+id)
		check(editor.panel.get_global_rect().encloses(editor.footer.get_global_rect()), "Rounded preferences keep fixed footer inside: "+id)
		picture("shortcuts-"+id); editor.dismiss(); await settle()
		shell.edit_orbit_center(); await settle()
		check(shell.orbit_editor.panel.get_theme_stylebox("panel").texture_margin_top == theme.OUTER_RADIUS, "Orbit surface shares radius: "+id)
		picture("orbit-"+id); shell.dismiss_orbit_editor(); await settle()
		viewer.tools_ui.open("Mapping"); await settle()
		var tool_style: StyleBoxFlat = viewer.tools_ui.surface.get_theme_stylebox("panel")
		check(tool_style.corner_radius_top_left == 0 and tool_style.corner_radius_bottom_left == theme.OUTER_RADIUS, "Tools body flush to header with rounded outer bottom: "+id)
		picture("mapping-"+id); viewer.tools_ui.close(); await settle()
		layouts.append({"requested":str(layout[0]),"actual":str(root.size),"scale":root.content_scale_factor,"logical":str(root.get_visible_rect().size)})
	root.content_scale_factor = 1; root.size = Vector2i(1440,900); await settle()
	check(viewer.camera.transform == camera and Visual.snapshot(viewer) == state, "All surface views preserve camera and scientific state")
	var report := {"checks":checks,"failures":failures,"layouts":layouts,"renderer":RenderingServer.get_current_rendering_method(),"display_driver":DisplayServer.get_name(),"packaged":OS.has_feature("template"),"executable":OS.get_executable_path()}
	FileAccess.open(output.path_join("rounded-report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("ROUNDED: ",checks," checks; failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
