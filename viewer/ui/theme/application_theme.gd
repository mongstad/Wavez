extends Node
## Event-driven chrome preference. Never enters capture/preset/export state.
const Base = preload("res://ui/theme/wavez_theme.gd")
const Violet = preload("res://ui/theme/violet_slice_theme.gd")
const Palette = preload("res://ui/theme/light_palette.gd")
const PATH := "user://appearance.cfg"
var shell
var light := false
var variants := {}
var originals := {}
var pending := false
var applying := false
var dark_base := Base.new()
var dark_violet := Violet.new()
var applications := 0

func setup(owner_shell) -> void:
	shell = owner_shell
	var config := ConfigFile.new()
	var error := config.load(PATH)
	if error == OK: light = config.get_value("appearance", "theme", "Dark") == "Light"
	elif error != ERR_FILE_NOT_FOUND: push_warning("Could not load appearance: " + error_string(error))
	get_tree().node_added.connect(node_added)
	apply()

func select(value: bool) -> void:
	var config := ConfigFile.new()
	config.set_value("appearance", "theme", "Light" if value else "Dark")
	var error := config.save(PATH)
	if error != OK:
		push_warning("Could not save appearance: " + error_string(error))
		return
	light = value
	apply()

func node_added(node: Node) -> void:
	if shell.viewer.is_ancestor_of(node): schedule()

func schedule() -> void:
	if applying or pending: return
	pending = true
	apply.call_deferred()

func excluded(node: Node) -> bool:
	for scientific in [shell.viewer.legend, shell.viewer.colorbar, shell.particle_legend_panel, shell.layer_legends, shell.viewer.screenshot_notice]:
		if is_instance_valid(scientific) and (node == scientific or scientific.is_ancestor_of(node)): return true
	return false

func variant(source: Theme) -> Theme:
	if variants.has(source): return variants[source]
	var result: Theme
	if source is Base:
		result = source.get_script().new()
		result.set_light(true)
		for type in source.get_type_list():
			for key in source.get_stylebox_list(type):
				var original: StyleBox = source.get_stylebox(key,type)
				var styled: StyleBox = result.get_stylebox(key,type)
				if original is StyleBoxFlat: styled.set_meta("wavez_dark_colors", [original.bg_color,original.border_color])
				elif original is StyleBoxTexture and original.texture is GradientTexture2D: styled.set_meta("wavez_dark_colors",original.texture.gradient.colors)
	else:
		# Native dialogs retain their native geometry and font metrics.
		result = source.duplicate(true)
		for type in result.get_type_list():
			for key in result.get_color_list(type):
				var role := &"text.primary"
				if "disabled" in key: role = &"text.disabled"
				elif "selected" in key or "hover" in key: role = &"selection.text"
				elif "selection" in key: role = &"selection.fill"
				elif "shadow" in key or "outline" in key: continue
				result.set_color(key, type, Palette.COLORS[role])
			for key in result.get_stylebox_list(type):
				var style := result.get_stylebox(key, type)
				if style is StyleBoxFlat:
					if style.bg_color.a > 0:
						style.bg_color = Palette.COLORS[&"selection.fill" if "selected" in key or "pressed" in key else (&"surface.hover" if "hover" in key else &"surface.1")]
					style.border_color = Palette.COLORS[&"focus.ring" if "focus" in key else &"border.control"]
		for key in ["close", "close_pressed"]:
			if not result.has_icon(key, "Window"): continue
			var pixels: Image = result.get_icon(key, "Window").get_image()
			if pixels == null: continue
			pixels = pixels.duplicate()
			for y in pixels.get_height():
				for x in pixels.get_width():
					var color: Color = Palette.COLORS[&"text.primary"]
					color.a = pixels.get_pixel(x,y).a
					pixels.set_pixel(x,y,color)
			result.set_icon(key, "Window", ImageTexture.create_from_image(pixels))
	variants[source] = result
	return result

