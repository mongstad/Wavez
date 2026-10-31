extends "res://analysis/spatial_spectrum_controller.gd"
## One pinned, verified full-volume reconstruction; ordinary playback stays owned
## by scene_layers. The derived adapter never enters its arrays or caches.
const Adapter = preload("res://analysis/reconstructed_field.gd")
const Grid = preload("res://layers/grid_view.gd")
const OPERATION := "spectral_reconstruct"
const BANDS := ["original","low","intermediate","high"]
var edge_low: SpinBox
var edge_high: SpinBox
var boundary_ack: CheckBox
var presentation_enabled: CheckBox
var band_choice: OptionButton
var lower_range: SpinBox
var upper_range: SpinBox
var opacity: SpinBox
var volume_enabled: CheckBox
var slice_enabled: CheckBox
var clip_enabled: CheckBox
var plane_axis: OptionButton
var plane_position: SpinBox
var legend_panel: PanelContainer
var legend: Label
var reconstructed_view
var signed_lut: Texture2D
var selected_band := "original"
var loaded_band := ""
var transfer := Thread.new()
var adapter
var transfer_revision := -1
var transfer_band := ""
var transfer_result_id := ""
var transfer_metrics := {}
var presentation_suspended := false
var presenting := false
var old_map_suspended := false
var header_dragging := false
var window_placed := false
var observed_source_channel := ""
var observed_source_target := ""
var result_worker_directory := ""

