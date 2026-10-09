extends RefCounted
## Application chrome only; roles and geometry come from the existing builders.
const COLORS = {
	&"atmosphere.start": Color("f7f8fc"), &"atmosphere.end": Color("eeeefa"),
	&"surface.0": Color("f7f8fc"), &"surface.1": Color("f7f8fc"),
	&"surface.2": Color("eeeff6"), &"surface.3": Color("fafaff"),
	&"surface.hover": Color("e8e7f4"), &"surface.pressed": Color("eee8fa"),
	&"surface.lit": Color("fafaff"), &"surface.shade": Color("f0f1f8"),
	&"text.primary": Color("25283a"), &"text.secondary": Color("515c73"),
	&"text.muted": Color("657087"), &"text.disabled": Color("73798a"),
	&"text.title": Color("7956c8"), &"text.section": Color("7956c8"),
	&"text.numeric": Color("25283a"), &"border.subtle": Color("d6d8e5"),
	&"border.control": Color("989eb2"), &"focus.ring": Color("687bce"),
	&"accent.primary": Color("7956c8"), &"accent.foreground": Color("ffffff"),
	&"identity.purple": Color("7956c8"), &"identity.teal": Color("287b80"),
	&"selection.fill": Color("eee8fa"), &"selection.text": Color("51358e"),
	&"tier.low": Color("515c73"), &"tier.medium": Color("14747a"),
	&"tier.high": Color("315fba"), &"tier.xhigh": Color("7950b0"),
	&"tier.max": Color("a3418d"),
	&"state.success": Color("24764b"), &"state.warning": Color("916009"),
	&"state.error": Color("bc3549"), &"state.info": Color("375fa0"),
}
