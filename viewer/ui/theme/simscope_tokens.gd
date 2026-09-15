@tool
extends Resource
## Canonical UX1 logical tokens. Scientific palettes and rendering never read this resource.
@export var colors: Dictionary[StringName, Color] = {
	&"surface.0": Color("15171b"), &"surface.1": Color("1c1f24"),
	&"surface.2": Color("252930"), &"surface.3": Color("2d323a"),
	&"surface.hover": Color("323943"), &"surface.pressed": Color("3a4350"),
	&"text.primary": Color("e6eaf0"), &"text.secondary": Color("b9c1cc"),
	&"text.muted": Color("9aa5b3"), &"text.disabled": Color("737c89"),
	&"text.numeric": Color("e6eaf0"), &"border.subtle": Color("46505d"),
	&"border.control": Color("707d8e"), &"focus.ring": Color("a8c9ff"),
	&"accent.primary": Color("8cb8ff"), &"accent.foreground": Color("142035"),
	&"selection.fill": Color("263f62"), &"selection.text": Color("dceaff"),
	&"state.success": Color("7fd1a7"), &"state.warning": Color("e8bf72"),
	&"state.error": Color("f08c91"), &"state.info": Color("9cbee8"),
}
@export var spacing: PackedInt32Array = [4, 8, 12, 16, 24, 32]
@export var control_height: int = 32
@export var compact_height: int = 28
@export var large_height: int = 40
@export var control_radius: int = 4
@export var popup_radius: int = 6
@export var border_width: int = 1
@export var focus_width: int = 2
@export var focus_gap: int = 2
@export var icon_size: int = 16
@export var scrollbar_visual: int = 10
@export var scrollbar_lane: int = 14
@export var property_label_width: int = 128
@export var property_stack_width: int = 320
@export var dialog_width: int = 640
@export var tooltip_width: int = 360
@export var body_size: int = 14
@export var title_size: int = 18
@export var panel_size: int = 16
@export var help_size: int = 12
@export var numeric_size: int = 13
@export var hover_ms: int = 80
@export var release_ms: int = 60
@export var tooltip_delay_ms: int = 500
@export var scales: PackedFloat32Array = [1.0, 1.25, 1.5, 2.0]

func color(key: StringName) -> Color:
	assert(colors.has(key), "Unknown UI token: " + key)
	return colors[key]