func setup(scene) -> void:
	viewer = scene; jobs = viewer.selection_controller.jobs
	window = Window.new(); window.title = "Spectral reconstruction"; window.transient = true; window.exclusive = false; window.borderless = true
	window.set_meta("viewport_navigation_passthrough",true)
	window.min_size = Vector2i(530,380); window.size = Vector2i(590,720); window.hide(); add_child(window)
	window.close_requested.connect(close)
	window.focus_exited.connect(func(): header_dragging = false; release_keyboard_focus())
	window.gui_focus_changed.connect(func(control: Control):
		if control != null: viewer._clear_manual_navigation())
	window.window_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed: header_dragging = false
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: close())
	viewer.get_viewport().size_changed.connect(_fit_window)
	surface = PanelContainer.new(); window.add_child(surface); surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new(); surface.add_child(margin)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,12)
	var body := VBoxContainer.new(); body.add_theme_constant_override("separation",7); margin.add_child(body)
	var header := HBoxContainer.new(); body.add_child(header); header.mouse_filter = Control.MOUSE_FILTER_STOP; header.mouse_default_cursor_shape = Control.CURSOR_MOVE
	var title := _label(header,"Spectral reconstruction • experimental"); title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var close_button := Button.new(); close_button.text = "Close"; close_button.pressed.connect(close); header.add_child(close_button); header.gui_input.connect(_header_input)
	scroller = ScrollContainer.new(); scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; body.add_child(scroller)
	var content := VBoxContainer.new(); content.size_flags_horizontal = Control.SIZE_EXPAND_FILL; content.add_theme_constant_override("separation",6); scroller.add_child(content)
	_label(content,"Derived signed scalar fields, not optical emission or physical energy. One native sample; full 3D phase retained.")
	var sources := HBoxContainer.new(); content.add_child(sources)
	object_choice = _choice(sources,"Field"); channel_choice = _choice(sources,"Channel")
	object_choice.item_selected.connect(func(i): select_object(str(object_choice.get_item_metadata(i))))
	channel_choice.item_selected.connect(func(i): select_channel(str(channel_choice.get_item_metadata(i))))
	var native_row := HBoxContainer.new(); content.add_child(native_row); _label(native_row,"Native index")
	sample_index = _spin(native_row,0,1000000,0)
	sample_index.value_changed.connect(func(_v):
		if changing: return
		_invalidate("Native sample changed. Compute to verify.")
		var rows := _rows()
		if int(sample_index.value) < rows.size(): requested_time = rows[int(sample_index.value)].time
		_load_sample(false))
	var pin := Button.new(); pin.text = "Use playhead"; pin.pressed.connect(pin_playhead); native_row.add_child(pin)
	context = _label(content,"")
	var edges := HBoxContainer.new(); content.add_child(edges); _label(edges,"Edges • cycles / source length")
	edge_low = _decimal(edges,0,1000000,.125,.001); edge_high = _decimal(edges,0,1000000,.375,.001)
	for control in [edge_low,edge_high]: control.value_changed.connect(_inputs_changed)
	boundary_ack = CheckBox.new(); boundary_ack.text = "Assume this whole volume is periodic"; content.add_child(boundary_ack); boundary_ack.toggled.connect(_inputs_changed)
	support_notice = _label(content,"Hard disjoint radial bands; low includes the mean/DC. No window, mean removal or zero padding. Periodicity is an explicit assumption; edge mismatch can ring.")
	var display_row := HBoxContainer.new(); content.add_child(display_row)
	presentation_enabled = CheckBox.new(); presentation_enabled.text = "Show pinned volume"; presentation_enabled.button_pressed = true; display_row.add_child(presentation_enabled); presentation_enabled.toggled.connect(func(_v): sync_visibility())
	band_choice = _choice(display_row,"View")
	for band in BANDS: band_choice.add_item(band.capitalize())
	band_choice.item_selected.connect(func(i): select_band(BANDS[i]))
	var range_row := HBoxContainer.new(); content.add_child(range_row); _label(range_row,"Symmetric signed range • shared by all views")
	lower_range = _decimal(range_row,-3.4028234663852886e38,3.4028234663852886e38,-1,0.); upper_range = _decimal(range_row,-3.4028234663852886e38,3.4028234663852886e38,1,0.)
	for spin in [lower_range,upper_range]:
		var editor: LineEdit = spin.get_line_edit(); editor.alignment = HORIZONTAL_ALIGNMENT_LEFT
		editor.focus_exited.connect(func(): _reveal_range_starts.call_deferred())
		editor.resized.connect(func(): _reveal_range_starts.call_deferred())
	lower_range.value_changed.connect(_shared_range_changed); upper_range.value_changed.connect(_shared_range_changed)
	var reset_range := Button.new(); reset_range.text = "Use original symmetric range"; reset_range.pressed.connect(_reset_range); content.add_child(reset_range)
	var opacity_row := HBoxContainer.new(); content.add_child(opacity_row); _label(opacity_row,"Volume opacity")
	opacity = _decimal(opacity_row,0,5,.25,.01)
	volume_enabled = CheckBox.new(); volume_enabled.text = "Volume"; volume_enabled.button_pressed = true; opacity_row.add_child(volume_enabled)
	slice_enabled = CheckBox.new(); slice_enabled.text = "Slice"; opacity_row.add_child(slice_enabled)
	var plane_row := HBoxContainer.new(); content.add_child(plane_row)
	clip_enabled = CheckBox.new(); clip_enabled.text = "Clip volume"; plane_row.add_child(clip_enabled)
	plane_axis = _choice(plane_row,"Axis")
	for axis in ["X","Y","Z"]: plane_axis.add_item(axis)
	plane_axis.select(2); plane_axis.item_selected.connect(func(_i): _center_plane())
	plane_position = _decimal(plane_row,-1e12,1e12,0,.1)
	_label(content,"Slice and clipping share the selected world-coordinate plane. Opacity uses magnitude; blue = negative, white = zero, red = positive. Source probes are unavailable while this view is shown. Camera and Scientific/Cinematic controls remain available.")
	var details_toggle := CheckButton.new(); details_toggle.text = "Source, numerical checks and transfer timings"; content.add_child(details_toggle)
	geometry_detail = _label(content,""); geometry_detail.hide(); details_toggle.toggled.connect(func(v): geometry_detail.visible = v)
	status = _label(body,"Choose a native field sample and acknowledge the periodic boundary assumption.")
	var actions := HBoxContainer.new(); actions.alignment = BoxContainer.ALIGNMENT_END; body.add_child(actions)
	compute_button = Button.new(); compute_button.text = "Compute"; compute_button.pressed.connect(compute); actions.add_child(compute_button)
	cancel_button = Button.new(); cancel_button.text = "Cancel"; cancel_button.disabled = true; cancel_button.pressed.connect(cancel); actions.add_child(cancel_button)
	reconstructed_view = Grid.new(); add_child(reconstructed_view); reconstructed_view.setup(viewer.camera); reconstructed_view.clear()
	var canvas := CanvasLayer.new(); canvas.layer = 3; add_child(canvas)
	legend_panel = PanelContainer.new(); legend_panel.position = Vector2(18,88); legend_panel.custom_minimum_size = Vector2(330,0); legend_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE; canvas.add_child(legend_panel)
	var legend_margin := MarginContainer.new(); legend_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE; legend_panel.add_child(legend_margin)
	for side in ["left","right","top","bottom"]: legend_margin.add_theme_constant_override("margin_"+side,10)
	var legend_body := VBoxContainer.new(); legend_body.mouse_filter = Control.MOUSE_FILTER_IGNORE; legend_margin.add_child(legend_body)
	legend = _label(legend_body,""); legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var image := Image.create(256,1,false,Image.FORMAT_RGB8)
	for i in 256:
		var value := i/255.0
		image.set_pixel(i,0,Color(.12,.25,.8).lerp(Color(.94,.94,.94),value*2.) if value < .5 else Color(.94,.94,.94).lerp(Color(.8,.12,.08),(value-.5)*2.))
	signed_lut = ImageTexture.create_from_image(image)
	var gradient := TextureRect.new(); gradient.texture = signed_lut; gradient.custom_minimum_size.y = 10; gradient.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; gradient.mouse_filter = Control.MOUSE_FILTER_IGNORE; legend_body.add_child(gradient); legend_panel.hide()
	jobs.spectral_reconstruction_completed.connect(_completed); jobs.spectral_reconstruction_failed.connect(_failed); jobs.spectral_reconstruction_progress.connect(_progress)
	RenderingServer.frame_pre_draw.connect(sync_visibility); set_process(not viewer.offline_instance)

