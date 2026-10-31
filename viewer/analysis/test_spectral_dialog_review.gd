extends SceneTree
## Focused PR #416 owner follow-up: nonmodal placement, retained draft, Cancel.
var viewer
var map
var out := ""
var checks := 0
var failures: Array[String] = []
var observations := {}
var batch_progress := {}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func settle() -> void:
	for i in 5: await process_frame
	RenderingServer.force_draw(false)
func wait_job(seconds := 15.) -> bool:
	var until := Time.get_ticks_msec()+int(seconds*1000.)
	while (not map.pending_id.is_empty() or map.jobs.busy()) and Time.get_ticks_msec() < until:
		await create_timer(.02).timeout
	return map.pending_id.is_empty() and not map.jobs.busy()
func pointer(point: Vector2, pressed: bool, window: Window = root) -> void:
	var event := InputEventMouseButton.new(); event.position = point; event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	window.push_input(event,true)
func click_point(point: Vector2, window: Window = root) -> void:
	pointer(point,true,window); pointer(point,false,window)
func click_control(control: Control) -> void:
	var window := control.get_window()
	var point := control.get_global_rect().get_center()
	if window.is_embedded(): click_point(point+Vector2(window.position))
	else: click_point(point,window)
func key(code: Key, window: Window) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new(); event.keycode = code; event.physical_keycode = code; event.pressed = pressed
		event.window_id = window.get_window_id(); Input.parse_input_event(event)
func drag(delta: Vector2) -> void:
	var point: Vector2 = Vector2(map.window.position)+map.header.get_global_rect().position+Vector2(24,map.header.size.y*.5)
	var hover := InputEventMouseMotion.new(); hover.position = point; hover.global_position = point; root.push_input(hover,true)
	pointer(point,true)
	var motion := InputEventMouseMotion.new(); motion.position = point+delta; motion.global_position = motion.position; motion.relative = delta; motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion,true); pointer(point+delta,false)
func inputs() -> Dictionary:
	return {"arguments":map._request_arguments().duplicate(true),"native_index":map.sample_index.value,"requested_time":map.requested_time,"opacity":map.opacity.value,"palette":map.palette.selected,"show_map":map.visibility.button_pressed,"details":map.details_toggle.button_pressed}
func fits() -> bool:
	var extent := Vector2i(viewer.get_viewport().get_visible_rect().size)
	var position: Vector2i = map.window.position
	return position.x >= 0 and position.y >= ceili(viewer.shell.bar.get_global_rect().end.y) and position.x+map.window.size.x <= extent.x and position.y+map.window.size.y <= extent.y
func picture(name: String) -> void:
	await settle()
	if DisplayServer.get_name() == "headless": return
	root.get_texture().get_image().save_png(out.path_join(name+"-viewport.png"))
	if map.window.visible: map.window.get_texture().get_image().save_png(out.path_join(name+"-dialog.png"))
func preset(name: String) -> bool:
	var route := {"requested":name,"before":viewer.selected_preset,"key_route":"Input.parse_input_event with popup window_id"}
	if not observations.has("preset_routes"): observations.preset_routes = []
	observations.preset_routes.append(route)
	var menu: MenuButton = viewer.shell.menus.View
	click_control(menu); await settle()
	var popup: PopupMenu = menu.get_popup()
	route.view_menu_open = popup.visible
	if not popup.visible: route.failure = "View MenuButton did not open its popup"; return false
	var entry: Dictionary = viewer.shell.commands["preset:"+name]
	for index in popup.item_count:
		var child := popup.get_item_submenu(index)
		if not child.is_empty() and popup.get_node(child) == entry.popup:
			popup.set_focused_item(index); key(KEY_RIGHT,popup); await settle()
			break
	var options: PopupMenu = entry.popup
	route.preset_menu_open = options.visible; route.item_disabled = options.is_item_disabled(entry.index)
	if not options.visible or options.is_item_disabled(entry.index): route.failure = "Preset submenu unavailable"; popup.hide(); return false
	options.set_focused_item(entry.index); key(KEY_ENTER,options); await settle()
	route.after = viewer.selected_preset; route.view_menu_after = popup.visible; route.preset_menu_after = options.visible; route.dialog_open = map.window.visible
	return viewer.selected_preset == name
