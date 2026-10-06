@tool
extends Resource
## Midnight Scientific UI tokens (UX-STYLE-001). Scientific palettes and rendering never read this resource.
@export var colors: Dictionary[StringName, Color] = {
	# Static environmental depth only; never control fills or scientific backgrounds.
	&"atmosphere.start": Color("111e30"), &"atmosphere.end": Color("0b101b"),
	&"surface.0": Color("0b101b"), &"surface.1": Color("111a29"),
	&"surface.2": Color("1a2638"), &"surface.3": Color("243249"),
	&"surface.hover": Color("2c3c54"), &"surface.pressed": Color("354862"),
	&"text.primary": Color("e6eaf0"), &"text.secondary": Color("b9c1cc"),
	&"text.muted": Color("9aa5b3"), &"text.disabled": Color("737c89"),
	# Distinct violet hierarchy cues; independent of interaction and semantic colors.
	&"text.title": Color("7270d8"), &"text.section": Color("7270d8"),
	&"text.numeric": Color("e6eaf0"), &"border.subtle": Color("465b76"),
	&"border.control": Color("798fae"), &"focus.ring": Color("a8c9ff"),
	&"accent.primary": Color("8cb8ff"), &"accent.foreground": Color("142035"),
	# Sparse identity marks only; never status, intensity tiers or scientific data.
	&"identity.purple": Color("b4a2dc"), &"identity.teal": Color("79bfc4"),
	&"selection.fill": Color("233f68"), &"selection.text": Color("dceaff"),
	# Categorical UI tiers, not operational severity or scientific magnitudes.
	&"tier.low": Color("b8c2d1"), &"tier.medium": Color("62d5db"),
	&"tier.high": Color("80acff"), &"tier.xhigh": Color("bc9aff"),
	&"tier.max": Color("efa5df"),
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
