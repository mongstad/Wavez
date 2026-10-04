extends PanelContainer
## Compact theme-driven section for application-owned dialogs.
var title_label: Label
var body: VBoxContainer

func _init(title: String = "") -> void:
	theme_type_variation = "TitledGroup"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 4)
	add_child(layout)
	title_label = Label.new()
	title_label.text = title
	title_label.theme_type_variation = "SectionTitle"
	layout.add_child(title_label)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	layout.add_child(body)

func set_title(title: String) -> void:
	title_label.text = title