func _decimal(parent: Node, low: float, high: float, value: float, increment: float) -> SpinBox:
	var spin := SpinBox.new(); spin.min_value = low; spin.max_value = high; spin.step = increment; spin.value = value; spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL; parent.add_child(spin); return spin

func open() -> void:
	viewer._clear_manual_navigation()
	var focus: Control = viewer.get_viewport().gui_get_focus_owner()
	if focus != null: previous_focus = weakref(focus)
	if _fingerprint() != source_fingerprint or current_object.is_empty(): _bind_current()
	window.theme = viewer.shell.style_slice.theme; legend_panel.theme = window.theme
	var style = viewer.shell.style_slice.theme.flat_box(&"surface.1",0,0,0)
	surface.add_theme_stylebox_override("panel",style); legend_panel.add_theme_stylebox_override("panel",style)
	if not window_placed:
		var extent := Vector2i(viewer.get_viewport().get_visible_rect().size)
		var offset := Vector2i(maxi(12,extent.x-window.size.x-16),_menu_bottom())
		window.position = offset if window.is_embedded() else viewer.get_window().position+offset; window_placed = true
	window.show(); _fit_window(); refresh_context()

func _menu_bottom() -> int:
	return int(ceil(viewer.shell.bar.get_global_rect().end.y))+8

func _fit_window() -> void:
	if not window.visible: return
	var extent := Vector2i(viewer.get_viewport().get_visible_rect().size)
	window.size = Vector2i(mini(590,maxi(530,extent.x-32)),mini(720,maxi(380,extent.y-_menu_bottom()-16)))
	if window.is_embedded(): _clamp_window()

func _clamp_window() -> void:
	var extent := Vector2i(viewer.get_viewport().get_visible_rect().size)
	window.position = Vector2i(clampi(window.position.x,8,maxi(8,extent.x-window.size.x-8)),clampi(window.position.y,_menu_bottom(),maxi(_menu_bottom(),extent.y-window.size.y-8)))

func _header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		header_dragging = event.pressed
		if event.pressed and not window.is_embedded() and DisplayServer.has_feature(DisplayServer.FEATURE_WINDOW_DRAG): DisplayServer.window_start_drag(window.get_window_id())
	elif event is InputEventMouseMotion and header_dragging and window.is_embedded():
		if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0: header_dragging = false; return
		window.position += Vector2i(event.relative); _clamp_window()

func close() -> void:
	header_dragging = false; release_keyboard_focus(); clear_result(); window.hide()
	if previous_focus != null:
		var focus = previous_focus.get_ref()
		if is_instance_valid(focus) and focus.is_visible_in_tree(): focus.grab_focus()

func owns_keyboard_input() -> bool:
	# Embedded/native Windows keep their own GUI focus, separate from the root
	# viewport queried by the existing camera controls.
	return window.visible and window.gui_get_focus_owner() != null

func release_keyboard_focus() -> void:
	var focused := window.gui_get_focus_owner()
	if focused != null: focused.release_focus()

func pin_playhead(_default_region := false) -> void:
	super.pin_playhead(false)
	observed_source_channel = _source_channel()

