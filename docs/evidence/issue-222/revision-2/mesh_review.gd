extends SceneTree
const Viewer = preload("res://main.gd")
var checks := 0
var failures := []
var output := "/tmp/wavez-222-r2"
var layouts := []
func _initialize(): run.call_deferred()
func check(ok, message):
	checks += 1
	if not ok: failures.append(message); push_error(message)
func settle():
	for i in 8: await process_frame
func row_for(parent, caption):
	for child in parent.get_children():
		if child is HBoxContainer and child.get_child_count() == 2 and child.get_child(0) is Label and child.get_child(0).text == caption: return child
		var row = row_for(child,caption)
		if row != null: return row
	return null
func inspect_rows(parent):
	for child in parent.get_children():
		if child is HBoxContainer and child.get_child_count()==2 and child.get_child(0) is Label and (child.get_child(1) is SpinBox or child.get_child(1) is OptionButton):
			var label = child.get_child(0); var edit = child.get_child(1)
			check(label.custom_minimum_size.x == 140, label.text+" aligned label width")
			if child.is_visible_in_tree():
				check(abs(label.get_global_rect().get_center().y-edit.get_global_rect().get_center().y)<2,label.text+" horizontal alignment")
				check(edit.size.x>=100 and edit.get_global_rect().end.x<=child.get_global_rect().end.x+1,label.text+" editor width and bounds")
		inspect_rows(child)
func run():
	create_timer(60).timeout.connect(func():push_error("Review timeout");quit(1))
	var viewer = Viewer.new(); root.add_child(viewer); viewer.set_process(false)
	viewer._open_capture(output.path_join("mixed.wvz")); viewer.playing=false; viewer.orbit_enabled=false
	await settle()
	var tools = viewer.tools_ui
	tools.open("Performance"); await settle()
	var form = tools.form("Performance")
	check(not viewer.scene_layers.mesh_playback.label.is_visible_in_tree() and not viewer.scene_layers.mesh_playback.label.text.is_empty(),"Mesh telemetry is retained but hidden")
	check(tools.window.size.y <= 320,"Mesh-only Performance fits compact content")
	var decoded = row_for(form,"Decoded cache")
	var gpu = row_for(form,"GPU budget")
	check(decoded != null and gpu != null,"Both budget editors share horizontal rows with their labels")
	check(not form.is_ancestor_of(viewer.cache_label) and not viewer.cache_label.is_visible_in_tree(),"Decoded diagnostics absent from normal Performance form")
	check(viewer.shell.source_details().contains(viewer.cache_label.text) and viewer.cache_label.text.contains("Synchronous layer reads"),"Reader diagnostic state retained in File Details")
	var cache_editor = decoded.get_child(1); var gpu_editor = gpu.get_child(1)
	check(cache_editor.suffix=="MiB" and cache_editor.min_value==0 and cache_editor.max_value==2048 and cache_editor.step==64,"Decoded budget units and range unchanged")
	check(gpu_editor.min_value==1 and gpu_editor.max_value==2048 and gpu_editor.step==1 and gpu_editor.tooltip_text.contains("MiB"),"GPU budget range and units unchanged")
	var old_cache = viewer.decoded_cache_mib; var old_gpu = viewer.scene_layers.gpu_budget_mib
	cache_editor.value = 128
	check(viewer.decoded_cache_mib==128 and viewer.generic_reader.cache.limit==128*1048576,"Decoded editor changes authoritative model and reader limit")
	gpu_editor.value=128
	check(viewer.scene_layers.gpu_budget_mib==128,"GPU editor changes authoritative layer budget")
	var clear = tools.find_button(form,"Clear decoded cache")
	check(clear != null,"Clear decoded cache remains available")
	viewer.generic_reader.cache.put(999999, {"sentinel":true}, 16)
	check(viewer.generic_reader.cache.used>0,"Cache seeded before clear")
	clear.pressed.emit()
	check(viewer.generic_reader.cache.used==0 and viewer.generic_reader.cache.limit==128*1048576 and viewer.decoded_cache_mib==128,"Clear empties decoded cache and restores configured budget")
	cache_editor.value=old_cache; gpu_editor.value=old_gpu
	for settings in [[Vector2i(1440,900),1.0,560],[Vector2i(1024,640),1.0,320],[Vector2i(1440,900),1.5,440]]:
		root.content_scale_factor=settings[1]; root.size=settings[0]; await settle()
		tools.open("Performance");tools.window.size.x=settings[2]; await settle()
		inspect_rows(form)
		check(decoded.get_child(1)==cache_editor and gpu.get_child(1)==gpu_editor,"Repeated opening retains original budget controls")
		layouts.append({"window":str(root.size),"scale":root.content_scale_factor,"dialog":str(tools.window.size)})
		tools.window.get_texture().get_image().save_png(output.path_join("performance-"+str(settings[2])+"-scale-"+str(settings[1])+".png"))
	tools.close()
	root.content_scale_factor=1
	viewer._open_capture(output.path_join("mixed.wvz")); await settle();tools.open("Performance");await settle()
	check(row_for(form,"GPU budget")!=null and row_for(form,"Decoded cache").get_child(1)==cache_editor,"Reloaded source gets horizontal layer rows without duplicating decoded editor")
	tools.close(); viewer.free(); await process_frame
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"layouts":layouts},"  "))
	print("Performance review: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
