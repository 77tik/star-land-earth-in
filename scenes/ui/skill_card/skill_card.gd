extends Panel
class_name SkillCard

signal pressed(skill_index: int)

var skill_index: int = -1

@onready var hotkey_label: Label = $MarginContainer/VBoxContainer/TopRow/HotkeyLabel
@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var description_label: Label = $MarginContainer/VBoxContainer/DescriptionLabel

var _normal_style: StyleBoxFlat
var _selected_style: StyleBoxFlat

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	_normal_style = _create_style(Color(0.12, 0.12, 0.12, 0.88), Color(0.45, 0.45, 0.45, 1.0))
	_selected_style = _create_style(Color(0.25, 0.45, 0.22, 0.95), Color(0.9, 1.0, 0.65, 1.0))
	_set_selected(false)

func setup(index: int, skill: BaseSkill) -> void:
	skill_index = index
	hotkey_label.text = str(index + 1)
	name_label.text = skill.skill_name
	description_label.text = _build_short_description(skill.description)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed.emit(skill_index)
		accept_event()

func set_selected(value: bool) -> void:
	_set_selected(value)

func _set_selected(value: bool) -> void:
	add_theme_stylebox_override("panel", _selected_style if value else _normal_style)
	name_label.modulate = Color(1, 1, 1, 1) if value else Color(0.92, 0.92, 0.92, 1)
	hotkey_label.modulate = Color(0.12, 0.12, 0.12, 1) if value else Color(0.95, 0.95, 0.95, 1)
	description_label.modulate = Color(0.95, 0.98, 0.9, 1) if value else Color(0.82, 0.82, 0.82, 1)

func _build_short_description(text: String) -> String:
	var compact_text = text.replace("\n", " ").strip_edges()
	if compact_text.is_empty():
		return "暂无描述"
	if compact_text.length() > 20:
		return compact_text.substr(0, 20) + "..."
	return compact_text

func _create_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	return style
