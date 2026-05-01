extends Node2D
class_name Battle

const ICON_SKULL = preload("uid://5wwkhf6n6x0o")
const TEST_UNIT = preload("uid://d06rf1yd48h6c")
const SKILL_CARD_SCENE = preload("res://scenes/ui/skill_card/skill_card.tscn")
const UNIT_SELECTOR_ITEM_SCENE = preload("res://scenes/ui/unit_selector_item/unit_selector_item.tscn")

@onready var game_area: GameArea = $GameArea
@onready var state_machine: BaseStateMachine = $BattleStateMachine
@onready var skill_bar_layer: CanvasLayer = $SkillBarLayer
@onready var skill_bar_container: HBoxContainer = $SkillBarLayer/SkillBarRoot/SkillBarMargin/SkillCardContainer
@onready var unit_selector_layer: CanvasLayer = $UnitSelectorLayer
@onready var unit_selector_container: VBoxContainer = $UnitSelectorLayer/UnitSelectorRoot/UnitSelectorMargin/UnitSelectorContainer
# 工具
@onready var unit_spawner: UnitSpawner = $UnitSpawner
@onready var grid_calculator: GridCalculator = $GridCalculator
@onready var range_selector: RangeSelector = $RangeSelector
@onready var unit_mover: UnitMover = $UnitMover
@onready var path_painter: PathPainter = $PathPainter
@onready var range_calculator: RangeCalculator = $RangeCalculator
@onready var attack_processor: AttackProcessor = $AttackProcessor
@onready var knockback_processor: KnockbackProcessor = $KnockbackProcessor
@onready var game_reseter: GameReseter = $GameReseter

@export var unit_positions_dict: Dictionary = {
	Vector2i(0, 0): {"faction": Unit.Faction.FRIENDLY, "unit_stat": TEST_UNIT},
	Vector2i(2, 1): {"faction": Unit.Faction.FRIENDLY, "unit_stat": TEST_UNIT},
	Vector2i(4, -4): {"faction": Unit.Faction.ENEMY, "unit_stat": TEST_UNIT},
	Vector2i(5, 6): {"faction": Unit.Faction.ENEMY, "unit_stat": TEST_UNIT}
}

# 活跃单位数组
var active_units: Array[Unit] = []
# 正在死亡的单位数组（播放死亡动画中）
var dying_units: Array[Unit] = []
# 所有单位状态管理
var all_units: AllUnits
# 当前选中的技能
var _current_skill: BaseSkill
var _skill_cards: Array[SkillCard] = []
var _unit_selector_items: Array[UnitSelectorItem] = []
var _can_switch_friendly_unit: bool = false

@warning_ignore("unused_private_class_variable")
var _icon_skull: IconSkull

func _ready() -> void:
	all_units = AllUnits.new()
	GlobalSignal.unit_died.connect(_on_unit_died)
	hide_skill_bar()

	state_machine.initialize(self)
	await get_tree().process_frame
	state_machine._on_enter()

func _process(delta: float) -> void:
	state_machine._state_process(delta)

func _input(event: InputEvent) -> void:
	state_machine._state_input(event)

func get_current_skill() -> BaseSkill:
	return _current_skill

func get_main_unit() -> Unit:
	return all_units.get_main_unit()

func get_current_unit_index() -> int:
	return all_units.current_unit_index

func get_controllable_friendly_units() -> Array[Unit]:
	return all_units.get_friendly_units()

func can_switch_controllable_unit() -> bool:
	return _can_switch_friendly_unit

func set_can_switch_friendly_unit(value: bool) -> void:
	_can_switch_friendly_unit = value
	refresh_unit_selector()

func switch_main_unit_for_move(unit: Unit) -> bool:
	if not unit or not _can_switch_friendly_unit:
		return false
	var unit_index = all_units.get_index_of_unit(unit)
	if unit_index < 0:
		return false
	var switched = all_units.set_current_unit_index(unit_index)
	if switched:
		show_skull_on_unit(unit)
		refresh_unit_selector()
	return switched

func select_skill(skill_index: int) -> BaseSkill:
	var unit = get_main_unit()
	if not unit:
		return null

	if not unit.has_method("get_skill"):
		push_warning("Unit does not have get_skill method")
		return null

	var selected_skill = unit.get_skill(skill_index)
	if selected_skill:
		_current_skill = selected_skill
		update_skill_bar_selection()
		print("Battle: Selected skill: ", selected_skill.skill_name)
	return selected_skill

func try_select_skill(event: InputEvent) -> BaseSkill:
	if not (event is InputEventKey):
		return null
	var key_event = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return null

	var skill_index: int
	match key_event.keycode:
		KEY_1, KEY_KP_1: skill_index = 0
		KEY_2, KEY_KP_2: skill_index = 1
		KEY_3, KEY_KP_3: skill_index = 2
		KEY_4, KEY_KP_4: skill_index = 3
		KEY_5, KEY_KP_5: skill_index = 4
		KEY_6, KEY_KP_6: skill_index = 5
		KEY_7, KEY_KP_7: skill_index = 6
		KEY_8, KEY_KP_8: skill_index = 7
		KEY_9, KEY_KP_9: skill_index = 8
		_: return null

	return select_skill(skill_index)

func try_select_friendly_unit(event: InputEvent) -> Unit:
	if not _can_switch_friendly_unit or not (event is InputEventKey):
		return null
	var key_event = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return null

	var target_index := -1
	match key_event.keycode:
		KEY_1, KEY_KP_1: target_index = 0
		KEY_2, KEY_KP_2: target_index = 1
		KEY_3, KEY_KP_3: target_index = 2
		KEY_4, KEY_KP_4: target_index = 3
		KEY_5, KEY_KP_5: target_index = 4
		KEY_6, KEY_KP_6: target_index = 5
		KEY_7, KEY_KP_7: target_index = 6
		KEY_8, KEY_KP_8: target_index = 7
		KEY_9, KEY_KP_9: target_index = 8
		_: return null

	var friendly_units = get_controllable_friendly_units()
	if target_index < 0 or target_index >= friendly_units.size():
		return null
	var selected_unit = friendly_units[target_index]
	if selected_unit == get_main_unit():
		return selected_unit
	if switch_main_unit_for_move(selected_unit):
		return selected_unit
	return null

