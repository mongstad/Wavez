extends SceneTree
const Viewer = preload("res://main.gd")
const Visual = preload("res://scene/visual_state.gd")
const Profile = preload("res://scene/playback_profile.gd")
var checks := 0
var failures: Array[String] = []
var viewer
var output: String
func _initialize(): run.call_deferred()
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:failures.append(message);push_error(message)
func pick(control: OptionButton, index: int) -> void:
	control.select(index);control.item_selected.emit(index)
func edit(control: LineEdit, value: String) -> void:
	control.text = value;control.text_submitted.emit(value)
func particle_state() -> Dictionary:
	var state := Visual.snapshot(viewer);state.erase("scene");return state
func hierarchy(node: Node, depth := 0) -> void:
	if node.has_meta("panel_header"):depth += 1
	check(depth <= 1,"No nested panel disclosure: "+str(node.get_path()))
	if node.has_meta("panel_disclosure"):
		check(node.icon != null and node.custom_minimum_size.y >= 32,"Distinct chevron disclosure header")
	for child in node.get_children():hierarchy(child,depth)
func settle() -> void:
	for i in 5:await process_frame

func disclosures() -> Dictionary:
	var values := {}
	for title in viewer.section_buttons: values["particles/"+title] = viewer.section_buttons[title].button_pressed
	if viewer.scene_layers != null:
		for title in viewer.scene_layers.panel_groups: values[title] = viewer.scene_layers.panel_groups[title].button_pressed
	return values

func check_session_disclosures() -> void:
	for title in disclosures():check(not disclosures()[title],"Fresh session starts collapsed: "+title)
	viewer._open_capture(output.path_join("mixed.ssc"));viewer.playing = false
	for title in disclosures():check(not disclosures()[title],"First mixed capture starts collapsed: "+title)
	viewer.section_buttons.Rendering.button_pressed = true
	viewer.section_buttons["Advanced • Size / Brightness"].button_pressed = true
	var layers = viewer.scene_layers
	layers.panel_groups["volume0/Rendering"].button_pressed = true
	layers.panel_groups["volume1/Opacity"].button_pressed = true
	layers.panel_groups["mesh1/Color Mapping"].button_pressed = true
	var chosen := disclosures()
	for repeat in 3:
		for index in 3:
			viewer.shell.select_workspace(index)
			for kind in ["volume","mesh"]:
				for i in 2:pick(layers.object_choices[kind],i)
	check(disclosures() == chosen,"Category/object switches preserve mixed open and closed groups")
	var saved := Visual.snapshot(viewer)
	Visual.apply(viewer,saved)
	check(disclosures() == chosen,"Visual recipe rebuild preserves session layer disclosures")
	# Particle sections are explicitly recipe-owned; do not remove that contract.
	viewer.section_buttons.Rendering.button_pressed = false
	Visual.apply(viewer,saved)
	check(disclosures() == chosen,"Explicit particle recipe disclosure is honored")
	viewer._open_capture(output.path_join("mixed-replacement.ssc"));viewer.playing = false
	check(disclosures() == chosen,"Different capture with matching logical groups preserves choices")
	viewer._open_capture(output.path_join("particles.ssc"));viewer.playing = false
	for title in disclosures():check(disclosures()[title] == chosen[title],"Particle disclosure survives missing layers: "+title)
	viewer._open_capture(output.path_join("mixed.ssc"));viewer.playing = false
	check(disclosures() == chosen,"Layer disclosures survive absence and reintroduction in session")
	viewer._open_capture(output.path_join("fields.ssc"));viewer.playing = false
	for title in disclosures():check(disclosures()[title] == chosen[title],"Field-only replacement preserves matching choices: "+title)
	viewer._open_capture(output.path_join("mixed.ssc"));viewer.playing = false
	check(disclosures() == chosen,"Replacement after object selection preserves per-object disclosures")