func _inputs_changed(_value = null) -> void:
	if changing: return
	_invalidate("Reconstruction inputs changed. Compute to verify."); refresh_context()

func _source_channel() -> String:
	if viewer.scene_layers == null: return ""
	return str(viewer.scene_layers.states.get(current_object,{}).get("channel",""))

func _source_target() -> String:
	if viewer.scene_layers == null: return ""
	return JSON.stringify([viewer.scene_layers.selected_volume,viewer.scene_layers.selected_objects.get("volume","")])

func _source_stamp_matches(data: Dictionary) -> bool:
	var stamp = data.get("source_stamp")
	if not stamp is Dictionary: return false
	var current := preload("res://data/source_stamp.gd").read(ProjectSettings.globalize_path(viewer.capture_path))
	if current.is_empty(): return false
	if not request_context.is_empty() and current != request_context.get("source_stamp",{}): return false
	for key in ["device","inode","size"]:
		if stamp.get(key) != current.get(key): return false
	for key in ["mtime","ctime"]:
		var ns: String = str(stamp.get(key+"_ns",""))
		if not ns.is_valid_int() or ns.length() < 10: return false
		if ns.substr(0,ns.length()-9)+"."+ns.right(9) != current.get(key): return false
	return true

func _request_arguments() -> Dictionary:
	if current_channel.is_empty() or channel_choice.selected < 0 or geometry.is_empty() or not boundary_ack.button_pressed or edge_low.value <= 0 or edge_high.value <= edge_low.value: return {}
	return {"object":current_object,"channel":current_channel,"index":int(sample_index.value),"boundary":"periodic","edges":[edge_low.value,edge_high.value]}

func compute() -> void:
	if _fingerprint() != source_fingerprint: _bind_current(); status.text = "Source changed. Review the native sample before computing."; return
	if viewer.generic_reader.source_stamp.is_empty() or viewer.generic_reader._source_stamp_profiled() != viewer.generic_reader.source_stamp:
		reset_source(); status.text = "Source identity changed or is unavailable. Let the source refresh, then reopen this panel before computing."; return
	if transfer.is_started(): status.text = "Wait for the current display transfer to finish or cancel it."; return
	if jobs.busy() or not jobs.foreground_cancel_id.is_empty(): status.text = "The analysis worker is busy. Wait or cancel its current job in Jobs."; return
	if viewer.scene_layers != null and viewer.scene_layers.iso_pid > 0: status.text = "Wait for surface extraction before source analysis."; return
	var headroom := preload("res://layers/playback_buffer.gd").memory_headroom()
	if headroom.available_physical < headroom.reserve+1073741824+256*1048576: status.text = "Reconstruction paused to preserve physical RAM headroom for its 1 GiB worker budget and viewer transfer."; return
	var args := _request_arguments()
	if args.is_empty(): status.text = "Choose a recorded channel, positive ordered band edges and the periodic boundary assumption."; return
	_invalidate(""); observed_source_channel = _source_channel(); observed_source_target = _source_target()
	request_selection_revision = viewer.selection_controller.state.revision
	var binding := {"path":ProjectSettings.globalize_path(viewer.capture_path),"committed_bytes":str(viewer.generic_reader.scan_offset)}
	if verified_source.has("sha256"): binding.sha256 = verified_source.sha256
	request_context = {"fingerprint":source_fingerprint,"source":binding.duplicate(true),"source_stamp":viewer.generic_reader.source_stamp.duplicate(true),"arguments":args.duplicate(true),"index":int(sample_index.value),"geometry":geometry.duplicate(true),"revision":revision,"selection":request_selection_revision}
	request_started_usec = Time.get_ticks_usec(); viewer.selection_controller.temporal.update_pins()
	pending_id = jobs.request_background(binding,OPERATION,args,viewer.capture_generation,request_selection_revision,revision,{"memory_bytes":1073741824})
	status.text = "Verifying native source and reconstructing full 3D bands…" if not pending_id.is_empty() else jobs.error
	refresh_context()

func cancel() -> void:
	_invalidate("Reconstruction cancelled. No derived result published."); refresh_context()

func clear_result() -> void:
	_invalidate("Pinned reconstruction cleared; ordinary live source restored."); refresh_context()

func _invalidate(message: String) -> void:
	if not pending_id.is_empty() and jobs.background_operation == OPERATION and jobs.background_id == pending_id: jobs.cancel_background()
	if adapter != null: adapter.cancel()
	_release_artifacts(result_data)
	pending_id = ""; revision += 1; request_context.clear(); result_data.clear(); result_source.clear(); transfer_metrics.clear(); loaded_band = ""; result_worker_directory = ""
	if reconstructed_view != null: reconstructed_view.clear()
	_release_presentation()
	if status != null and not message.is_empty(): status.text = message

