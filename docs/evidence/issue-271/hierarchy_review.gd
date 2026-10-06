extends SceneTree
const Viewer = preload("res://main.gd")
var output := "/tmp/wavez-271-review"
var layouts := []
var checks := 0
var failures := []
func _initialize(): run.call_deferred()
func check(ok, message):
	checks += 1
	if not ok: failures.append(message); push_error(message)
func settle():
	for i in 8: await process_frame
func luminance(c):
	var s = c.srgb_to_linear()
	return .2126*s.r + .7152*s.g + .0722*s.b
func run():
	DirAccess.make_dir_recursive_absolute(output)
	var theme = load("res://ui/theme/violet_slice_theme.gd").new()
	var before = load("/tmp/wavez-violet-271-before.gd").new()
	var changed := []
	for type in before.get_type_list():
		var keys = Array(before.get_color_list(type))
		for key in theme.get_color_list(type):
			if not keys.has(key): keys.append(key)
		for key in keys:
			if before.get_color(key,type) != theme.get_color(key,type): changed.append(type+":"+key)
		for key in before.get_constant_list(type): check(before.get_constant(key,type)==theme.get_constant(key,type),type+":"+key+" unchanged")
		for key in before.get_font_size_list(type): check(before.get_font_size(key,type)==theme.get_font_size(key,type),type+":"+key+" unchanged")
	changed.sort()
	check(changed == ["PanelTitle:font_color","SectionTitle:font_color","Window:title_color"],"Only three hierarchy colors differ: "+str(changed))
	for role in ["PanelTitle","SectionTitle"]:
		var color = theme.get_color("font_color",role)
		check((luminance(color)+.05)/(luminance(theme.c(&"surface.3"))+.05)>=4.5,role+" readable contrast")
	check(luminance(theme.c(&"text.disabled")) < luminance(theme.c(&"text.section")) and luminance(theme.c(&"text.section")) < luminance(theme.c(&"text.title")) and luminance(theme.c(&"text.title")) < luminance(theme.c(&"text.primary")),"Restrained distinct hierarchy brightness")
	var viewer = Viewer.new(); root.add_child(viewer); viewer.set_process(false)
	await settle()
	root.min_size = Vector2i.ZERO
	for scale in [1.0,2.0]:
		root.content_scale_factor = scale
		root.size = Vector2i(1440,900) if scale == 1.0 else Vector2i(3840,2160)
		await settle(); viewer.shell.layout(); viewer.shell.edit_shortcuts(); await settle()
		var dialog = viewer.shell.shortcuts_editor
		dialog.fit(); await settle()
		check(dialog.panel.get_global_rect().encloses(dialog.footer.get_global_rect()),"Shortcut footer fits at scale "+str(scale))
		check(dialog.groups.Navigation.title_label.get_theme_color("font_color")==theme.c(&"text.section"),"Live group inherits section color")
		layouts.append({"requested_scale":scale,"actual_window":str(root.size),"viewport":str(root.get_texture().get_size())})
		root.get_texture().get_image().save_png(output.path_join("shortcuts-scale-"+str(scale)+".png"))
		dialog.dismiss()
		var video = viewer.video_dialog; video.open(); await settle()
		check(video.groups.Range.title_label.get_theme_color("font_color")==theme.c(&"text.section"),"Video inherits section color")
		video.get_texture().get_image().save_png(output.path_join("video-scale-"+str(scale)+".png"))
		video.hide()
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"layouts":layouts,"failures":failures,"changed_theme_colors":changed},"  "))
	viewer.free(); await process_frame
	print("Hierarchy review: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