func refresh_skill_bar() -> void:
	for child in skill_bar_container.get_children():
		child.queue_free()
	_skill_cards.clear()
	clear_selected_skill(false)

	var unit = get_main_unit()
	if not unit or unit.get_faction() != Unit.Faction.FRIENDLY:
		hide_skill_bar()
		return

	show_skill_bar()
	for i in range(unit.skills.size()):
		var skill = unit.skills[i]
		if not skill:
			continue
		var card := SKILL_CARD_SCENE.instantiate() as SkillCard
		skill_bar_container.add_child(card)
		card.setup(i, skill)
		card.pressed.connect(_on_skill_card_pressed)
		_skill_cards.append(card)

	update_skill_bar_selection()

func refresh_unit_selector() -> void:
	for child in unit_selector_container.get_children():
		child.queue_free()
	_unit_selector_items.clear()

	var friendly_units = get_controllable_friendly_units()
	for index in range(friendly_units.size()):
		var unit = friendly_units[index]
		var item := UNIT_SELECTOR_ITEM_SCENE.instantiate() as UnitSelectorItem
		unit_selector_container.add_child(item)
		item.setup(unit, index + 1)
		_unit_selector_items.append(item)

	var current_unit = get_main_unit()
	for item in _unit_selector_items:
		item.set_state(item.target_unit == current_unit, _can_switch_friendly_unit)

func update_skill_bar_selection() -> void:
	for i in range(_skill_cards.size()):
		var card = _skill_cards[i]
		var is_selected = false
		var unit = get_main_unit()
		if unit and i < unit.skills.size():
			is_selected = unit.skills[i] == _current_skill
		card.set_selected(is_selected)

func clear_selected_skill(update_ui: bool = true) -> void:
	_current_skill = null
	if update_ui:
		update_skill_bar_selection()

func show_skill_bar() -> void:
	skill_bar_layer.visible = true

func hide_skill_bar() -> void:
	skill_bar_layer.visible = false

func show_unit_selector() -> void:
	unit_selector_layer.visible = true
	refresh_unit_selector()

func hide_unit_selector() -> void:
	unit_selector_layer.visible = false

func _on_skill_card_pressed(skill_index: int) -> void:
	var selected_skill = select_skill(skill_index)
	if not selected_skill:
		return

	var current_state = state_machine.current_state
	if not current_state:
		return

	if current_state is BaseStateMachine and current_state.name == "MainState":
		var main_state_machine = current_state as BaseStateMachine
		if main_state_machine.current_state and main_state_machine.current_state.name == "AttackState":
			main_state_machine.change_state("SkillState")

func _on_unit_died(unit: Unit) -> void:
	if unit in active_units:
		var died_index = active_units.find(unit)
		active_units.erase(unit)
		all_units.remove_unit_and_update_index(died_index)
		dying_units.append(unit)
		unit.tree_exited.connect(_on_dying_unit_freed.bind(unit))
		refresh_unit_selector()
		print("Battle: Unit moved to dying list. Active: ", active_units.size(), ", Dying: ", dying_units.size())

## 死亡单位正式释放时从 dying_units 中移除
func _on_dying_unit_freed(unit: Unit) -> void:
	dying_units.erase(unit)
	print("Battle: Dying unit freed. Dying: ", dying_units.size())

## 备份游戏状态（更新 all_units 中的 b_unit 快照）
func backup_game_state() -> void:
	for i in range(all_units.get_count()):
		var unit = all_units.get_unit_by_index(i)
		if unit:
			var cell_pos = game_area.game_grid.get_unit_position(unit)
			var b_unit = unit.create_b_unit(cell_pos)
			all_units.units_dict[i + 1]["b_unit"] = b_unit
	print("Battle: Game state backed up.")

## 备份回溯状态（临时）
func backup_state() -> void:
	game_reseter.backup_rollback_state(all_units)

## 执行回溯重置
func reset_state() -> void:
	range_selector.clear_all_ranges()
	path_painter.clear_all_paths()
	hide_skull()
	clear_selected_skill(false)
	set_can_switch_friendly_unit(false)

	active_units = game_reseter.reset_to_rollback_state(unit_spawner, active_units, dying_units, all_units)
	dying_units.clear()
	refresh_unit_selector()

	print("Battle: State reset.")
	state_machine.change_state("MainState")

## 切换到下一个单位
func switch_to_next_unit() -> int:
	return all_units.switch_to_next()

## 在指定单位头顶显示骷髅图标
func show_skull_on_unit(unit: Unit) -> void:
	if not unit: return

	if not _icon_skull:
		_icon_skull = ICON_SKULL.instantiate()
		add_child(_icon_skull)

	hide_skull()

	var target_pos = unit.position + Vector2(0, -16)
	_icon_skull.position = target_pos

	var faction = unit.get_faction()
	var target_color = Color.GREEN if faction == Unit.Faction.FRIENDLY else Color.RED

	_icon_skull.show()
	_icon_skull.tween_color(target_color)

## 隐藏骷髅图标
func hide_skull() -> void:
	if _icon_skull:
		_icon_skull.hide()
		_icon_skull.modulate = Color.WHITE

## 清空回溯状态
func clear_rollback_state() -> void:
	game_reseter.clear_rollback_state()