func finish() -> void:
	if is_instance_valid(viewer):
		map.cancel(); await wait_job(3.); map.close(); viewer._close_capture(); viewer.queue_free(); await settle()
	var report := {"checks":checks,"failures":failures,"observations":observations,"renderer":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name()}
	var file := FileAccess.open(out.path_join("native.json"),FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t",true,true)); file.close()
	print("SPECTRAL DIALOG REVIEW: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	create_timer(90).timeout.connect(func():push_error("Spectral dialog review timed out"); quit(1))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--band-map-output="): out = arg.trim_prefix("--band-map-output=")
	if out.is_empty(): quit(1); return
	viewer = load("res://main.gd").new(); viewer.scene_prebuffer_enabled = false; root.add_child(viewer)
	await settle(); map = viewer.spectral_band_map
	viewer._open_capture(out.path_join("field.wvz")); viewer.playing = false; viewer.orbit_enabled = false; await settle()
	map.open(); map.select_object("field"); map.select_channel("amplitude")
	map.set_grid_xyz([-8,-8,16],[16,16,16],"z",[5,5],[12,12]); map.band_low.text = ".4"; map.band_high.text = ".8"
	viewer.requested_time = 1.; map.pin_playhead(); await settle()
	check(map.window.is_embedded() and not map.window.exclusive,"Spectral form uses the existing embedded nonmodal window")
	check(fits(),"Initial placement leaves toolbar accessible and stays inside viewport")
	check(map.cancel_button.disabled and not map.jobs.busy(),"Cancel is disabled while no request is active")
	click_control(map.compute_button)
	check(not map.pending_id.is_empty() and not map.cancel_button.disabled and map.compute_button.disabled,"Compute enables Cancel only for its pending request")
	check(await wait_job() and not map.result_data.is_empty() and map.result_data.coverage.measured == 9,"Small source batch publishes expected nine measured centers")
	if map.result_data.is_empty(): observations.failure_status = map.status.text; await finish(); return
	check(map.cancel_button.disabled and not map.compute_button.disabled,"Completed computation disables Cancel and restores Compute")
	var result: Dictionary = map.result_data.duplicate(true)
	var source: Dictionary = map.result_source.duplicate(true)
	map.opacity.value = .57; map.palette.select(2); map._presentation_changed()
	var draft := inputs(); var serial: int = map.jobs.serial
	var before: Vector2i = map.window.position
	var camera_before: Transform3D = viewer.camera.transform
	drag(Vector2(-640,24)); await settle()
	check(map.window.position != before and not map.header_dragging,"Actual embedded title drag moves the form and releases drag ownership")
	check(fits() and map.result_data == result and map.result_source == source and viewer.camera.transform == camera_before,"Title dragging preserves numerical results, viewport camera and dialog limits")
	observations.initial_position = [before.x,before.y]; observations.dragged_position = [map.window.position.x,map.window.position.y]
	var positioned: Vector2i = map.window.position; var sized: Vector2i = map.window.size
	map.close(); map.open(); await settle()
	check(map.window.position == positioned and map.window.size == sized,"Closing and reopening retains session placement")
	check(inputs() == draft and map.result_data == result and map.result_source == source,"Closing and reopening retains inputs, presentation and pinned result")
	check(map.jobs.serial == serial and not map.jobs.busy() and map.cancel_button.disabled,"Reopening a completed map starts no work and leaves Cancel disabled")
	check(await preset("Cinematic") and map.window.visible,"Actual View menu selects Cinematic while spectral form stays open")
	check(map.result_data == result and map.result_source == source and inputs() == draft,"Cinematic changes presentation without changing spectral measurements")
	await picture("cinematic-open")
	check(await preset("Scientific") and map.window.visible,"Actual View menu selects Scientific while spectral form stays open")
	check(map.result_data == result and map.jobs.serial == serial,"Preset menu interactions neither recompute nor invalidate the pinned map")
	viewer.shell.appearance.select(true); await settle(); await picture("light-open")
	viewer.shell.appearance.select(false)
	drag(Vector2(-10000,-10000)); await settle()
	check(fits() and not map.header_dragging,"Dragging beyond top/left remains below toolbar and on screen")
	drag(Vector2(10000,10000)); await settle()
	check(fits() and not map.header_dragging,"Dragging beyond bottom/right keeps dialog controls reachable")
	root.size = Vector2i(960,640); await settle(); await settle()
	check(fits() and map.compute_button.get_global_rect().end.y <= map.window.size.y,"Viewport resize refits dialog and retains footer access")
	check(inputs() == draft and map.result_data == result,"Placement and resize preserve retained scientific inputs")
	await picture("compact-refit")
	root.size = Vector2i(1440,900); await settle()
	map.close(); viewer._close_capture()
	check(map.result_data.is_empty() and map.plane.centers_world.is_empty(),"Closing source clears the retained result independently of form close")
	viewer._open_capture(out.path_join("active-batch.wvz")); viewer.playing = false; viewer.orbit_enabled = false; await settle()
	map.open(); map.select_object("field"); map.select_channel("amplitude")
	map.set_grid_xyz([0,0,0],[128,128,128],"z",[8,8],[4,4]); map.band_low.text = ".05"; map.band_high.text = ".15"; await settle()
	map.jobs.spectral_band_map_progress.connect(func(progress):
		if progress.get("id") == map.pending_id and progress.get("stage") == "band_map_centers": batch_progress = progress.duplicate(true))
	click_control(map.compute_button); var active_id: String = map.pending_id
	check(not active_id.is_empty() and not map.cancel_button.disabled,"Actual Compute button enables cancellation for a 64-center batch")
	var until := Time.get_ticks_msec()+15000
	while not map.pending_id.is_empty() and int(batch_progress.get("completed",0)) == 0 and Time.get_ticks_msec() < until: await create_timer(.01).timeout
	var mid_batch: bool = map.pending_id == active_id and int(batch_progress.get("completed",0)) > 0 and int(batch_progress.get("completed",64)) < 64
	check(mid_batch and not map.cancel_button.disabled,"Cancel remains enabled after the worker has measured centers")
	observations.first_measured_progress = batch_progress.duplicate(true)
	if not mid_batch: observations.failure_status = map.status.text; await finish(); return
	await picture("active-cancel")
	observations.cancel_progress = batch_progress.duplicate(true)
	var active_at_click: bool = map.pending_id == active_id and not map.cancel_button.disabled and int(batch_progress.get("completed",64)) < 64
	check(active_at_click,"Batch and Cancel button remain active immediately before the click")
	if not active_at_click: observations.failure_status = map.status.text; await finish(); return
	var began := Time.get_ticks_usec(); click_control(map.cancel_button)
	observations.cancel_callback_ms = (Time.get_ticks_usec()-began)/1000.
	check(map.pending_id.is_empty() and map.cancel_button.disabled and map.result_data.is_empty() and not map.plane.visible,"Actual Cancel button immediately clears publication and disables itself")
	check(await wait_job(3.),"Active batch cancellation is acknowledged within worker grace")
	observations.cancel_ack_ms = (Time.get_ticks_usec()-began)/1000.
	var reply: Dictionary = map.jobs._read("background_result.json")
	check(reply.get("id") == active_id and reply.get("code") == "cancelled" and not reply.has("data"),"Worker confirms mid-batch cancellation without publishing a partial map")
	draft = inputs(); serial = map.jobs.serial; map.close(); map.open(); await settle()
	check(inputs() == draft and map.jobs.serial == serial and map.cancel_button.disabled and map.result_data.is_empty(),"Reopening a cancelled form retains draft without restarting work")
	map.set_grid_xyz([0,0,0],[128,128,128],"z",[1,1],[4,4]); click_control(map.compute_button)
	check(await wait_job() and not map.result_data.is_empty() and map.result_data.coverage.measured == 1 and map.cancel_button.disabled,"Worker and controls recover for a subsequent completed batch")
	await finish()
