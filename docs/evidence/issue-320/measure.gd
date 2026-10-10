extends SceneTree
## Review-only production-control samples. Does not change application preferences.
const Viewer = preload("res://main.gd")
var viewer
var output: String
var records := {}
func _initialize(): run.call_deferred()
func settle():
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
func picture(name: String): root.get_texture().get_image().save_png(output.path_join(name+".png"))
func describe(theme: Theme) -> Dictionary:
	var result := {}
	for type in theme.get_type_list():
		var entry := {"colors":{},"styles":{},"icons":{},"constants":{},"sizes":{}}
		for key in theme.get_color_list(type): entry.colors[key] = theme.get_color(key,type).to_html()
		for key in theme.get_constant_list(type): entry.constants[key] = theme.get_constant(key,type)
		for key in theme.get_font_size_list(type): entry.sizes[key] = theme.get_font_size(key,type)
		for key in theme.get_icon_list(type):
			var icon: Texture2D = theme.get_icon(key,type)
			entry.icons[key] = icon.get_source() if icon is DPITexture else str(icon.get_size())
		for key in theme.get_stylebox_list(type):
			var style: StyleBox = theme.get_stylebox(key,type)
			var props := {}
			for prop in style.get_property_list():
				if prop.usage & PROPERTY_USAGE_STORAGE and prop.name not in ["resource_local_to_scene","resource_name","script"]:
					var value = style.get(prop.name)
					if value is GradientTexture2D: props[prop.name] = str(value.gradient.colors)
					elif not value is Resource: props[prop.name] = str(value)
			entry.styles[key] = props
		result[type] = entry
	return result
func sample(control: Control, ink: String, label: String, point := Vector2(-1,-1)):
	var image := root.get_texture().get_image()
	var rect := control.get_global_rect()
	if control.get_window() != root: rect.position += Vector2(control.get_window().position)
	var scale := root.content_scale_factor
	var locations := [Vector2(rect.end.x-8,rect.position.y+2),Vector2(rect.end.x-8,rect.get_center().y),Vector2(rect.end.x-8,rect.end.y-2)] if point.x < 0 else [point]
	var pixels := []
	for location in locations:
		var pixel := Vector2i(location*scale)
		if Rect2i(Vector2i.ZERO,image.get_size()).has_point(pixel): pixels.append(image.get_pixelv(pixel).to_html(false))
	var tint := control.self_modulate * control.modulate
	records[label] = {"path":str(control.get_path()),"rect":str(rect),"window":str(root.size),"scale":scale,"foreground":control.get_theme_color(ink).to_html(false),"tint":tint.to_html(),"background_samples":pixels}
func gather(node: Node, kind: String) -> Control:
	if node is Control and node.is_visible_in_tree() and Rect2(Vector2.ZERO,Vector2(root.size)).encloses(node.get_global_rect()):
		if node.get_class() == kind: return node
	for child in node.get_children(true):
		var match_control := gather(child,kind)
		if match_control != null: return match_control
	return null
func key(code: Key):
	var event := InputEventKey.new();event.keycode=code;event.pressed=true;root.push_input(event)
	var release := event.duplicate();release.pressed=false;root.push_input(release)
