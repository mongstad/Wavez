@tool
extends "res://ui/theme/simscope_theme.gd"
## #143 review slice. The accepted theme/colormaps remain separate resources.
const PALETTE = {
	&"surface.0": Color("080d14"), &"surface.1": Color("111827"),
	&"surface.2": Color("182234"), &"surface.3": Color("141c2b"),
	&"surface.hover": Color("222d42"), &"surface.pressed": Color("27294c"),
	&"text.primary": Color("e5eaf2"), &"text.secondary": Color("a5b2c6"),
	&"text.muted": Color("94a3b8"), &"text.disabled": Color("748096"),
	&"text.numeric": Color("e5eaf2"), &"border.subtle": Color("273247"),
	&"border.control": Color("39465e"), &"focus.ring": Color("9695f5"),
	&"accent.primary": Color("7270d8"), &"accent.foreground": Color("080d14"),
	&"selection.fill": Color("27294c"), &"selection.text": Color("dedcff"),
}
var shell_icons := {}

func c(key: StringName) -> Color:
	return PALETTE.get(key, TOKENS.color(key))

func flat_box(fill: StringName, x := 12, y := 6, radius := 4) -> StyleBoxFlat:
	var style := box(fill, &"border.subtle", x, y, radius)
	style.set_border_width_all(0)
	return style

func _init() -> void:
	super()
	# Parent builds typography, numeric inputs, semantic states and native widgets.
	# Only this scoped Theme uses the palette above; no project-wide theme change.
	for type in ["Button", "MenuButton", "SecondaryButton", "CompactButton", "IconAction", "SelectedButton", "SectionHeader", "CheckBox", "CheckButton", "OptionButton"]:
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var old := get_stylebox(state, type)
			var fill: StringName = &"surface.2" if type == "OptionButton" else &"surface.1"
			if state == "hover": fill = &"surface.hover"
			elif state in ["pressed", "hover_pressed"] or type == "SelectedButton": fill = &"selection.fill"
			var style := flat_box(fill)
			style.content_margin_left = old.content_margin_left
			style.content_margin_right = old.content_margin_right
			style.content_margin_top = old.content_margin_top
			style.content_margin_bottom = old.content_margin_bottom
			if type in ["Button", "MenuButton", "IconAction", "CheckBox", "CheckButton"] and state in ["normal", "disabled"]: style.bg_color = Color.TRANSPARENT
			if type == "CheckButton" and state == "pressed": style.bg_color = Color.TRANSPARENT
			set_stylebox(state, type, style)
		for state in ["font_pressed_color", "font_hover_pressed_color", "icon_pressed_color", "icon_hover_pressed_color"]:
			set_color(state, type, c(&"selection.text"))
		set_color("icon_normal_color", type, c(&"text.secondary"))
		set_color("icon_hover_color", type, c(&"text.primary"))
		set_color("icon_focus_color", type, c(&"text.primary"))
		set_color("icon_disabled_color", type, c(&"text.disabled"))
	# Active tabs have one accent underline rather than a boxed selected button.
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var selected := flat_box(&"selection.fill")
		selected.border_width_bottom = 2; selected.border_color = c(&"accent.primary")
		set_stylebox(state, "SelectedButton", selected)
	set_stylebox("normal", "LineEdit", flat_box(&"surface.2"))
	set_stylebox("read_only", "LineEdit", flat_box(&"surface.1"))
	var invalid := flat_box(&"surface.2"); invalid.border_width_bottom = 1; invalid.border_color = c(&"state.error")
	for type in ["InvalidInput", "InvalidNumericInput"]: set_stylebox("normal", type, invalid)
	for type in ["HSlider", "VSlider"]:
		set_stylebox("slider", type, flat_box(&"border.control", 2, 2, 2))
		set_stylebox("grabber_area", type, flat_box(&"accent.primary", 2, 2, 2))
		set_stylebox("grabber_area_highlight", type, flat_box(&"focus.ring", 2, 2, 2))
		for pair in [["grabber", &"accent.primary"], ["grabber_highlight", &"focus.ring"], ["grabber_disabled", &"text.disabled"]]:
			set_icon(pair[0], type, svg_texture('<svg xmlns="http://www.w3.org/2000/svg" width="12" height="12"><circle cx="6" cy="6" r="4" fill="#ffffff"/></svg>', c(pair[1])))
	for pair in [["checked", true], ["unchecked", false], ["checked_disabled", true], ["unchecked_disabled", false]]:
		var disabled: bool = String(pair[0]).ends_with("disabled")
		var track := c(&"border.control" if disabled else (&"accent.primary" if pair[1] else &"border.control"))
		var knob := c(&"text.disabled" if disabled else &"text.primary")
		var source := '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="20"><rect x="1" y="2" width="30" height="16" rx="8" fill="#%s"/><circle cx="%s" cy="10" r="6" fill="#%s"/></svg>' % [track.to_html(false), "22" if pair[1] else "10", knob.to_html(false)]
		set_icon(pair[0], "CheckButton", DPITexture.create_from_string(source))
	set_constant("icon_max_width", "CheckButton", 32)
	set_stylebox("panel", "PopupMenu", flat_box(&"surface.3", 8, 8, 6))
	set_stylebox("hover", "PopupMenu", flat_box(&"selection.fill", 8, 4))
	set_color("font_hover_color", "PopupMenu", c(&"selection.text"))
	set_icon("radio_checked", "PopupMenu", icon_named("radio_checked", &"selection.text"))
	set_icon("radio_unchecked", "PopupMenu", icon_named("radio", &"text.secondary"))
	set_stylebox("panel", "TooltipPanel", flat_box(&"surface.3", 12, 8, 6))

func svg_texture(source: String, tint: Color) -> DPITexture:
	return DPITexture.create_from_string(source, 1.0, 1.0, {Color.WHITE: tint})

func shell_icon(id: String) -> Texture2D:
	if not shell_icons.has(id):
		var original: DPITexture = load("res://ui/shell/icons/" + id + ".svg")
		var colors := RegEx.new(); colors.compile("#[0-9a-fA-F]{6}")
		shell_icons[id] = DPITexture.create_from_string(colors.sub(original.get_source(), "#ffffff", true))
	return shell_icons[id]