func _release_artifacts(data) -> void:
	if data is Dictionary and data.get("manifest") is Dictionary:
		jobs._write("reconstruction_release.json",{"manifest":str(data.manifest.get("path",""))})

func reset_source() -> void:
	_invalidate("Source changed or closed. Select a native field sample.")
	verified_source.clear(); source_fingerprint = ""; geometry.clear(); descriptor.clear(); current_object = ""; current_channel = ""; observed_source_channel = ""
	if object_choice != null: object_choice.clear(); channel_choice.clear(); refresh_context()

func _completed(result: Dictionary) -> void:
	if pending_id.is_empty() or result.get("id") != pending_id: return
	if request_context.is_empty() or _fingerprint() != request_context.fingerprint or revision != request_context.revision or viewer.selection_controller.state.revision != request_context.selection:
		_release_artifacts(result.get("data")); _invalidate("Superseded reconstruction discarded."); refresh_context(); return
	var data = result.get("data"); var binding = result.get("source")
	if not _valid_result(data,binding): _release_artifacts(data); _invalidate("Invalid reconstructed result refused."); refresh_context(); return
	if float(data.common_range[1]) > upper_range.max_value:
		_release_artifacts(data); _invalidate("Source extrema exceed the float32 display range. No clamped reconstruction was shown."); refresh_context(); return
	pending_id = ""; result_data = data.duplicate(true); result_source = binding.duplicate(true); verified_source = binding.duplicate(true); result_worker_directory = str(jobs.directory)
	publication_msec = (Time.get_ticks_usec()-request_started_usec)/1000.0
	_reset_range(); _center_plane(); presentation_enabled.set_pressed_no_signal(true)
	status.text = "Verified native reconstruction ready; checking display artifact…"; select_band(selected_band); refresh_context()

func _valid_result(data, binding) -> bool:
	if not data is Dictionary or not binding is Dictionary: return false
	if data.get("kind") != "spectral_reconstruction" or data.get("version") != 1 or data.get("object") != current_object or data.get("channel") != current_channel or data.get("boundary") != "periodic": return false
	if not data.get("record") is Dictionary or not _same_number(data.record.get("index"),request_context.index): return false
	if not Index.valid_hex(binding.get("sha256"),64) or binding.get("committed_bytes") != request_context.source.committed_bytes or str(binding.get("path","")).simplify_path() != str(request_context.source.path).simplify_path(): return false
	if request_context.source.has("sha256") and binding.sha256 != request_context.source.sha256: return false
	if not data.get("source") is Dictionary: return false
	for key in ["path","committed_bytes","sha256"]:
		if data.source.get(key) != binding.get(key): return false
	var native := Exact.exact_float(data.record.get("native_time")); var rows := _rows()
	if native.is_empty() or request_context.index >= rows.size() or native.value != rows[request_context.index].time: return false
	if not data.get("geometry") is Dictionary or not _numeric_array_matches(data.get("edges"),request_context.arguments.edges): return false
	for key in ["shape","origin","spacing","data_to_world"]:
		if not _numeric_array_matches(data.geometry.get(key),request_context.geometry.get(key)): return false
	if data.geometry.get("centering") != request_context.geometry.get("centering") or not data.geometry.get("centering") in ["cell","node"]: return false
	if not data.get("units") is Dictionary or not data.get("common_range") is Array or data.common_range.size() != 2: return false
	for bound in data.common_range:
		if not (bound is int or bound is float) or not is_finite(bound): return false
	if data.common_range[0] > data.common_range[1] or data.common_range[0] != -data.common_range[1]: return false
	if not data.get("artifacts") is Dictionary or not data.artifacts.has_all(BANDS) or not data.get("manifest") is Dictionary: return false
	return _source_stamp_matches(data)

