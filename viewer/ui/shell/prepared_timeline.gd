extends HSlider
## Read-only CPU readiness overlay. The inherited slider keeps its union-index axis.
const Grid = preload("res://layers/grid_view.gd")
const MeshView = preload("res://layers/mesh_view.gd")
signal seek_requested
var coverage := {"fields":[],"scene":[],"end_ready":false}
var frames: Array = []
var readiness_snapshot := {}
var generation := -1
var axis_signature := ""
var scene_color := preload("res://ui/theme/wavez_tokens.tres").color(&"identity.teal")
var overlay: Control

class CoverageOverlay extends Control:
	func _draw() -> void:
		get_parent().draw_coverage(self)

func _ready() -> void:
	# Match native thumb travel/input to the full-width track and coverage axis.
	add_theme_constant_override("center_grabber",1)
	# Keep the native track outline/focus and thumb, allowing the buffered band
	# to show through its interior instead of appearing as two outside stripes.
	for part in ["slider","grabber_area","grabber_area_highlight"]:
		var style := get_theme_stylebox(part).duplicate() as StyleBoxFlat
		if style != null:
			style.bg_color = Color.TRANSPARENT
			if part != "slider":style.border_color = Color.TRANSPARENT
			add_theme_stylebox_override(part,style)
	overlay = CoverageOverlay.new();overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.show_behind_parent = true;add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(func():overlay.queue_redraw())

static func spans(rows: Array, ready: Dictionary, first: float, last: float, is_static := false) -> Array:
	var result: Array = []
	if is_static:return [[first,last]] if ready.has(0) else []
	# A layer has no presentation before its own first recorded sample.
	if not rows.is_empty() and float(rows[0].time) > first:result.append([first,float(rows[0].time)])
	for i in range(rows.size()):
		if not ready.has(i):continue
		var start: float = rows[i].time
		var end: float = rows[i+1].time if i+1 < rows.size() else last
		if not result.is_empty() and result[-1][1] == start:result[-1][1] = end
		else:result.append([start,end])
	return result

static func intersect(a: Array, b: Array) -> Array:
	var result: Array = [];var i := 0;var j := 0
	while i < a.size() and j < b.size():
		var lo := maxf(a[i][0],b[j][0]);var hi := minf(a[i][1],b[j][1])
		if lo < hi:result.append([lo,hi])
		if a[i][1] < b[j][1]:i += 1
		else:j += 1
	return result

static func axis_position(time: float, samples: Array) -> float:
	if samples.size() < 2:return 0.0
	var lo := 0;var hi := samples.size()-1
	while lo+1 < hi:
		var mid := (lo+hi)/2
		if float(samples[mid].time) <= time:lo = mid
		else:hi = mid
	var fraction := clampf((time-float(samples[lo].time))/(float(samples[hi].time)-float(samples[lo].time)),0,1)
	return (lo+fraction)/(samples.size()-1)

