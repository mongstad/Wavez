extends AcceptDialog
## Informational only: no capture, playback or scientific controller dependencies.
const Version = preload("res://application_version.gd")
const Notices = preload("res://ui/about/notices.tres")
const Logo = preload("res://ui/about/wavez-logo-dark.png")
const REPOSITORY := "https://github.com/mongstad/SimScope"
var url_opener: Callable = OS.shell_open
var identity: Label
var runtime: Label
var logo: TextureRect
var overview: VBoxContainer
var license_page: VBoxContainer
var notice_choice: OptionButton
var notice_text: TextEdit
var browser_error: RichTextLabel
var github: LinkButton
var licenses: Button
var scroller: ScrollContainer

func _ready() -> void:
	title = "About WAVEZ"
	get_ok_button().text = "Close"
	scroller = ScrollContainer.new(); scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroller)
	var margin := MarginContainer.new(); margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroller.add_child(margin)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,8)
	var content := VBoxContainer.new(); content.add_theme_constant_override("separation",12); margin.add_child(content)
	overview = VBoxContainer.new(); overview.add_theme_constant_override("separation",10); content.add_child(overview)
	var header := HBoxContainer.new(); header.add_theme_constant_override("separation",16); overview.add_child(header)
	logo = TextureRect.new(); logo.texture = Logo; logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; logo.custom_minimum_size = Vector2(112,112)
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS; header.add_child(logo)
	var heading := VBoxContainer.new(); heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(heading)
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	identity = paragraph(heading,""); identity.add_theme_font_size_override("font_size",22)
	paragraph(heading,"Scientific capture, playback and analysis for particles, meshes and scalar fields.")
	paragraph(overview,Notices.get_meta("copyright"))
	paragraph(overview,"WAVEZ project material\nPolyForm Noncommercial 1.0.0. Commercial use requires a separate agreement with the rights holder.")
	paragraph(overview,"Godot Engine/runtime — MIT License.\nOther third-party components retain their respective licenses.")
	runtime = paragraph(overview,""); runtime.add_theme_color_override("font_color",get_theme_color("font_color","Label"))
	paragraph(overview,"Full license texts and third-party notices are available here and in the project repository.")
	github = LinkButton.new(); github.text = "github.com/mongstad/SimScope"; github.pressed.connect(open_repository); overview.add_child(github)
	licenses = Button.new(); licenses.text = "Licenses and notices"; licenses.pressed.connect(show_notices); overview.add_child(licenses)
	browser_error = RichTextLabel.new(); browser_error.fit_content = true; browser_error.selection_enabled = true
	browser_error.scroll_active = false; overview.add_child(browser_error); browser_error.hide()
	license_page = VBoxContainer.new(); license_page.add_theme_constant_override("separation",10); content.add_child(license_page)
	var back := Button.new(); back.text = "Back to About"; back.pressed.connect(show_overview); license_page.add_child(back)
	notice_choice = OptionButton.new(); notice_choice.fit_to_longest_item = false; license_page.add_child(notice_choice)
	for name in Notices.get_meta("notices"):notice_choice.add_item(name)
	notice_choice.add_item("Godot Engine — MIT License"); notice_choice.add_item("Godot third-party notices")
	notice_choice.item_selected.connect(select_notice)
	notice_text = TextEdit.new(); notice_text.editable = false; notice_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	notice_text.custom_minimum_size = Vector2(0,280); license_page.add_child(notice_text)
	notice_text.add_theme_color_override("font_readonly_color",get_theme_color("font_color","Label"))
	license_page.hide()
	get_parent().get_viewport().size_changed.connect(fit_to_viewport)

func paragraph(parent: Control, text: String) -> Label:
	var label := Label.new(); label.text = text; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; parent.add_child(label); return label

func open() -> void:
	identity.text = Version.details()
	runtime.text = "Runtime: Godot %s · %s %s" % [Engine.get_version_info().string,OS.get_name(),Engine.get_architecture_name()]
	browser_error.hide(); show_overview()
	var available := get_parent().get_viewport().get_visible_rect().size
	popup_centered(Vector2i(Vector2(580,560).min(available-Vector2(48,64)).max(Vector2(280,240))))

func fit_to_viewport() -> void:
	if not visible:return
	var available := get_parent().get_viewport().get_visible_rect().size
	size = Vector2i(Vector2(580,560).min(available-Vector2(48,64)).max(Vector2(280,240)))
	position = Vector2i((available-Vector2(size))*.5)

func show_overview() -> void:
	overview.show(); license_page.hide(); scroller.scroll_vertical = 0

func show_notices() -> void:
	overview.hide(); license_page.show(); scroller.scroll_vertical = 0
	notice_choice.select(0); select_notice(0); notice_choice.grab_focus()

func select_notice(index: int) -> void:
	var name := notice_choice.get_item_text(index)
	var texts: Dictionary = Notices.get_meta("notices")
	if texts.has(name):notice_text.text = texts[name]
	elif name == "Godot Engine — MIT License":notice_text.text = Engine.get_license_text()
	else:
		var parts := PackedStringArray(["Third-party components in this Godot runtime",JSON.stringify(Engine.get_copyright_info(),"  ")])
		var engine_licenses := Engine.get_license_info()
		for key in engine_licenses:parts.append(str(key)+"\n\n"+str(engine_licenses[key]))
		notice_text.text = "\n\n".join(parts)
	notice_text.scroll_vertical = 0

func open_repository() -> void:
	var result: int = url_opener.call(REPOSITORY)
	if result != OK:
		browser_error.text = "Could not open your browser. Copy this address:\n"+REPOSITORY
		browser_error.show()
		reveal_browser_error()
	else:browser_error.hide()

func reveal_browser_error() -> void:
	# Rich text wrapping and container height settle on successive layout frames.
	await get_tree().process_frame
	await get_tree().process_frame
	if visible and browser_error.visible:scroller.ensure_control_visible(browser_error)