func select_band(band: String) -> void:
	if band not in BANDS: return
	selected_band = band; band_choice.select(BANDS.find(band))
	if result_data.is_empty(): return
	if jobs.worker_pid <= 0 or jobs.directory != result_worker_directory: _invalidate("The reconstruction worker ended. Compute again to verify this sample."); refresh_context(); return
	if transfer.is_started():
		adapter.cancel(); return # _process starts the newest selection after join.
	if loaded_band == band: sync_visibility(); return
	reconstructed_view.clear(); loaded_band = ""; _release_presentation()
	var bytes := int(result_data.artifacts[band].get("bytes",0))
	if bytes <= 0 or bytes > Adapter.MAX_CELLS*4 or _ordinary_gpu_bytes()+bytes > int(viewer.scene_layers.gpu_budget_mib)*1048576:
		status.text = "Full-resolution reconstruction exceeds the available texture budget. No LOD substitute was loaded."; return
	adapter = Adapter.new(); transfer_revision = revision; transfer_band = band; transfer_result_id = str(result_data.manifest.get("path",""))
	var error := transfer.start(adapter.prepare.bind(result_data.duplicate(true),band,str(jobs.directory)))
	if error != OK: status.text = "Cannot start reconstructed field transfer."; return
	status.text = "Validating %s artifact, finite float32 samples and SHA-256…" % band; refresh_context()

func _ordinary_gpu_bytes() -> int:
	var bytes := 0
	if viewer.scene_layers == null: return bytes
	for view in viewer.scene_layers.views.values():
		bytes += view.gpu_bytes
	if is_instance_valid(viewer.scene_layers.iso_node): bytes += viewer.scene_layers.iso_node.gpu_bytes
	# Ordinary playback may retain one staged texture per field as well.
	return bytes*2 if viewer.scene_layers.field_playback != null and viewer.scene_layers.field_playback.enabled else bytes

func _publish_transfer(prepared: Dictionary) -> void:
	if transfer_revision != revision or result_data.is_empty(): return
	if transfer_band != selected_band: select_band(selected_band); return
	if prepared.is_empty(): select_band(selected_band); return
	if prepared.has("error"): _invalidate(str(prepared.error)); refresh_context(); return
	if jobs.worker_pid <= 0 or jobs.directory != result_worker_directory or _fingerprint() != source_fingerprint or _source_channel() != observed_source_channel or _source_target() != observed_source_target or not _source_stamp_matches(result_data): _invalidate("Source or worker ownership changed during display transfer."); return
	if _ordinary_gpu_bytes()+int(prepared.gpu_bytes) > int(viewer.scene_layers.gpu_budget_mib)*1048576: status.text = "Texture budget changed; full-resolution publication refused."; return
	var started := Time.get_ticks_usec()
	var ready := Grid.upload(prepared)
	transfer_metrics = prepared.timings.duplicate(); transfer_metrics.gpu_upload_ms = (Time.get_ticks_usec()-started)/1000.0; transfer_metrics.gpu_bytes = prepared.gpu_bytes; transfer_metrics.ordinary_gpu_bytes_reserved = _ordinary_gpu_bytes()
	if ready.has("error"): status.text = ready.error; return
	var obj := {"id":"derived:"+transfer_result_id+":"+transfer_band,"data_to_world":result_data.geometry.data_to_world}
	var sample := {"sequence":int(result_data.record.sequence),"geometry":result_data.geometry,"channels":{},"time":Exact.exact_float(result_data.record.native_time).value}
	if not reconstructed_view.load_sample(obj,sample,current_channel,int(prepared.gpu_bytes),ready): status.text = reconstructed_view.error; return
	loaded_band = transfer_band; status.text = "Pinned %s ready at full resolution. Playback changes the playhead, not this volume." % loaded_band.capitalize(); sync_visibility(); refresh_context()

func _reset_range() -> void:
	if result_data.is_empty(): return
	var zero: bool = result_data.common_range[0] == 0 and result_data.common_range[1] == 0
	lower_range.set_value_no_signal(-1. if zero else result_data.common_range[0]); upper_range.set_value_no_signal(1. if zero else result_data.common_range[1]); _reveal_range_starts.call_deferred(); sync_visibility()

func _shared_range_changed(value: float) -> void:
	# Keep zero at the diverging LUT midpoint for every manually chosen range.
	lower_range.set_value_no_signal(-absf(value)); upper_range.set_value_no_signal(absf(value)); _reveal_range_starts.call_deferred(); sync_visibility()

func _reveal_range_starts() -> void:
	# Keep the sign and leading integer visible in narrow fields without
	# quantizing the exact shared range or disturbing an active text edit.
	for spin in [lower_range,upper_range]:
		var editor: LineEdit = spin.get_line_edit()
		if not editor.has_focus(): editor.caret_column = 0

