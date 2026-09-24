extends ScrollContainer
## Presentation-only collection. Rendering controllers own eligibility and ranges.
var viewer
var stack := VBoxContainer.new()
var entries := {}
var available := Vector2.ZERO
var bottom := 0.0

func setup(owner_viewer) -> void:
	viewer = owner_viewer
	theme = viewer.shell.theme
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = "Layer color legends. Scroll to see additional enabled layers."
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 12)
	add_child(stack)
	stack.minimum_size_changed.connect(arrange)
	hide()

func sync() -> void:
	var active := {}
	var order := 0
	var layers = viewer.scene_layers
	if layers != null:
		for info in layers.layer_samples:
			var id: String = info.id
			if info.kind == "particles" or not info.visible or info.status in ["hidden", "unavailable"]: continue
			if not layers.legend_visibility.get(id, true): continue
			var state: Dictionary = layers.states[id]
			if state.channel.is_empty(): continue
			var view = layers.views[id]
			if info.kind == "volume" and not (view.quad.visible or view.slice.visible): continue
			if info.kind == "mesh" and not view.visible: continue
			active[id] = true
			if not entries.has(id):
				var card := PanelContainer.new()
				card.add_theme_stylebox_override("panel", viewer.shell.theme.box(&"surface.1", &"border.subtle", 8, 6))
				var body := VBoxContainer.new(); card.add_child(body)
				var bar := TextureRect.new()
				bar.custom_minimum_size = Vector2(324,18)
				bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var label := Label.new()
				label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				label.mouse_filter = Control.MOUSE_FILTER_IGNORE
				body.add_child(bar); body.add_child(label); stack.add_child(card)
				entries[id] = {"card":card,"bar":bar,"label":label}
			var entry: Dictionary = entries[id]
			stack.move_child(entry.card,order); order += 1
			entry.bar.texture = layers.lut(state.colormap)
			var mapping: String = layers.ColorMapping.resolve(state).normalization if info.kind == "volume" else "linear"
			entry.label.text = "%s • %s\n%s • %s\n%s → %s • %s" % ["Field" if info.kind == "volume" else "Mesh", id, state.channel, state.colormap, str(state.lower), str(state.upper), mapping]
			entry.card.tooltip_text = entry.label.text
	for id in entries.keys():
		if not active.has(id):
			stack.remove_child(entries[id].card); entries[id].card.queue_free(); entries.erase(id)
	visible = not entries.is_empty() and not (viewer.offline_instance and not viewer.overlay_visible)
	arrange()

func place(bounds: Vector2, particle_top: float) -> void:
	available = bounds; bottom = particle_top
	arrange()

func arrange() -> void:
	if available == Vector2.ZERO: return
	# Bound the collection, leaving the center available even for many layers.
	var height := minf(stack.get_combined_minimum_size().y, maxf(0, minf(available.y*.4, bottom-72)))
	var width := 340.0 + get_v_scroll_bar().get_combined_minimum_size().x
	size = Vector2(width, height)
	position = Vector2(maxf(12,available.x-width-12), maxf(12,bottom-height-12))
