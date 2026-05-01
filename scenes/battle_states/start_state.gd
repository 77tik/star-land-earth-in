extends BaseState

func _on_enter() -> void:
	var unit = battle.get_main_unit()
	if not unit:
		push_warning("StartState: No unit found!")
		return

	battle.clear_selected_skill(false)
	battle.refresh_skill_bar()
	battle.hide_skill_bar()
	battle.show_skull_on_unit(unit)

	if unit.get_faction() != Unit.Faction.FRIENDLY:
		battle.hide_skill_bar()
		parent_fsm.change_state("EnemyState")
	else:
		parent_fsm.change_state("MainState")
