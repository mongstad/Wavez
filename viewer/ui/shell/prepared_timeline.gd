extends HSlider
## Read-only CPU readiness overlay. The inherited slider keeps its union-index axis.
const Grid = preload("res://layers/grid_view.gd")
const MeshView = preload("res://layers/mesh_view.gd")
var coverage := {"fields":[],"scene":[]}
var frames: Array = []
var checked_ms := -1000
var generation := -1
var axis_signature := ""
var field_color := preload("res://ui/theme/simscope_tokens.tres").color(&"accent.primary")
var scene_color := preload("res://ui/theme/simscope_tokens.tres").color(&"identity.teal")
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

static func spans(rows: Array, ready: Dictionary, first: float, last: float) -> Array:
	var result: Array = []
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
	if not force and generation == viewer.capture_generation and Time.get_ticks_msec()-checked_ms < 200:return
	checked_ms = Time.get_ticks_msec();generation = viewer.capture_generation
	var next := {"fields":[],"scene":[]}
	frames = [] if viewer.generic_reader == null else viewer.generic_reader.frames
	var next_axis := str(generation)+str(frames.size())+str(viewer.generic_reader.generation if viewer.generic_reader != null else -1)
	if not frames.is_empty() and viewer.scene_layers != null and not viewer.offline_instance:
		var layers = viewer.scene_layers
		var whole := [[float(frames[0].time),float(frames[-1].time)]]
		next.scene = whole.duplicate(true);next.fields = whole.duplicate(true)
		var has_fields := false;var has_layers := false
		var fields: Dictionary = layers.field_playback.worker.status().charges if layers.field_playback.active() else {}
		var particles: Dictionary = layers.playback.worker.status() if layers.playback.enabled else {}
		var meshes: Dictionary = layers.mesh_playback.worker.status() if layers.mesh_playback.active() else {}
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
			var ranges := spans(rows,ready,frames[0].time,frames[-1].time)
			next.scene = intersect(next.scene,ranges)
			if layers.views.get(id) is Grid:next.fields = intersect(next.fields,ranges)
		# Particles use their own controller and are not entries in layers.states.
		if not layers.particle_id.is_empty() and layers.particles_required():
			has_layers = true
			var ready := {}
			var config: String = JSON.stringify(layers.playback.settings(),"",true,true)
			if config == layers.playback.config_signature and layers.playback.source_generation == layers.reader.generation:
				for i in particles.get("ready_indices",[]):ready[i] = true
			next.scene = intersect(next.scene,spans(layers.reader.samples[layers.particle_id],ready,frames[0].time,frames[-1].time))
		if not has_fields:next.fields = []
		if not has_layers:next.scene = []
	if coverage != next or axis_signature != next_axis:
		coverage = next
		axis_signature = next_axis
		if is_instance_valid(overlay):overlay.queue_redraw()

func draw_coverage(canvas: Control) -> void:
	if frames.size() < 2:return
	var grabber := get_theme_icon("grabber")
	var inset := 0.0 if get_theme_constant("center_grabber") else grabber.get_width()*.5
	var width := maxf(0,size.x-inset*2)
	# One band behind the native groove and grabber. Teal overrides blue only
	# where all visible layers are prepared; there is no second buffer bar.
	for row in [["fields",field_color],["scene",scene_color]]:
		for span in coverage[row[0]]:
			var left := 0.0 if span[0] <= frames[0].time else inset+axis_position(span[0],frames)*width
			var right := size.x if span[1] >= frames[-1].time else inset+axis_position(span[1],frames)*width
			canvas.draw_line(Vector2(left,size.y*.5),Vector2(right,size.y*.5),row[1],4)
