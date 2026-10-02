@tool
extends Theme
## Derived at load time: edit tokens/builder, never a second serialized style palette.
const TOKENS = preload("res://ui/theme/wavez_tokens.tres")
const MONO = preload("res://ui/fonts/DejaVuSansMono.ttf")
const OUTER_RADIUS := 6 # Accepted About outer-corner reference.
var _icons: Dictionary = {}

func c(key: StringName) -> Color: return TOKENS.color(key)

func box(fill: StringName, border: StringName = &"border.subtle", pad_x: int = 12, pad_y: int = 6, radius: int = 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = c(fill)
	style.border_color = c(border)
	style.set_border_width_all(TOKENS.border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = pad_x; style.content_margin_right = pad_x
	style.content_margin_top = pad_y; style.content_margin_bottom = pad_y
	style.anti_aliasing = true
	return style

func dialog_body(fill: StringName, border: StringName, x: int, y: int) -> StyleBoxFlat:
	# Embedded Window owns the outer header corners; the body joins it squarely.
	var style := box(fill, border, x, y, OUTER_RADIUS)
	style.corner_radius_top_left = 0; style.corner_radius_top_right = 0
	style.border_width_top = 0
	return style

func atmosphere() -> StyleBoxTexture:
	# One immutable texture: no shader time, animation or per-frame regeneration.
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([c(&"atmosphere.start"), c(&"atmosphere.end")])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256; texture.height = 256
	texture.fill_from = Vector2.ZERO; texture.fill_to = Vector2.ONE
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.content_margin_left = 24; style.content_margin_right = 24
	style.content_margin_top = 24; style.content_margin_bottom = 24
	return style

func focus() -> StyleBoxFlat:
	var style := box(&"surface.0", &"focus.ring", 0, 0)
	style.draw_center = false
	style.set_border_width_all(TOKENS.focus_width)
	style.set_expand_margin_all(TOKENS.focus_gap + TOKENS.focus_width)
	style.set_corner_radius_all(TOKENS.control_radius + TOKENS.focus_gap)
	return style

func icon_named(id: String, color_role: StringName = &"text.primary") -> Texture2D:
	var key := id + String(color_role)
	if not _icons.has(key):
		# Import SVG as DPITexture: the SVG source survives export remapping and re-rasterizes per viewport.
		var source: DPITexture = load("res://ui/icons/" + id + ".svg")
		_icons[key] = DPITexture.create_from_string(source.get_source(), 1.0, 1.0, {Color.WHITE: c(color_role)})
	return _icons[key]

func _text(type: StringName) -> void:
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		set_color(state, type, c(&"text.primary"))
	set_color("font_disabled_color", type, c(&"text.disabled"))
	set_color("font_uneditable_color", type, c(&"text.secondary"))
	set_color("font_selected_color", type, c(&"selection.text"))
	set_color("font_outline_color", type, Color.TRANSPARENT)

func _button(type: StringName, height: int = TOKENS.control_height) -> void:
	_text(type)
	var vertical := maxi(0, height - ceili(default_font.get_height(TOKENS.body_size)))
	for entry in [["normal", &"surface.2"], ["hover", &"surface.hover"], ["pressed", &"surface.pressed"], ["hover_pressed", &"surface.pressed"], ["disabled", &"surface.1"]]:
		var style := box(entry[1], &"border.control", TOKENS.spacing[2], vertical / 2)
		style.content_margin_bottom = vertical - int(style.content_margin_top)
		if entry[0] in ["hover", "pressed", "hover_pressed"]: style.border_color = c(&"text.secondary")
		if entry[0] == "disabled": style.border_color = c(&"border.subtle")
		set_stylebox(entry[0], type, style)
	set_stylebox("focus", type, focus())
	set_constant("h_separation", type, TOKENS.spacing[1])
	set_constant("outline_size", type, 0)
	set_constant("icon_max_width", type, TOKENS.icon_size)
	set_color("icon_disabled_color", type, c(&"text.disabled"))

func _init() -> void:
	default_font = ThemeDB.fallback_font
	default_font_size = TOKENS.body_size
	default_base_scale = 1.0
	for type in ["Button", "OptionButton", "MenuButton", "CheckBox", "CheckButton"]: _button(type)
	for role in ["SecondaryButton", "PrimaryButton", "DestructiveButton", "SelectedButton", "CompactButton", "IconAction", "SectionHeader"]:
		set_type_variation(role, "Button")
		_button(role, TOKENS.compact_height if role == "CompactButton" else TOKENS.control_height)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		# Same accent in all fills; border and pressed inset communicate interaction.
		var primary := box(&"accent.primary", &"accent.primary")
		primary.content_margin_top = get_stylebox(state, "Button").content_margin_top
		primary.content_margin_bottom = get_stylebox(state, "Button").content_margin_bottom
		if state == "hover": primary.border_color = c(&"focus.ring")
		if state in ["pressed", "hover_pressed"]: primary.set_border_width_all(2); primary.border_color = c(&"accent.foreground")
		set_stylebox(state, "PrimaryButton", primary)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		set_color(key, "PrimaryButton", c(&"accent.foreground"))
		set_color(key, "DestructiveButton", c(&"state.error"))
	for key in ["font_pressed_color", "font_hover_pressed_color"]: set_color(key, "DestructiveButton", c(&"text.primary"))
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var danger: StyleBoxFlat = get_stylebox(state, "Button").duplicate()
		danger.border_color = c(&"state.error")
		set_stylebox(state, "DestructiveButton", danger)
		var selected := box(&"selection.fill", &"accent.primary")
		selected.content_margin_top = danger.content_margin_top; selected.content_margin_bottom = danger.content_margin_bottom
		set_stylebox(state, "SelectedButton", selected)
	set_color("font_color", "SelectedButton", c(&"selection.text"))
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var icon_style: StyleBoxFlat = get_stylebox(state, "IconAction").duplicate()
		icon_style.content_margin_left = 8; icon_style.content_margin_right = 8
		set_stylebox(state, "IconAction", icon_style)
	# Labels and typography retain the bundled Godot sans; only numeric roles use mono.
	_text("Label")
	set_constant("line_spacing", "Label", 2)
	var semibold := FontVariation.new(); semibold.base_font = default_font; semibold.variation_embolden = 0.5
	for role in ["ApplicationTitle", "PanelTitle", "SectionTitle", "PropertyLabel", "HelpLabel", "SecondaryLabel", "NumericValue", "StatusLabel", "ErrorLabel"]:
		set_type_variation(role, "Label")
	for pair in [["ApplicationTitle", TOKENS.title_size], ["PanelTitle", TOKENS.panel_size], ["SectionTitle", TOKENS.body_size]]:
		set_font_size("font_size", pair[0], pair[1]); set_font("font", pair[0], semibold)
	set_font("font", "SectionHeader", semibold)
	for role in ["HelpLabel", "StatusLabel"]: set_font_size("font_size", role, TOKENS.help_size)
	for role in ["PropertyLabel", "SecondaryLabel"]: set_color("font_color", role, c(&"text.secondary"))
	set_color("font_color", "HelpLabel", c(&"text.muted"))
	set_color("font_color", "ErrorLabel", c(&"state.error"))
	set_color("font_color", "NumericValue", c(&"text.numeric"))
	set_font("font", "NumericValue", MONO); set_font_size("font_size", "NumericValue", TOKENS.numeric_size)
	for tier in ["Low", "Medium", "High", "XHigh", "Max"]:
		var role := StringName("Tier" + tier)
		set_type_variation(role, "Label")
		set_font_size("font_size", role, TOKENS.help_size)
		set_color("font_color", role, c(StringName("tier." + tier.to_lower())))
	# Native input states, including selection/caret; no global project theme.
	_text("LineEdit"); _text("TextEdit")
	for type in ["LineEdit", "TextEdit"]:
		set_stylebox("normal", type, get_stylebox("normal", "Button"))
		set_stylebox("read_only", type, get_stylebox("disabled", "Button"))
		set_stylebox("focus", type, focus())
		set_color("caret_color", type, c(&"focus.ring"))
		set_color("selection_color", type, c(&"selection.fill"))
		set_color("font_placeholder_color", type, c(&"text.muted"))
	set_icon("clear", "LineEdit", icon_named("close", &"text.secondary"))
	for role in ["NumericInput", "InvalidInput", "InvalidNumericInput", "SearchInput"]:
		set_type_variation(role, "LineEdit")
	for role in ["NumericInput", "InvalidNumericInput"]:
		set_color("font_color", role, c(&"text.numeric"))
		set_font("font", role, MONO); set_font_size("font_size", role, TOKENS.numeric_size)
	for role in ["InvalidInput", "InvalidNumericInput"]:
		var invalid: StyleBoxFlat = get_stylebox("normal", "LineEdit").duplicate(); invalid.border_color = c(&"state.error")
		set_stylebox("normal", role, invalid)
	set_icon("arrow", "OptionButton", icon_named("chevron_down", &"text.secondary"))
	set_constant("arrow_margin", "OptionButton", TOKENS.spacing[1])
	for type in ["CheckBox", "CheckButton"]:
		for entry in [["checked", "checked"], ["unchecked", "box"], ["radio_checked", "radio_checked"], ["radio_unchecked", "radio"], ["on", "checked"], ["off", "box"]]:
			set_icon(entry[0], type, icon_named(entry[1], &"accent.primary" if entry[0] in ["checked", "radio_checked", "on"] else &"text.secondary"))
			set_icon(entry[0] + "_disabled", type, icon_named(entry[1], &"text.disabled"))
		for state in ["normal", "disabled"]:
			var check_style: StyleBoxFlat = get_stylebox(state, "Button").duplicate(); check_style.draw_center = false; check_style.set_border_width_all(0)
			set_stylebox(state, type, check_style)
	set_icon("up", "SpinBox", icon_named("chevron_up")); set_icon("down", "SpinBox", icon_named("chevron_down"))
	set_icon("updown", "SpinBox", icon_named("updown"))
	# Containers: padding belongs to shared styles/variations.
	for type in ["HBoxContainer", "VBoxContainer"]: set_constant("separation", type, TOKENS.spacing[1])
	for type in ["HFlowContainer", "VFlowContainer", "GridContainer"]:
		set_constant("h_separation", type, TOKENS.spacing[1]); set_constant("v_separation", type, TOKENS.spacing[1])
	for role in ["AppSurface", "AtmosphericSurface", "PropertyGroup", "RaisedPanel", "PopupSurface"]: set_type_variation(role, "PanelContainer")
	set_stylebox("panel", "PanelContainer", box(&"surface.1", &"border.subtle", 12, 12, 0))
	set_stylebox("panel", "AtmosphericSurface", atmosphere())
	set_stylebox("panel", "AppSurface", box(&"surface.0", &"surface.0", 24, 24, 0))
	set_stylebox("panel", "PropertyGroup", box(&"surface.1", &"border.subtle", 12, 12, 0))
	set_stylebox("panel", "RaisedPanel", box(&"surface.2", &"border.subtle", 12, 12, 4))
	set_stylebox("panel", "PopupSurface", box(&"surface.3", &"border.control", 24, 24, 6))
	for type in ["HSeparator", "VSeparator"]:
		var line := StyleBoxLine.new(); line.color = c(&"border.subtle"); line.thickness = 1; line.vertical = type == "VSeparator"
		set_stylebox("separator", type, line); set_constant("separation", type, TOKENS.spacing[1])
	# Selection has a border/marker in addition to its fill.
	var selection := box(&"selection.fill", &"accent.primary", 8, 4); selection.border_width_left = 3
	for type in ["Tree", "ItemList"]:
		_text(type)
		set_stylebox("panel", type, box(&"surface.2", &"border.control", 8, 8))
		set_stylebox("focus", type, focus())
		for state in ["selected", "selected_focus", "cursor", "cursor_unfocused"]: set_stylebox(state, type, selection)
		set_stylebox("hovered", type, box(&"surface.hover", &"border.subtle", 8, 4))
		set_stylebox("button_hover", type, box(&"surface.hover"))
		set_constant("v_separation", type, 8)
		set_constant("h_separation", type, 8)
	for state in ["normal", "hover", "pressed"]: set_stylebox("title_button_" + state, "Tree", get_stylebox(state, "Button"))
	set_color("title_button_color", "Tree", c(&"text.primary"))
	set_stylebox("hovered_selected", "Tree", selection); set_stylebox("hovered_selected_focus", "Tree", selection)
	set_color("font_hovered_color", "Tree", c(&"text.primary"))
	set_color("font_hovered_selected_color", "Tree", c(&"selection.text"))
	set_icon("arrow", "Tree", icon_named("chevron_down")); set_icon("arrow_collapsed", "Tree", icon_named("chevron_right"))
	set_icon("checked", "Tree", icon_named("checked", &"accent.primary")); set_icon("unchecked", "Tree", icon_named("box"))
	for type in ["TabBar", "TabContainer"]:
		_text(type)
		set_color("font_unselected_color", type, c(&"text.secondary"))
		set_color("font_hovered_color", type, c(&"text.primary"))
		set_stylebox("tab_selected", type, selection)
		set_stylebox("tab_unselected", type, box(&"surface.1", &"border.subtle", 12, 8))
		set_stylebox("tab_hovered", type, box(&"surface.hover", &"border.control", 12, 8))
		set_stylebox("tab_disabled", type, box(&"surface.1", &"border.subtle", 12, 8))
		set_stylebox("tab_focus", type, focus())
		set_stylebox("panel", type, box(&"surface.1", &"border.subtle", 12, 12, 0))
	# Slider/scrollbar tracks and native interaction states.
	for type in ["HSlider", "VSlider"]:
		var track := box(&"surface.2", &"border.control", 2, 2, 2)
		set_stylebox("slider", type, track)
		set_stylebox("grabber_area", type, box(&"accent.primary", &"accent.primary", 2, 2, 2))
		set_stylebox("grabber_area_highlight", type, box(&"focus.ring", &"focus.ring", 2, 2, 2))
		set_icon("grabber", type, icon_named("grip", &"accent.primary"))
		set_icon("grabber_highlight", type, icon_named("grip", &"focus.ring"))
		set_icon("grabber_disabled", type, icon_named("grip", &"text.disabled"))
		# Godot Slider uses grabber highlight for focus; lab verifies this boundary.
	for type in ["HScrollBar", "VScrollBar"]:
		var vertical: bool = type == "VScrollBar"
		var lane := box(&"surface.1", &"surface.1", 7 if vertical else 0, 0 if vertical else 7, 0)
		set_stylebox("scroll", type, lane); set_stylebox("scroll_focus", type, lane)
		for entry in [["grabber", &"border.control"], ["grabber_highlight", &"text.secondary"], ["grabber_pressed", &"focus.ring"]]:
			var grab := box(entry[1], entry[1], 7 if vertical else 0, 0 if vertical else 7, 2)
			# Drawing inset leaves a 10 px visual inside the 14 px lane.
			if vertical: grab.expand_margin_left = -2; grab.expand_margin_right = -2
			else: grab.expand_margin_top = -2; grab.expand_margin_bottom = -2
			set_stylebox(entry[0], type, grab)
		for key in ["increment", "increment_highlight", "increment_pressed", "decrement", "decrement_highlight", "decrement_pressed"]: set_icon(key, type, ImageTexture.new())
	_text("ProgressBar")
	set_stylebox("background", "ProgressBar", box(&"surface.2", &"border.control", 0, 8))
	set_stylebox("fill", "ProgressBar", box(&"accent.primary", &"accent.primary", 0, 8))
	# Percent text must be outside the two-tone track (component below).
	_text("PopupMenu")
	set_stylebox("panel", "PopupMenu", box(&"surface.3", &"border.control", 8, 8, 6))
	set_stylebox("hover", "PopupMenu", selection)
	set_stylebox("separator", "PopupMenu", get_stylebox("separator", "HSeparator"))
	set_constant("v_separation", "PopupMenu", 12)
	set_color("font_accelerator_color", "PopupMenu", c(&"text.secondary"))
	set_icon("checked", "PopupMenu", icon_named("check", &"selection.text")); set_icon("submenu", "PopupMenu", icon_named("chevron_right"))
	set_stylebox("panel", "TooltipPanel", box(&"surface.3", &"border.control", 12, 8, 6))
	set_color("font_color", "TooltipLabel", c(&"text.primary")); set_font_size("font_size", "TooltipLabel", TOKENS.help_size)
	set_stylebox("panel", "AcceptDialog", dialog_body(&"surface.3", &"border.control", 24, 24))
	var window_border := box(&"surface.3", &"border.control", 12, 12, OUTER_RADIUS)
	window_border.expand_margin_top = 32
	set_stylebox("embedded_border", "Window", window_border)
	set_stylebox("embedded_unfocused_border", "Window", window_border)
	set_constant("title_height", "Window", 32)
	set_icon("close", "Window", icon_named("close")); set_icon("close_pressed", "Window", icon_named("close"))
	set_color("title_color", "Window", c(&"text.primary"))
	set_font_size("title_font_size", "Window", TOKENS.panel_size)
	for severity in ["info", "success", "warning", "error"]:
		var role: String = severity.capitalize() + "Message"
		set_type_variation(role, "PanelContainer")
		var style := box(&"surface.2", &"border.subtle", 12, 8)
		style.border_color = c(StringName("state." + severity)); style.border_width_left = 3
		style.border_width_top = 0; style.border_width_right = 0; style.border_width_bottom = 0
		set_stylebox("panel", role, style)