func refresh(viewer, force := false) -> void:
	var next := {"fields":[],"scene":[],"end_ready":false}
	frames = [] if viewer.generic_reader == null else viewer.generic_reader.frames
	generation = viewer.capture_generation
	var next_axis := str(generation)+str(frames.size())+str(viewer.generic_reader.generation if viewer.generic_reader != null else -1)
	if not frames.is_empty() and viewer.scene_layers != null and not viewer.offline_instance:
		var layers = viewer.scene_layers
		var field = layers.field_playback;var particle = layers.playback;var mesh = layers.mesh_playback
		# Query only publication metadata. Never request, pin, upload or prepare.
		# Use the controllers' exact signatures so old source/channel/visibility
		# keys cannot claim readiness before the next controller pump.
		var fields: Dictionary = field.worker.status().charges if field.active() and field.token == field.readiness_signature(layers.field_budget()) and field.worker.token == field.token else {}
		var meshes: Dictionary = mesh.worker.status() if mesh.active() and mesh.token == mesh.readiness_signature(layers.mesh_budget()) and mesh.worker.token == mesh.token else {}
		var particles: Dictionary = {}
		var config: String = JSON.stringify(particle.settings(),"",true,true)
		var source_token := str(layers.reader.generation)+JSON.stringify(layers.reader.source_stamp,"",true,true)
		if particle.enabled and config == particle.config_signature and particle.context.get("token","") == source_token+config and particle.worker.token == source_token+config:
			particles = particle.worker.status()
		var snapshot := {"axis":next_axis,"states":layers.states.duplicate(true),"particle_required":layers.particles_required(),"fields":fields,"meshes":meshes.get("ready_keys",[]),"particles":particles.get("ready_indices",[])}
		# Residency/configuration changes bypass the former 200 ms stale window.
		# Unchanged snapshots avoid walking the complete source sample tables.
		if not force and snapshot == readiness_snapshot:return
		readiness_snapshot = snapshot
		var whole := [[float(frames[0].time),float(frames[-1].time)]]
		next.scene = whole.duplicate(true);next.fields = whole.duplicate(true)
		var has_fields := false;var has_layers := false;var end_ready := true
		for id in layers.states:
			if not layers.states[id].visible:continue
			has_layers = true
			var rows: Array = layers.reader.samples[id];var ready := {}
			if layers.views.get(id) is Grid:
				has_fields = true
				for i in range(rows.size()):
					var key := Grid.sample_key(layers.reader.objects[id],rows[i].sequence,layers.states[id].channel,layers.field_budget())
					if fields.has(key):ready[i] = true
			elif layers.views.get(id) is MeshView:
				var keys := {}
				for key in meshes.get("ready_keys",[]):keys[key] = true
				for i in range(rows.size()):
					var key := "%s/%s/%s/%s/%s" % [id,rows[i].sequence,rows[mini(i+1,rows.size()-1)].sequence,layers.mesh_budget(),JSON.stringify(layers.states[id])]
					if keys.has(key):ready[i] = true
			end_ready = end_ready and ready.has(0 if layers.reader.objects[id].static else rows.size()-1)
			var ranges := spans(rows,ready,frames[0].time,frames[-1].time,layers.reader.objects[id].static)
			next.scene = intersect(next.scene,ranges)
			if layers.views.get(id) is Grid:next.fields = intersect(next.fields,ranges)
		if not layers.particle_id.is_empty() and layers.particles_required():
			has_layers = true
			var ready := {}
			for i in particles.get("ready_indices",[]):ready[i] = true
			var rows: Array = layers.reader.samples[layers.particle_id]
			end_ready = end_ready and ready.has(0 if layers.reader.objects[layers.particle_id].static else rows.size()-1)
			next.scene = intersect(next.scene,spans(rows,ready,frames[0].time,frames[-1].time,layers.reader.objects[layers.particle_id].static))
		if not has_fields:next.fields = []
		if not has_layers:next.scene = []
		next.end_ready = has_layers and end_ready
	else:readiness_snapshot = {}
	if coverage != next or axis_signature != next_axis:
		coverage = next
		axis_signature = next_axis
		if is_instance_valid(overlay):overlay.queue_redraw()

func coverage_geometry() -> Array:
	var result: Array = []
	if frames.size() < 2:return result
	var inset := 0.0 if get_theme_constant("center_grabber") else get_theme_icon("grabber").get_width()*.5
	var width := maxf(0,size.x-inset*2)
	for span in coverage.scene:
		if span[1] <= span[0]:continue
		var left := 0.0 if span[0] <= frames[0].time else inset+axis_position(span[0],frames)*width
		var right := size.x if span[1] >= frames[-1].time else inset+axis_position(span[1],frames)*width
		if span[1] >= frames[-1].time and not coverage.get("end_ready",true):right = maxf(left,right-1.0)
		result.append({"left":left,"right":right,"presence":right-left < 3.0})
	return result

func draw_coverage(canvas: Control) -> void:
	if has_theme_color("prepared_scene"):scene_color = get_theme_color("prepared_scene")
	# Only full required scene readiness has duration on the main track.
	# A detached diamond above it marks subpixel presence, never extra duration.
	for span in coverage_geometry():
		canvas.draw_line(Vector2(span.left,size.y*.5),Vector2(span.right,size.y*.5),scene_color,4)
		if span.presence:
			var x := clampf((span.left+span.right)*.5,3,maxf(3,size.x-3))
			var y := size.y*.5-10
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(x,y-3),Vector2(x+3,y),Vector2(x,y+3),Vector2(x-3,y)]),scene_color)

func playhead_rect() -> Rect2:
	var texture := get_theme_icon("grabber")
	var inset := 0.0 if get_theme_constant("center_grabber") else texture.get_width() * .5
	var fraction := (value - min_value) / (max_value - min_value) if max_value > min_value else 0.0
	return Rect2(Vector2(inset + fraction * (size.x - inset * 2), size.y * .5) - texture.get_size() * .5, texture.get_size()).grow(4)

func _gui_input(event: InputEvent) -> void:
	# Claim only a double-click on the current thumb; native Slider owns scrubbing.
	if editable and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.double_click and playhead_rect().has_point(event.position):
		seek_requested.emit(); accept_event()