func _center_plane() -> void:
	if geometry.is_empty(): return
	var axis := plane_axis.selected
	var transform := preload("res://layers/scene_reader.gd").transform_of(geometry.data_to_world)
	var center := transform*(preload("res://layers/scene_reader.gd").vec(geometry.origin)+preload("res://layers/scene_reader.gd").vec(geometry.spacing)*Vector3(float(geometry.shape[2]-1),float(geometry.shape[1]-1),float(geometry.shape[0]-1))*.5)
	plane_position.set_value_no_signal(center[axis])

func display_state() -> Dictionary:
	var normal := [0.,0.,0.]; normal[plane_axis.selected] = 1.
	var color_mapping: Dictionary = preload("res://layers/volume_color.gd").DEFAULT.duplicate(); color_mapping.policy = "symmetric"
	return {"visible":true,"volume":volume_enabled.button_pressed,"slice":slice_enabled.button_pressed,"lower":lower_range.value,"upper":upper_range.value,"opacity":opacity.value,"step":float(geometry.spacing.min())*.5,"clip":clip_enabled.button_pressed,"clip_normal":normal,"clip_distance":plane_position.value,"slice_normal":normal,"slice_distance":plane_position.value,"color_mapping":color_mapping,"opacity_mapping":{"mode":"magnitude","lower":0.,"upper":maxf(absf(lower_range.value),absf(upper_range.value))}}

func active() -> bool:
	return not result_data.is_empty() and not loaded_band.is_empty() and reconstructed_view.texture != null and presentation_enabled.button_pressed and not presentation_suspended and not viewer.offline_instance and not viewer.inspection_busy

func sync_visibility() -> void:
	if reconstructed_view == null: return
	if not active(): _release_presentation(); return
	# Fresh high-resolution stat guards request, acceptance and upload. Steady
	# rendering uses the reader's ordinary source poll; never launch a blocking
	# stat subprocess for every playback frame. External mutation is therefore
	# detected at the normal source refresh boundary (nominally once per second).
	if jobs.worker_pid <= 0 or jobs.directory != result_worker_directory or _fingerprint() != source_fingerprint or _source_channel() != observed_source_channel or _source_target() != observed_source_target or viewer.selection_controller.state.revision != request_selection_revision:
		_invalidate("Source identity or field/channel target changed. Pinned reconstruction released."); refresh_context(); return
	var state := display_state()
	var span := PackedFloat32Array([state.upper-state.lower])
	if not preload("res://layers/volume_color.gd").validate(state).is_empty() or not preload("res://layers/volume_opacity.gd").validate(state.opacity_mapping).is_empty() or not is_finite(span[0]) or span[0] < 1e-38:
		_release_presentation(); status.text = "Choose finite symmetric signed bounds with a float32 span and magnitude threshold at least 1e-38; this range cannot be rendered accurately."; return
	if not presenting:
		presenting = true
		if viewer.spectral_band_map != null:
			old_map_suspended = viewer.spectral_band_map.presentation_suspended; viewer.spectral_band_map.suspend_presentation()
	reconstructed_view.apply(state,signed_lut)
	for view in viewer.scene_layers.views.values():
		if view is Grid: view.quad.hide(); view.slice.hide()
	if is_instance_valid(viewer.scene_layers.iso_node): viewer.scene_layers.iso_node.hide()
	if is_instance_valid(viewer.scene_layers.probe_marker): viewer.scene_layers.probe_marker.hide()
	# Ordinary source legend cards must not label the derived field.
	viewer.shell.layer_legends.hide()
	legend_panel.show(); _update_legend()

func _release_presentation() -> void:
	if reconstructed_view != null: reconstructed_view.quad.hide(); reconstructed_view.slice.hide()
	if legend_panel != null: legend_panel.hide()
	if not presenting: return
	presenting = false
	if viewer.scene_layers != null:
		for id in viewer.scene_layers.views:
			var view = viewer.scene_layers.views[id]
			if view is Grid: view.apply(viewer.scene_layers.states[id],viewer.scene_layers.lut(viewer.scene_layers.states[id].colormap))
		viewer.scene_layers.set_probe_marker_enabled(viewer.scene_layers.probe_marker_enabled)
		if is_instance_valid(viewer.scene_layers.iso_node) and not viewer.scene_layers.iso_finished_target.is_empty():
			viewer.scene_layers.iso_node.visible = viewer.scene_layers.iso_target == viewer.scene_layers.iso_finished_target and not viewer.scene_layers.iso_result.is_empty()
		viewer.shell.layer_legends.sync()
	if viewer.spectral_band_map != null and not old_map_suspended: viewer.spectral_band_map.restore_presentation()