func run():
	output=OS.get_cmdline_user_args()[0]
	viewer=Viewer.new();viewer.scene_prebuffer_enabled=false;root.add_child(viewer);viewer.set_process(false)
	viewer.shell.edge_reveal.set_process(false);await settle()
	records.dark_theme=describe(viewer.shell.style_slice.theme)
	viewer.shell.appearance.light=true;viewer.shell.appearance.apply();await settle();picture("empty-light")
	records.light_theme=describe(viewer.shell.edge_reveal.pins.right.theme)
	viewer._open_capture(output.path_join("mixed.wvz"));viewer.playing=false;viewer.orbit_enabled=false
	var prepared: Dictionary=viewer.scene_layers.sample(viewer.requested_time,false)
	records.committed_fixture={"ok":not prepared.is_empty(),"objects":viewer.scene_layers.current.size()}
	viewer._sync_control_state();viewer.shell.refresh();await settle()
	for title in viewer.section_buttons:viewer.section_buttons[title].button_pressed=true
	for layout in [[Vector2i(1440,900),1.0],[Vector2i(970,600),1.0],[Vector2i(3840,2160),2.0]]:
		root.content_scale_factor=layout[1];root.size=layout[0];await settle();viewer.shell.layout();await settle()
		var suffix:=str(layout[0].x)
		var heading:Label=viewer.shell.edge_reveal.pins.right.get_parent().get_child(0)
		sample(heading,"font_color","Simulation-"+suffix)
		for title in viewer.section_buttons:
			var button:Button=viewer.section_buttons[title]
			if button.is_visible_in_tree() and button.get_global_rect().end.y < root.size.y/root.content_scale_factor:
				sample(button,"font_pressed_color",title+"-"+suffix,button.get_global_rect().position+Vector2(button.size.x*.6,4))
		picture("expanded-light-"+suffix)
		for side in viewer.shell.edge_reveal.pins:
			var pin:Button=viewer.shell.edge_reveal.pins[side]
			sample(pin,"icon_normal_color","pin-"+side+"-"+suffix,pin.get_global_rect().position+Vector2(3,3))
	root.content_scale_factor=1;root.size=Vector2i(1440,900);await settle();viewer.shell.layout();await settle()
	var interactions := {}
	for side in viewer.shell.edge_reveal.pins:
		var pin:Button=viewer.shell.edge_reveal.pins[side];pin.grab_focus();await settle()
		var original:bool=viewer.shell.edge_reveal.states[side].pinned
		key(KEY_SPACE);await settle()
		interactions[side]=pin.has_focus() and viewer.shell.edge_reveal.states[side].pinned!=original
		key(KEY_SPACE);await settle();interactions[side]=interactions[side] and viewer.shell.edge_reveal.states[side].pinned==original
	records.pin_keyboard=interactions
	var dropdown:OptionButton=gather(viewer.shell.dock,"OptionButton")
	if dropdown != null:
		for state in ["normal","hover","pressed","disabled"]:
			dropdown.disabled=state=="disabled";dropdown.set_pressed_no_signal(state=="pressed")
			var motion:=InputEventMouseMotion.new();motion.position=dropdown.get_global_rect().get_center() if state=="hover" else Vector2(100,200);root.push_input(motion)
			await create_timer(.12).timeout;await settle()
			sample(dropdown,"font_"+state+"_color" if state!="normal" else "font_color","dropdown-"+state,dropdown.get_global_rect().position+Vector2(dropdown.size.x*.5,4))
			picture("dropdown-"+state)
		dropdown.disabled=false;dropdown.set_pressed_no_signal(false)
	viewer.tools_ui.open("Source probe");await settle()
	var input:LineEdit=viewer.scene_layers.probe_spins[0].get_line_edit()
	if input != null:
		var input_point := input.get_global_rect().position+Vector2(viewer.tools_ui.window.position)+Vector2(input.size.x*.5,3)
		sample(input,"font_color","input-normal",input_point)
		input.grab_focus();input.select_all();await settle();picture("input-focus")
		sample(input,"font_color","input-focus",input_point)
		sample(input,"font_selected_color","input-selected",input.get_global_rect().position+Vector2(viewer.tools_ui.window.position)+Vector2(13,input.size.y*.5+7))
		input.editable=false;await settle();picture("input-readonly")
		sample(input,"font_uneditable_color","input-readonly",input_point)
		input.editable=true
	picture("source-probe");viewer.tools_ui.close(false)
	viewer.tools_ui.open("Global effects");await settle();picture("global-effects");viewer.tools_ui.close(false)
	viewer.shell.about.open();await settle();picture("about-light");viewer.shell.about.hide()
	viewer.shell.select_workspace(1);await settle();picture("fields-light")
	viewer.shell.select_workspace(2);await settle();picture("meshes-light")
	viewer.shell.appearance.light=false;viewer.shell.appearance.apply();await settle();picture("dark-restored")
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(records,"  "))
	viewer.queue_free();await process_frame;quit()
