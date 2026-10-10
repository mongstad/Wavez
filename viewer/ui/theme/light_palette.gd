extends RefCounted
## Application chrome only; roles and geometry come from the existing builders.
const COLORS = {
	&"atmosphere.start": Color("e1e3ea"), &"atmosphere.end": Color("d9dde6"),
	&"surface.0": Color("e1e3ea"), &"surface.1": Color("eef0f5"),
	&"surface.2": Color("d6dbe6"), &"surface.3": Color("e5e8ef"),
	&"surface.hover": Color("dcd4ec"), &"surface.pressed": Color("d9d0e9"),
	&"surface.lit": Color("eef0f5"), &"surface.shade": Color("e1e3ea"),
	&"text.primary": Color("25283a"), &"text.secondary": Color("414e65"),
	&"text.muted": Color("4e596d"), &"text.disabled": Color("6b7182"),
	&"text.title": Color("563493"), &"text.section": Color("563493"),
	&"text.numeric": Color("25283a"), &"border.subtle": Color("b7becd"),
	&"border.control": Color("626e85"), &"focus.ring": Color("596dbc"),
	&"accent.primary": Color("563493"), &"accent.foreground": Color("ffffff"),
	&"identity.purple": Color("7956c8"), &"identity.teal": Color("287b80"),
	&"selection.fill": Color("dcd4ec"), &"selection.text": Color("452776"),
	&"tier.low": Color("4c576e"), &"tier.medium": Color("126c72"),
	&"tier.high": Color("315fba"), &"tier.xhigh": Color("7950b0"),
	&"tier.max": Color("a3418d"),
	&"state.success": Color("20683f"), &"state.warning": Color("785006"),
	&"state.error": Color("a62e43"), &"state.info": Color("315890"),
}