func run() -> void:
	output = OS.get_cmdline_user_args()[0]
	create_timer(120).timeout.connect(func():push_error("Panel test timeout");quit(1))
	viewer = Viewer.new();viewer.scene_prebuffer_enabled = false;root.add_child(viewer);viewer.set_process(false)
	check_session_disclosures()
	viewer._open_capture(output.path_join("mixed.ssc"));viewer.playing = false;viewer.orbit_enabled = false
	await settle()
	var shell = viewer.shell;var layers = viewer.scene_layers
	check(shell.WORKSPACES == ["Particles","Fields","Meshes"],"Exact simulation categories")
	check(layers.object_choices.volume.item_count == 2 and layers.object_choices.mesh.item_count == 2,"Both fields and meshes have independent object selectors")
	var before := Visual.snapshot(viewer);var sample: Dictionary = viewer.committed_sample.duplicate(true)
	var source: Dictionary = viewer.selection_controller.source.duplicate(true)
	var serial: int = viewer.selection_controller.jobs.serial
	var probe_target: String = layers.selected_volume
	Profile.enabled = true;Profile.reset()
	for index in 3:
		shell.select_workspace(index)
		for kind in ["volume","mesh"]:
			for i in 2:pick(layers.object_choices[kind],i)
	var activity := Profile.report();Profile.enabled = false
	check(activity.stages.is_empty() and activity.counters.is_empty(),"Context switches submit no scientific work")
	check(Visual.snapshot(viewer) == before and viewer.committed_sample == sample,"Context switches preserve values, visibility and sample")
	check(viewer.selection_controller.source == source and viewer.selection_controller.jobs.serial == serial and layers.selected_volume == probe_target,"Context does not bind analysis/selection/probe or create requests")
	check(not layers.object_bodies.volume0.visible and layers.object_bodies.volume1.visible,"Only selected field form is presented")
	check(not layers.object_bodies.mesh0.visible and layers.object_bodies.mesh1.visible,"Only selected mesh form is presented")
	hierarchy(viewer.inspector_box);hierarchy(layers.panel)
	check(viewer.section_buttons["Particle Filters"].get_parent() == viewer.section_buttons.Rendering.get_parent(),"Particle Filters is a Rendering sibling")
	check(viewer.filter_box.get_child(0).text == "Density tracers" and viewer.filter_box.get_child(1).text == "Coverage tracers","Known verbose filter labels are concise")
	check(viewer.filter_box.get_child(0).tooltip_text == "Density-seeded passive tracers (Type 0)","Full type provenance retained in tooltip")
	check(viewer._filter_display_label(99) == "Type 99","Unknown type IDs retain unambiguous labels")
	check(viewer.control_checks.has("Density-seeded passive tracers (Type 0)"),"Presentation label does not replace legacy type control key")
	var other: Dictionary = layers.states.duplicate(true)
	var environment: Dictionary = before.environment.duplicate(true)
	for name in ["Particle size","Brightness","Exposure","Gamma"]:
		viewer.visual_sliders[name].value += .15
		check(layers.states == other and Visual.snapshot(viewer).environment == environment,"Particle slider owns only particle state: "+name)
	for name in ["Point rendering","Recorded history  [T]","Invert","Show legend"]:
		viewer.control_checks[name].button_pressed = not viewer.control_checks[name].button_pressed
		check(layers.states == other and Visual.snapshot(viewer).environment == environment,"Particle check owns only particle state: "+name)
	for control in [viewer.color_option,viewer.colormap_option,viewer.size_option,viewer.brightness_option,viewer.normalization_option]:
		pick(control,mini(1,control.item_count-1))
		check(layers.states == other and Visual.snapshot(viewer).environment == environment,"Particle option owns only particle state")
	viewer.filter_box.get_child(0).button_pressed = false
	check(viewer.hidden_types.has(0) and not viewer.hidden_types.has(1) and layers.states == other,"Concise filter still targets exact type ID")
	Visual.apply(viewer,before)
	# Each object's real controls must preserve every other object's state and all particle/global state.
	for id in ["volume0","mesh0"]:
		var controls: Dictionary = layers.panel_controls[id]
		var particles := particle_state();var baseline: Dictionary = layers.states.duplicate(true)
		edit(controls.lower,"-0.125");edit(controls.upper,"12.3456789012345")
		pick(controls.channel,1);pick(controls.colormap,1)
		controls.visible.button_pressed = not controls.visible.button_pressed
		if id == "volume0":
			controls.volume.button_pressed = not controls.volume.button_pressed
			controls.strength.value = .75;controls.step.value = .75
			pick(layers.opacity_controls[id].mode,1)
			edit(layers.opacity_controls[id].lower,"0.125");edit(layers.opacity_controls[id].upper,"4.125")
		else:controls.wireframe.button_pressed = true
		check(layers.states[id].channel == controls.channel.get_item_metadata(1) and layers.states[id].colormap == controls.colormap.get_item_text(1) and layers.states[id].visible != baseline[id].visible,"Object channel, colormap and visibility callbacks retained: "+id)
		if id == "volume0":
			check(layers.states[id].opacity == .75 and layers.states[id].step == .75 and not layers.states[id].volume,"Field rendering callbacks retained")
			check(layers.states[id].opacity_mapping == {"mode":"magnitude","lower":.125,"upper":4.125},"Independent field opacity mapping retained")
		else:check(layers.states[id].wireframe,"Mesh wireframe callback retained")
		check(particle_state() == particles,"Object controls leave particle/global state untouched: "+id)
		for key in baseline:
			if key != id:check(layers.states[key] == baseline[key],"Object controls preserve other object "+key)
		check(layers.states[id].lower == -.125 and layers.states[id].upper == 12.3456789012345,"Exact numeric range retained: "+id)
		var valid: Dictionary = layers.states[id].duplicate(true)
		edit(controls.lower,"nan");edit(controls.upper,"-100")
		check(layers.states[id] == valid,"Invalid numeric range still refused: "+id)
		Visual.apply(viewer,before)
	# Enabling a second translucent field must keep its original refusal semantics.
	layers.panel_controls.volume1.visible.button_pressed = true
	check(not layers.states.volume1.visible and not layers.panel_controls.volume1.visible.button_pressed,"Second translucent volume remains refused")
	var fields_before: Dictionary = layers.states.duplicate(true)
	viewer.glow_slider.value = .65
	check(layers.states == fields_before and is_equal_approx(viewer.environment.glow_intensity,viewer.glow_slider.value),"One global Bloom control updates the environment")
	check(not viewer.inspector_box.is_ancestor_of(viewer.glow_slider) and not layers.panel.is_ancestor_of(viewer.glow_slider),"Bloom excluded from every category")
	Visual.apply(viewer,before)
	shell.select_workspace(0)
	viewer.section_buttons.Rendering.button_pressed = false
	viewer.section_buttons["Color Mapping"].button_pressed = false
	viewer.section_buttons["Particle Filters"].button_pressed = true
	viewer.section_buttons["Advanced • Size / Brightness"].button_pressed = true
	await settle();root.get_texture().get_image().save_png(output.path_join("particles-advanced.png"))
	Visual.apply(viewer,before)
	shell.select_workspace(1);layers.choose_object("volume","volume0")
	layers.panel_groups["volume0/Rendering"].button_pressed = false
	layers.panel_groups["volume0/Color Mapping"].button_pressed = false
	await settle();root.get_texture().get_image().save_png(output.path_join("field-opacity.png"))
	layers.panel_groups["volume0/Rendering"].button_pressed = true
	layers.panel_groups["volume0/Color Mapping"].button_pressed = true
	var command: Dictionary = shell.commands.global_effects
	command.popup.id_pressed.emit(command.index)
	check(viewer.tools_ui.window.visible and viewer.tools_ui.current == "Global effects","View opens the global Bloom surface")
	await settle();viewer.tools_ui.window.get_texture().get_image().save_png(output.path_join("global-effects.png"));viewer.tools_ui.close()
	layers.choose_object("volume","volume1");layers.choose_object("mesh","mesh1")
	layers.panel_groups["volume1/Opacity"].button_pressed = false
	Visual.apply(viewer,before)
	check(layers.selected_objects == {"volume":"volume1","mesh":"mesh1"} and not layers.panel_groups["volume1/Opacity"].button_pressed,"Restore preserves session object choices and disclosure states")
	check(Visual.snapshot(viewer) == before,"Recipe restore retains exact values and legacy keys")
	# Missing categories show an empty context, never another category's controls.
	viewer._open_capture(output.path_join("particles.ssc"));layers = viewer.scene_layers
	check(layers.object_choices.volume.disabled and layers.object_choices.mesh.disabled,"Absent field/mesh selectors disabled")
	viewer._open_capture(output.path_join("fields.ssc"));layers = viewer.scene_layers
	shell.select_workspace(0);await settle()
	check(not viewer.inspector_box.visible,"Field-only capture does not show particle controls")
	check(layers.object_choices.mesh.disabled,"Field-only capture has no mesh controls")
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	viewer.free();await process_frame
	print("PANEL: ",checks," checks; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