func suspend_presentation() -> bool:
	var previous := presentation_suspended; presentation_suspended = true; _release_presentation(); return previous

func restore_presentation(previous := false) -> void:
	presentation_suspended = previous; sync_visibility()

func _update_legend() -> void:
	if result_data.is_empty(): return
	var native := Exact.exact_float(result_data.record.native_time)
	var low := str(result_data.edges[0]); var high := str(result_data.edges[1])
	var band_text := "All frequencies, same verified original" if loaded_band == "original" else "0 ≤ f < "+low+" (includes DC / mean)" if loaded_band == "low" else low+" ≤ f < "+high if loaded_band == "intermediate" else "f ≥ "+high
	var range_kind := "original symmetric" if lower_range.value == result_data.common_range[0] and upper_range.value == result_data.common_range[1] else "manual shared"
	if result_data.common_range[0] == 0 and result_data.common_range[1] == 0 and lower_range.value == -1 and upper_range.value == 1: range_kind = "zero-field display fallback; true range [0, 0]"
	legend.text = "PINNED • %s • %s / %s\nNative %s; playhead %s\n%s [%s]\nPeriodic whole volume; hard radial bands.\nSigned range %s … %s [%s] • %s\nBlue − / white 0 / red +; magnitude opacity.\nDerived analysis, not optical light or energy.\nFull-resolution float32 display; float64 calculations." % [loaded_band.capitalize(),current_object,current_channel,str(native.value),str(viewer.requested_time),band_text,str(result_data.units.get("frequency","cycles / source length")),str(lower_range.value),str(upper_range.value),str(result_data.units.get("value","unknown")),range_kind]

func refresh_context() -> void:
	if compute_button == null: return
	compute_button.disabled = current_object.is_empty() or geometry.is_empty() or not pending_id.is_empty() or transfer.is_started() or not jobs.background_cancel_id.is_empty()
	cancel_button.disabled = pending_id.is_empty() and not transfer.is_started()
	var rows := _rows(); var index := int(sample_index.value)
	context.text = "No native field sample selected."
	if index >= 0 and index < rows.size(): context.text = "%s • native %s; playhead %s." % ["Pinned result" if not result_data.is_empty() else "Input draft",str(rows[index].time),str(viewer.requested_time)]
	geometry_detail.text = "Native geometry (shape ZYX; spacing/origin XYZ): "+JSON.stringify(geometry,"",true,true)
	if not result_data.is_empty():
		geometry_detail.text += "\nSource SHA-256: %s\nVerified prefix: %s bytes\nFloat64 numerical checks: %s\nWorker timings: %s\nDisplay transfer: %s\nOne active derived texture; ordinary playback textures/cache retained. Display artifacts do not replace numerical source values." % [result_source.sha256,result_source.committed_bytes,JSON.stringify(result_data.get("metrics",{}),"",true,true),JSON.stringify(result_data.get("timings",{}),"",true,true),JSON.stringify(transfer_metrics,"",true,true)]
	_update_legend()

func _process(delta: float) -> void:
	if transfer.is_started() and not transfer.is_alive():
		var prepared = transfer.wait_to_finish(); adapter = null
		_publish_transfer(prepared if prepared is Dictionary else {}); refresh_context()
	elapsed += delta
	if elapsed < .1: return
	elapsed = 0
	if not source_fingerprint.is_empty() and _fingerprint() != source_fingerprint: reset_source(); return
	if not result_data.is_empty() and (jobs.worker_pid <= 0 or jobs.directory != result_worker_directory): _invalidate("The reconstruction worker ended. Compute again to verify this sample."); refresh_context(); return
	if (not result_data.is_empty() or not pending_id.is_empty()) and (_source_channel() != observed_source_channel or _source_target() != observed_source_target or viewer.selection_controller.state.revision != request_selection_revision): _invalidate("Source field/channel or selection changed. Compute again to verify."); refresh_context(); return
	if not pending_id.is_empty() and (jobs.background_operation != OPERATION or (not jobs.background_pending and jobs.background_id != pending_id)): _invalidate("Worker request changed. Reconstruction discarded.")
	if window.visible or active(): refresh_context()

func _exit_tree() -> void:
	if adapter != null: adapter.cancel()
	if transfer.is_started(): transfer.wait_to_finish()