func ink(color: Color, source: Theme) -> Color:
	if color.a == 0: return color
	for candidate in [source, dark_base, dark_violet]:
		if not candidate is Base: continue
		for role in Palette.COLORS:
			if not candidate is Violet and not candidate.TOKENS.colors.has(role): continue
			if candidate.c(role) == color: return Palette.COLORS[role]
	# Retained inspector helper ink predates semantic tokens.
	if color == Color("91b6ca"): return Palette.COLORS[&"text.secondary"]
	return color

func recolor(style: StyleBox, source: Theme, to_light := true) -> StyleBox:
	# Duplicate only presentation resources. Keep every metric and original dark
	# color, including for local styles copied/modified by a dialog while Light.
	var result := style.duplicate(true)
	if result is StyleBoxFlat:
		var dark: Array = style.get_meta("wavez_dark_colors", [style.bg_color, style.border_color])
		result.bg_color = ink(dark[0], source) if to_light else dark[0]
		result.border_color = ink(dark[1], source) if to_light else dark[1]
		result.set_meta("wavez_dark_colors", dark)
	elif result is StyleBoxTexture and result.texture is GradientTexture2D:
		var dark: PackedColorArray = style.get_meta("wavez_dark_colors", style.texture.gradient.colors)
		var colors := dark.duplicate()
		if to_light:
			for i in colors.size(): colors[i] = ink(colors[i], source)
		result.texture.gradient.colors = colors
		result.set_meta("wavez_dark_colors", dark)
	result.set_meta("wavez_light", to_light)
	return result

func walk(node: Node, inherited: Theme) -> void:
	if excluded(node): return
	var source := inherited
	if node is Control or node is Window:
		var id := node.get_instance_id()
		if not originals.has(id):
			originals[id] = {"node": weakref(node), "theme": node.theme, "styles": {}, "colors": {}}
			if not node.theme_changed.is_connected(schedule): node.theme_changed.connect(schedule)
		var record: Dictionary = originals[id]
		# Owners may assign a scoped theme when a deferred dialog opens.
		if node.theme != record.theme and not variants.values().has(node.theme): record.theme = node.theme
		if record.theme != null: source = record.theme
		if source == null: source = ThemeDB.get_default_theme()
		if node != shell and (record.theme != null or node is Window or node.get_parent() == shell or not (node.get_parent() is Control or node.get_parent() is Window)):
			node.theme = variant(source) if light else record.theme
		for property in node.get_property_list():
			var name: String = property.name
			if name.begins_with("theme_override_styles/") and node.get(name) != null:
				var current: StyleBox = node.get(name)
				if not record.styles.has(name) or (current != record.styles[name][0] and current != record.styles[name][1]):
					var dark := recolor(current, source, false) if current.get_meta("wavez_light", false) else current
					record.styles[name] = [dark, recolor(dark, source)]
				node.set(name, record.styles[name][1 if light else 0])
			elif name.begins_with("theme_override_colors/") and node.get(name) != null:
				var current: Color = node.get(name)
				if not record.colors.has(name) or not current in record.colors[name]: record.colors[name] = [current, ink(current, source)]
				node.set(name, record.colors[name][1 if light else 0])
		if node is TextureRect and node.has_meta("chrome_icon"):
			node.texture = variant(dark_base).icon_named(node.get_meta("chrome_icon"), &"text.secondary") if light else load("res://ui/icons/" + node.get_meta("chrome_icon") + ".svg")
		if node is OptionButton: walk(node.get_popup(), source)
	for child in node.get_children(): walk(child, source)

func apply() -> void:
	pending = false
	if not is_instance_valid(shell): return
	applying = true
	applications += 1
	for id in originals.keys():
		if originals[id].node.get_ref() == null: originals.erase(id)
	walk(shell.viewer, null)
	shell.about.logo.texture = shell.about.LightLogo if light else shell.about.Logo
	for pair in [["theme_dark", not light], ["theme_light", light]]:
		var entry: Dictionary = shell.commands[pair[0]]
		entry.popup.set_item_checked(entry.index, pair[1])
	applying = false
