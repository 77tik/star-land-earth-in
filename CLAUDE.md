# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Godot 4.6 isometric SRPG game prototype. A turn-based tactical game using isometric tile maps with A* pathfinding, unit state machines, and skill-based combat.

**Engine**: Godot 4.6 (GDScript)
**Renderer**: Forward Plus, D3D12 on Windows

## Running the Game

Open the project in Godot 4.6 editor and press F5 to run. The main scene is defined in `project.godot` under `[application]`.

## Architecture

### Core Flow: Battle State Machine

The entire game revolves around a **hierarchical state machine** in `scenes/battle/battle.tscn`:

```
BattleStateMachine (root state machine)
├── InitState        → spawns units, sorts by speed, initializes AllUnits
├── StartState       → shows skull on current unit, decides EnemyState vs MainState
├── MainState        → contains sub-states for player turn
│   ├── MoveState    → A* movement, path preview, range display
│   └── AttackState  → attack selection and execution
├── SkillState       → skill sub-state machine (select_origin → get_cast_range → get_skill_range → execute_skill)
├── EnemyState       → AI: finds best path to target, attacks lowest HP enemy
├── SwitchState      → switches to next unit
└── EndState        → cleanup, returns to StartState
```

Each state extends `BaseState` (`scenes/states/base_state.gd`). States receive a `battle: Battle` reference and use `parent_fsm: BaseStateMachine` to transition.

### Key Classes

**Battle** (`scenes/battle/battle.gd`) - Central scene node containing:
- `game_area: GameArea` - TileMap layer for coordinate conversion
- `state_machine: BaseStateMachine` - Active state controller
- `active_units: Array[Unit]` - Units currently in play
- `all_units: AllUnits` - Ordered unit data with turn index tracking
- Tool nodes: `grid_calculator`, `range_selector`, `unit_mover`, `attack_processor`, `knockback_processor`, `game_reseter`

**GameGrid** (`scenes/battle/game_grid/game_grid.gd`) - Grid data structure:
- `grid_data: Dictionary` - Key: Vector2i cell, Value: {unit, terrain, obstacle}
- Terrain enum: `LAND, GRASS, STONE, RIVER`
- Obstacle enum: `ROCK, WOOD, NULL`
- Provides `add_unit`, `remove_unit`, `is_usable`, `get_unit_position`

**Unit** (`scenes/unit/unit.gd`) - Combat entity:
- `faction: Faction` (FRIENDLY/ENEMY)
- `skills: Array[BaseSkill]` - Configurable skill list
- `unit_stat: UnitStat` - Stats resource (atk, def, speed, move_point, etc.)
- Direction system: `NE, NW, SE, SW` mapped from grid vectors

**AllUnits** (`data/battle_units/all_units.gd`) - Turn order manager:
- `units_dict: Dictionary` - key: 1-based index, value: {unit, b_unit}
- `current_unit_index: int` - Active turn index
- `switch_to_next()` - Cycles through all units

**BaseSkill** (`data/skills/base_skill.gd`) - Skill definition:
- `origin_type`: SELF / GLOBAL / RANGE
- `target_filter`: ALL / ENEMY_ONLY / FRIENDLY_ONLY / SELF_ONLY
- `area_range`, `area_shape`, `is_directional` for area definition
- `execute()` applies damage via `battle.attack_processor`

### Tools (in `/scripts/`)

| Class | Purpose |
|-------|---------|
| `GridCalculator` | A* pathfinding, reachable cells calculation, move cost with terrain |
| `RangeCalculator` | Circle/square/diamond range generation, directional range (cones) |
| `RangeSelector` | Visual highlight of grid cells (move range, attack range) |
| `PathPainter` | Visual path line rendering |
| `UnitMover` | Animated unit movement along path |
| `UnitSpawner` | Factory for unit instantiation |
| `AttackProcessor` | Damage calculation with def reduction, sends `show_damage_text` signal |
| `KnockbackProcessor` | Push units along direction, handles collision |
| `GameReseter` | State rollback for undo functionality |

### Autoloads

- `GlobalSignal` - Global event bus: `unit_died`, `show_damage_text`, `show_heal_text`
- `VfxManager` - Visual effects handling

### Data Resources

- `UnitStat` (`data/unit_stats/unit_stat.gd`) - Unit statistics resource
- `BUnit` (`data/battle_units/b_unit.gd`) - Unit snapshot for state backup
- `wolf_sprite_frames.tres` - Animated sprite data for units

## Input

- **Left click**: Context-dependent (move, attack, select)
- **Right click**: Cancel / return to previous state
- **R key**: Reset current turn (rollback via `game_reseter`)
- **Number keys 1-9**: Select skill by index

## State Transition Triggers

- `InitState` → `StartState` after unit spawning
- `StartState` → `EnemyState` (if current unit is ENEMY) or `MainState` (if FRIENDLY)
- `MainState.MoveState` → `AttackState` after movement completes
- `MainState.AttackState` → `SwitchState` after attack
- `SkillState` → returns to `AttackState` after skill execution
- `SwitchState` → `StartState` (loops to next unit or ends turn)