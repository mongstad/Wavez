extends SceneTree
const Viewer = preload("res://main.gd")
var viewer
var shell
var output := ""
var records := {}
func _initialize(): run.call_deferred()
func settle():
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
func box(style: StyleBox) -> Array:
	return [style.bg_color.to_html(),style.border_color.to_html(),style.get_border_width_min(),str(style.get_minimum_size()),style.expand_margin_top,style.corner_radius_top_left] if style is StyleBoxFlat else [style.get_class()]
func metric(control: Control) -> Dictionary:
	var font: Font = control.get_theme_font("font")
	return {"position":str(control.position),"size":str(control.size),"min":str(control.custom_minimum_size),"font_size":control.get_theme_font_size("font_size"),"font":font.get_font_name(),"font_class":font.get_class(),"embolden":font.variation_embolden if font is FontVariation else 0,"tooltip":control.tooltip_text,"focus_mode":control.focus_mode}
func record(name: String):
	var heading: Label = shell.edge_reveal.pins.right.get_parent().get_child(0)
	var data := {"light":shell.appearance.light,"heading":metric(heading),"heading_color":heading.get_theme_color("font_color").to_html(false),"pins":{},"other_title":heading.get_theme_color("font_color","PanelTitle").to_html(false)}
	for side in shell.edge_reveal.pins:
		var pin: Button = shell.edge_reveal.pins[side]
		var entry := metric(pin)
		entry.pinned=shell.edge_reveal.states[side].pinned;entry.button_pressed=pin.button_pressed;entry.icon_hash=pin.icon.get_source().hash()
		entry.self_modulate=pin.self_modulate.to_html()
		entry.colors={};entry.styles={}
		for state in ["normal","hover","pressed","hover_pressed","focus","disabled"]:
			entry.colors[state]=pin.get_theme_color("icon_"+state+"_color").to_html(false)
			entry.styles[state]=box(pin.get_theme_stylebox(state))
		data.pins[side]=entry
	var image := root.get_texture().get_image()
	var rect := heading.get_global_rect()
	var scale := root.content_scale_factor
	var background := []
	for y in [rect.position.y+2,rect.get_center().y,rect.end.y-2]:
		background.append(image.get_pixel(int((rect.end.x-8)*scale),int(y*scale)).to_html(false))
	data.background_samples=background
	data.heading_pixel_rect=[int(rect.position.x*scale),int(rect.position.y*scale),int(rect.end.x*scale),int(rect.end.y*scale)]
	records[name]=data
	image.save_png(output.path_join(name+".png"))
func key(code: Key):
	var event := InputEventKey.new();event.keycode=code;event.pressed=true;root.push_input(event)
	var release := event.duplicate();release.pressed=false;root.push_input(release)
func run():
	output=OS.get_cmdline_user_args()[0]
	viewer=Viewer.new();viewer.scene_prebuffer_enabled=false;root.add_child(viewer);viewer.set_process(false);await settle()
	shell=viewer.shell;shell.edge_reveal.set_process(false)
	if OS.get_cmdline_user_args().size()>1:
		record("restart")
		if OS.get_cmdline_user_args()[1]=="Light": shell.appearance.select(false)
	else:
		for light in [false,true,false,true]:
			shell.appearance.light=light;shell.appearance.apply();await settle()
			var mode := "light" if light else "dark"
			for layout in [[Vector2i(1440,900),1.0],[Vector2i(970,600),1.0],[Vector2i(3840,2160),2.0]]:
				root.size=layout[0];root.content_scale_factor=layout[1];await settle();shell.layout();await settle()
				for pinned in [true,false]:
					for side in shell.edge_reveal.pins: shell.edge_reveal.pins[side].button_pressed=pinned
					await settle()
					record(mode+"-"+str(layout[0].x)+("-pinned" if pinned else "-unpinned"))
				for side in shell.edge_reveal.pins: shell.edge_reveal.pins[side].button_pressed=true
				await settle()
			root.content_scale_factor=1.0;root.size=Vector2i(1440,900);await settle();shell.layout();await settle()
			var interactions := {}
			for side in shell.edge_reveal.pins:
				var pin: Button=shell.edge_reveal.pins[side];pin.grab_focus();await settle()
				var start: bool=shell.edge_reveal.states[side].pinned
				key(KEY_SPACE);await settle()
				interactions[side]=pin.has_focus() and shell.edge_reveal.states[side].pinned!=start and pin.button_pressed==shell.edge_reveal.states[side].pinned
				key(KEY_SPACE);await settle()
				interactions[side]=interactions[side] and shell.edge_reveal.states[side].pinned==start
			records[mode+"-keyboard"]=interactions
			var pin: Button=shell.edge_reveal.pins.right
			var motion := InputEventMouseMotion.new();motion.position=pin.get_global_rect().get_center();root.push_input(motion)
			await create_timer(.12).timeout;await settle()
			records[mode+"-hover"]={"hovered":pin.is_hovered(),"focused":pin.has_focus(),"ink":pin.get_theme_color("icon_hover_color").to_html(false),"modulate":pin.self_modulate.to_html()}
			motion.position=Vector2(100,200);root.push_input(motion);pin.release_focus();await create_timer(.12).timeout;await settle()
			shell.dock.hide();await settle();shell.dock.show();shell.layout();await settle();record(mode+"-reopened")
		shell.appearance.select(true)
	await settle()
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(records,"  "))
	viewer.free();await process_frame;quit()
