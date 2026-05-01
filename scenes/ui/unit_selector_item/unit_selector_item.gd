extends Panel
class_name UnitSelectorItem

var target_unit: Unit

@onready var portrait_texture: TextureRect = $MarginContainer/PortraitTexture
@onready var hotkey_label: Label = $HotkeyLabel

var _normal_style: StyleBoxFlat
var _selected_style: StyleBoxFlat
var _disabled_style: StyleBoxFlat

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	_normal_style = _create_style(Color(0.10, 0.10, 0.10, 0.88), Color(0.40, 0.40, 0.40, 1.0))
	_selected_style = _create_style(Color(0.25, 0.45, 0.22, 0.95), Color(0.9, 1.0, 0.65, 1.0))
	_disabled_style = _create_style(Color(0.10, 0.10, 0.10, 0.60), Color(0.22, 0.22, 0.22, 1.0))
	_apply_visual(false, true)

func setup(unit: Unit, hotkey_index: int) -> void:
	target_unit = unit
	portrait_texture.texture = unit.get_portrait_texture()
	portrait_texture.modulate = unit.animated_sprite.modulate if is_instance_valid(unit) else Color.WHITE
	hotkey_label.text = str(hotkey_index)

func set_state(is_selected: bool, is_interactable: bool) -> void:
	_apply_visual(is_selected, is_interactable)

func _apply_visual(is_selected: bool, is_interactable: bool) -> void:
	var style = _normal_style
	if not is_interactable:
		style = _disabled_style
	elif is_selected:
		style = _selected_style
	add_theme_stylebox_override("panel", style)
	portrait_texture.modulate.a = 1.0 if is_interactable else 0.45
	hotkey_label.modulate = Color(1, 1, 1, 1) if is_interactable else Color(1, 1, 1, 0.45)

func _create_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 4
	style.content_margin_top = 4
	style.content_margin_right = 4
	style.content_margin_bottom = 4
	return style
