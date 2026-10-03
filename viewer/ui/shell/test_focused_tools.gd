extends SceneTree
const Viewer = preload("res://main.gd")
const Visual = preload("res://scene/visual_state.gd")
const Profile = preload("res://scene/playback_profile.gd")
const TITLES = ["Selection","Temporal","Space time","Diagnostics","Compare","Matched runs","Period","Bookmarks","Results","Mapping","Derive range","Slice","Clipping","Isosurface","Source probe","Performance","Geometry"]
var checks := 0
var failures: Array[String] = []
var viewer
var output: String
func _initialize():run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:failures.append(message);push_error(message)
func settle() -> void:
	for i in 5:await process_frame
func controls(node: Node) -> Array:
	var result: Array = []
	for child in node.get_children():
		result.append(child);result.append_array(controls(child))
	return result
func pick(choice: OptionButton, index: int) -> void:
	choice.select(index);choice.item_selected.emit(index)
func run() -> void:
	output = OS.get_cmdline_user_args()[0]
	create_timer(180).timeout.connect(func():push_error("Focused tools timeout");quit(1))
	viewer = Viewer.new();viewer.scene_prebuffer_enabled = false;root.add_child(viewer);viewer.set_process(false)
	check(not viewer.tools_ui.window.visible,"Tools start hidden")
	viewer._open_capture(output.path_join("mixed.wvz"));viewer.playing = false;viewer.orbit_enabled = false
	await settle()
	var tools = viewer.tools_ui;var layers = viewer.scene_layers;var selection = viewer.selection_controller;var temporal = selection.temporal
	var snapshot := Visual.snapshot(viewer);var objects: Dictionary = layers.selected_objects.duplicate();var source: Dictionary = selection.source.duplicate()
	var sample: Dictionary = viewer.committed_sample.duplicate(true);var serial: int = selection.jobs.serial
	var probe: String = layers.selected_volume
	Profile.enabled = true;Profile.reset()
	for title in TITLES:
		tools.open(title)
		for node in controls(tools.content):
			if node is OptionButton and node.has_meta("tool_pages"):
				for index in node.item_count:
					pick(node,index)
					var visible := 0
					for body in node.get_meta("tool_pages"):
						if body.visible:visible += 1
					check(visible == 1,"One section visible in "+title)
				pick(node,0)
		if tools.target_choices.has(title):
			for index in tools.target_choices[title].item_count:pick(tools.target_choices[title],index)
		tools.close()
	check(Profile.report().stages.is_empty() and Profile.report().counters.is_empty(),"Navigation performs no profiled scientific work")
	Profile.enabled = false
	check(Visual.snapshot(viewer) == snapshot and viewer.committed_sample == sample,"Navigation preserves scientific state and sample")
	check(layers.selected_objects == objects and layers.selected_volume == probe,"Tool target navigation preserves simulation and probe targets")
	check(selection.source == source and selection.jobs.serial == serial,"Navigation does not submit, cancel or bind selection work")
	temporal.channel.text = "other";temporal.start_time.text = "0.123456789012345"
	tools.open("Space time")
	check(tools.shared_slots["Space time"].is_ancestor_of(temporal.channel),"Space time edits original shared request widgets")
	tools.close();tools.open("Temporal")
	check(temporal.channel.text == "other" and temporal.start_time.text == "0.123456789012345","Shared draft survives close and reopen exactly")
	for index in 12:
		pick(selection.kind,index)
		check(selection.radius_input.visible == (index in [9,10]),"Radius shown only for sphere or cylinder")
		check(selection.members_input.visible == (index in [0,1,3,4,5,6]),"Only applicable address inputs visible")
	check(not tools.forms.has("Quick setup") and not tools.target_choices.has("Quick setup"),"Removed setup has no form or target route")
	check(not viewer.shell.commands.has("tool:Quick setup"),"Removed setup has no menu command")
	for key in layers.tool_bodies:check(not key.begins_with("Quick setup"),"No removed setup layer body: "+key)
	tools.open("Derive range")
	var low = layers.color_controls.volume0.percentile_low
	low.value = 7.5
	tools.close();tools.open("Derive range")
	check(layers.tool_bodies["Derive range:volume0"].is_ancestor_of(low) and low.value == 7.5,"Derive range owns persistent percentile draft")
	layers.sample(.5);layers.probe_channel = "other";layers.refresh_probe_channels();layers.probe_selected_volume()
	check(layers.probe_label.text.begins_with("other = 1"),"Explicit probe channel samples loaded source independently of display channel")
	check(layers.states.volume0.channel != "other","Probe channel leaves display mapping unchanged")
	check(layers.probe_stamp.time == 0.0 and layers.probe_stamp.object == "volume0" and layers.probe_stamp.capture == layers.reader.source_path and layers.probe_stamp.uuid == layers.reader.metadata.uuid and layers.probe_stamp.extent == layers.reader.scan_offset,"Probe stamps actual held source time and capture identity")
	var stamp: Dictionary = layers.probe_stamp.duplicate();var result: String = layers.probe_label.text
	layers.sample(1.);layers.refresh_probe_stamp()
	check(layers.probe_stamp == stamp and layers.probe_label.text == result and layers.probe_stamp_label.text.contains("Context changed"),"Later sample marks old result stale without relabeling it")
	layers.apply_state(layers.snapshot());layers.refresh_probe_stamp()
	check(layers.probe_stamp == stamp and layers.probe_label.text == result and layers.probe_channel == "other","Recipe rebuild preserves probe draft result and event stamp")
	# Reopen routing uses the actual operation, without starting another request.
	for pair in [["space_time","Space time"],["result_plot","Results"],["estimate_period","Period"],["compare_series","Compare"]]:
		selection.jobs.background_operation = pair[0];viewer.shell.status_ui.reopen_analysis()
		check(tools.current == pair[1] and selection.jobs.serial == serial,"Jobs reopens correct existing task: "+pair[0])
	selection.jobs.background_operation = ""
	selection.bind_source()
	var pending: bool = selection.jobs.pending;var request_serial: int = selection.jobs.serial
	tools.open("Selection");tools.close()
	check(selection.jobs.pending == pending and selection.jobs.serial == request_serial,"Close does not cancel the active source query")
	var deadline := Time.get_ticks_msec()+15000
	while selection.jobs.pending and Time.get_ticks_msec()<deadline:await process_frame
	check(not selection.source.is_empty() and not selection.jobs.pending,"Original source query completes after tool close")
	check(not tools.window.exclusive,"Selection host remains nonmodal for viewport gestures")
	for size in [Vector2i(1440,900),Vector2i(1920,1080),Vector2i(1024,640)]:
		root.size = size;await settle()
		for title in TITLES:
			tools.open(title);await settle()
			check(tools.window.size.x <= size.x and tools.window.size.y <= size.y,"Tool bounded at "+str(size)+": "+title)
			check(tools.content.get_parent().size.y >= 100,"Usable scroll area: "+title)
			for node in controls(tools.content):
				if node is Control and node.is_visible_in_tree() and node is not PopupMenu:
					check(node.size.x <= tools.window.size.x,"No width overflow: "+title+" "+node.get_class())
			for choice in controls(tools.content):
				if choice is OptionButton and choice.has_meta("tool_pages"):
					for index in choice.item_count:
						pick(choice,index);await settle()
						for node in controls(tools.content):
							if node is Control and node.is_visible_in_tree() and node is not PopupMenu:check(node.size.x <= tools.window.size.x,"Section width: "+title+" "+choice.get_item_text(index))
						if size.x == 1440 and title in ["Selection","Temporal","Compare"]:tools.window.get_texture().get_image().save_png(output.path_join(title.to_lower()+"-section-"+str(index)+".png"))
					pick(choice,0);await settle()
			if title in ["Selection","Temporal","Matched runs","Source probe","Performance"]:
				tools.window.get_texture().get_image().save_png(output.path_join(title.to_lower().replace(" ","-")+"-"+str(size.x)+".png"))
			tools.close()
	viewer.scene_prebuffer_enabled = true;viewer._open_capture(output.path_join("mixed.wvz"));viewer.set_process(true);viewer.playing = false
	root.size = Vector2i(1440,900);await settle()
	tools.open("Performance");await settle()
	check(viewer.scene_layers.playback.enabled and viewer.scene_layers.field_playback.enabled and viewer.scene_layers.mesh_playback.enabled,"Performance exposes normal particle field and mesh preparation owners")
	tools.window.get_texture().get_image().save_png(output.path_join("performance-buffered.png"));tools.close()
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	viewer.free();await process_frame
	print("TOOLS: ",checks," checks; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
