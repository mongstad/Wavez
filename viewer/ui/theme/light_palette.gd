extends RefCounted
## Application chrome only; roles and geometry come from the existing builders.
const COLORS = {
	&"atmosphere.start": Color("e6e8ef"), &"atmosphere.end": Color("e1e4ed"),
	&"surface.0": Color("e6e8ef"), &"surface.1": Color("f0f1f5"),
	&"surface.2": Color("e2e5ed"), &"surface.3": Color("eceef3"),
	&"surface.hover": Color("ddd5f0"), &"surface.pressed": Color("d8cfec"),
	&"surface.lit": Color("f0f1f5"), &"surface.shade": Color("e6e8ef"),
	&"text.primary": Color("25283a"), &"text.secondary": Color("4c576e"),
	&"text.muted": Color("5c667d"), &"text.disabled": Color("6b7182"),
	&"text.title": Color("7050b8"), &"text.section": Color("7050b8"),
	&"text.numeric": Color("25283a"), &"border.subtle": Color("d6d8e5"),
	&"border.control": Color("757d94"), &"focus.ring": Color("596dbc"),
	&"accent.primary": Color("7956c8"), &"accent.foreground": Color("ffffff"),
	&"identity.purple": Color("7956c8"), &"identity.teal": Color("287b80"),
	&"selection.fill": Color("ddd5f0"), &"selection.text": Color("51358e"),
	&"tier.low": Color("4c576e"), &"tier.medium": Color("126c72"),
	&"tier.high": Color("315fba"), &"tier.xhigh": Color("7950b0"),
	&"tier.max": Color("a3418d"),
	&"state.success": Color("20683f"), &"state.warning": Color("785006"),
	&"state.error": Color("a62e43"), &"state.info": Color("315890"),
}
