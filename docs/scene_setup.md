# 场景搭建文档 / Scene Setup Guide

本文档描述如何在 Godot 4.6 中从零搭建与本项目一致的 2.5D 等距战棋战斗场景。

---

## 一、创建项目基础配置

### project.godot 关键配置

```ini
[application]
config/name="Test Isotremic Demo"
run/main_scene="uid://dn3renxk81gfo"   # 指向 battle.tscn
config/features=PackedStringArray("4.6", "Forward Plus")

[autoload]
GlobalSignal="*uid://b4pk1eu0r1x8v"
VfxManager="*uid://c0lbvttq0lsn8"

[display]
window/size/viewport_width=640
window/size/viewport_height=360
window/size/window_width_override=1280
window/size/window_height_override=720
window/stretch/mode="viewport"

[gui]
theme/custom_font="uid://bxe6flnmxsp2l"   # Unifont 点阵字体

[input]
mouse_left  # 左键输入
mouse_right # 右键输入
reset       # R 键重置

[physics]
3d/physics_engine="Jolt Physics"

[rendering]
textures/canvas_textures/default_texture_filter=0
```

---

## 二、创建 TileSet（等距瓦片集）

TileSet 是场景的基础，定义了所有地形、障碍物和 2.5D 渲染参数。

### 2.1 准备资源

使用素材：`assets/Pixel Isometric Tiles from scrabling/isometric tileset/spritesheet.png`

### 2.2 创建 TileSet 资源

1. 在 Godot 编辑器中：**新建资源 → TileSet**
2. 保存为 `assets/battle_tile_set.tres`

### 2.3 TileSet 配置参数

| 参数 | 值 | 说明 |
|------|-----|------|
| tile_shape | Isometric (1) | 等距瓦片形状 |
| tile_layout | Fixed (5) | 固定布局 |
| tile_size | Vector2i(32, 16) | 瓦片尺寸（宽32高16） |

### 2.4 创建 Terrain Set（地形集）

在 TileSet 检查器中创建 `Terrain Set 0`，包含以下 6 种地形：

| 地形名称 | Terrain Index | 颜色 | 说明 |
|----------|---------------|------|------|
| land | 0 | Color(0.5, 0.34375, 0.25) | 默认陆地 |
| grass | 1 | Color(0.5, 0.4375, 0.25) | 草地 |
| stone | 2 | Color(0.84313726, 0.84313726, 0.84313726) | 石地 |
| river | 3 | Color(0.3764706, 0.5568628, 0.9137255) | 河流（不可通行） |
| rock | 4 | Color(0, 0, 0) | 黑色岩石障碍 |
| wood | 5 | Color(0.7058824, 0.5019608, 0.3137255) | 木制障碍 |

### 2.5 创建 Custom Data Layers（自定义数据层）

| 层名称 | 类型 | 说明 |
|--------|------|------|
| terrain | int (2) | 存储地形类型（用于 GameGrid 读取） |
| obstacle | int (2) | 存储障碍物类型（用于路径规划） |

### 2.6 创建瓦片源（TileSetAtlasSource）

1. 添加 `TileSetAtlasSource`
2. 导入 `spritesheet.png`，设置 `texture_region_size = Vector2i(32, 32)`
3. 根据素材图片的行列布局，逐一设置每个格子的地形属性：
   - **陆地/草地/石地/河流格**：在对应行设置 terrain
   - **Rock 障碍格**（坐标 4:4 ~ 8:4）：设置 terrain=5（wood），`texture_origin = Vector2i(0, 8)` 使其与地面层对齐
   - **River 障碍格**（坐标 6:5, 8:5）：设置 terrain=3，custom_data_0=3
4. 通过 `terrains_peering_bit` 关系自动生成地形过渡

### 2.7 地形对应的自定义数据值

在 `battle_tile_set.tres` 中，每个格子的 `custom_data_0` 值与其 terrain 索引对应：

- terrain=0 (land): custom_data_0 不设置或任意
- terrain=1 (grass): custom_data_0 = 1
- terrain=2 (stone): custom_data_0 = 2
- terrain=3 (river): custom_data_0 = 3
- terrain=5 (rock/wood): custom_data_0 = terrain 值

---

## 三、构建场景层级结构

场景节点树：

```
Battle (Node2D)
├── Camera2D
├── HighlightSelector (HighlightSelector)
├── GameArea (TileMapLayer)          # 等距地图主容器
│   └── TileMap (Node2D)
│       ├── MainTileMap (TileMapLayer)      # 主地形层（z_index=0）
│       ├── ObstacleTileMap (TileMapLayer)  # 障碍物层（z_index=1）
│       ├── BaseTileMap-1 (TileMapLayer)    # 底层阴影（z_index=-1, y_offset=8）
│       └── BaseTileMap-2 (TileMapLayer)   # 底层阴影2（z_index=-2, y_offset=16）
├── GameGrid (Node, GameGrid script)  # 网格数据管理
├── BattleStateMachine (Node)        # 状态机根节点
│   ├── InitState
│   ├── StartState
│   ├── MainState (BaseStateMachine)
│   │   ├── MoveState
│   │   ├── AttackState
│   │   └── SkillState (BaseStateMachine)
│   │       ├── GetCastRange
│   │       ├── SelectOrigin
│   │       ├── GetSkillRange
│   │       └── ExecuteSkill
│   ├── EnemyState
│   ├── SwitchState
│   ├── EndState
│   └── FinishState
├── UnitSpawner (Node)
├── GridCalculator (Node)
├── RangeSelector (Node)
├── UnitMover (Node)
├── PathPainter (Node)
├── RangeCalculator (Node)
├── AttackProcessor (Node)
├── KnockbackProcessor (Node)
└── GameReseter (Node)
```

---

## 四、逐节点配置

### 4.1 GameArea（等距地图容器）

**类型**：`TileMapLayer`
**脚本**：`game_area.gd`

**属性**：
- `y_sort_enabled = true` — 开启 Y 轴排序实现 2.5D 深度效果
- `tile_set` — 指向 `battle_tile_set.tres`
- `game_grid` — 引用子节点 `GameGrid`

**功能**：提供坐标转换函数
- `get_tile_from_global(global: Vector2) → Vector2i`
- `get_global_from_tile(tile: Vector2i) → Vector2`
- `get_hovered_tile() → Vector2i`

### 4.2 TileMap 子节点

#### MainTileMap（主地形层）

- **类型**：`TileMapLayer`
- **z_index**：0
- **y_sort_enabled**：true
- **tile_set**：`battle_tile_set.tres`
- **tile_map_data**：使用地块编辑器绘制地形（草地、石地、河流）
- **Position**：默认

#### ObstacleTileMap（障碍物层）

- **类型**：`TileMapLayer`
- **z_index**：1
- **y_sort_enabled**：true
- **tile_set**：`battle_tile_set.tres`
- **tile_map_data**：绘制 Rock/Wood 障碍
- **Position**：默认

#### BaseTileMap-1（底层阴影1）

- **类型**：`TileMapLayer`
- **z_index**：-1
- **y_sort_enabled**：true
- **position**：Vector2(0, 8) — 向下偏移 8 像素制造阴影效果
- **tile_set**：`battle_tile_set.tres`
- **tile_map_data**：与 MainTileMap 相同的地形数据（颜色变暗）

#### BaseTileMap-2（底层阴影2）

- **类型**：`TileMapLayer`
- **z_index**：-2
- **y_sort_enabled**：true
- **position**：Vector2(0, 16) — 向下偏移 16 像素
- **tile_set**：`battle_tile_set.tres`
- **tile_map_data**：与 MainTileMap 相同的地形数据（颜色更暗）

### 4.3 GameGrid（网格数据节点）

**类型**：`Node`
**脚本**：`game_grid.gd`

**子节点引用**：
- `main_tile_map` → MainTileMap
- `obstacle_tile_map` → ObstacleTileMap

**功能**：
- 管理 `grid_data: Dictionary` — 存储每个格子的 unit/terrain/obstacle
- 提供 `add_unit`、`remove_unit`、`is_usable`、`get_unit_position` 等接口
- 监听 `GlobalSignal.unit_died` 自动清理死亡单位

### 4.4 BattleStateMachine（状态机根节点）

**类型**：`Node`
**脚本**：`base_state_machine.gd`

**属性**：
- `initial_state_name = "InitState"`

**子节点**（全部继承 `base_state.gd`）：
- `InitState` → `init_state.gd`
- `StartState` → `start_state.gd`
- `MainState` → `base_state_machine.gd`（子状态机）
  - `MoveState` → `move_state.gd`
  - `AttackState` → `attack_state.gd`
  - `SkillState` → `skill_state_machine.gd`（孙状态机）
    - `GetCastRange` → `get_cast_range.gd`
    - `SelectOrigin` → `select_origin.gd`
    - `GetSkillRange` → `get_skill_range.gd`
    - `ExecuteSkill` → `execute_skill.gd`
- `EnemyState` → `enemy_state.gd`
- `SwitchState` → `switch_state.gd`
- `EndState` → `end_state.gd`
- `FinishState` → `finish_state.gd`

### 4.5 工具节点配置

| 节点名称 | 脚本 | 依赖节点 |
|----------|------|----------|
| UnitSpawner | `unit_spawner.gd` | container → ObstacleTileMap |
| GridCalculator | `grid_calculator.gd` | game_area → GameArea |
| RangeSelector | `range_selector.gd` | game_area → GameArea |
| UnitMover | `unit_mover.gd` | game_area → GameArea |
| PathPainter | `path_painter.gd` | game_area → GameArea |
| RangeCalculator | `range_calculator.gd` | game_area → GameArea |
| AttackProcessor | `attack_processor.gd` | 无 |
| KnockbackProcessor | `knockback_processor.gd` | game_area → GameArea, attack_processor → AttackProcessor |
| GameReseter | `game_reseter.gd` | game_area → GameArea |

---

## 五、Unit（单位）场景配置

创建 `scenes/unit/unit.tscn`：

```
Unit (Area2D)
├── AnimatedSprite2D    # 精灵动画（使用 wolf_sprite_frames.tres）
└── CollisionShape2D     # 碰撞形状（32x32 RectangleShape2D，visible=false）
```

### Unit 节点属性

| 属性 | 值 |
|------|-----|
| y_sort_enabled | true |
| script | unit.gd |
| unit_stat | test_unit.tres |
| skills | [howl_skill, directional_howl_skill, healing_howl_skill, knockback_attack] |

### Unit 脚本属性

- `faction: Faction` — FRIENDLY(绿色) 或 ENEMY(红色)
- `skills: Array[BaseSkill]` — 技能数组
- `unit_stat: UnitStat` — 单位属性数据

### 动画帧命名规则

`{方向}_{状态}`，例如：
- `SE_IDLE`、`NW_RUN`、`NE_ATK`、`SW_DEATH`、`SE_SKILL`
- 方向：NE、NW、SE、SW
- 状态：IDLE、RUN、ATK、DEATH、SKILL

---

## 六、Highlight（高亮）场景

### 6.1 HighlightArea（区域高亮）

创建 `scenes/highlight_area/highlight_area.tscn`：

```
HighlightArea (Polygon2D)
├── polygon = PackedVector2Array(-16, 0, 0, -8, 16, 0, 0, 8, -16, 0)  # 等距菱形
├── color = Color(1, 1, 1, 0.5)
└── HighlightLine (Line2D)
    └── default_color = Color(0, 0, 0, 0.5)
```

### 6.2 HighlightLine（路径高亮）

创建 `scenes/highlight_line/highlight_line.tscn`：

```
HighlightLine (Line2D)
├── points = PackedVector2Array(-16, 0, 0, -8, 16, 0, 0, 8, -16, 0)
└── width = 1.0
```

---

## 七、SpriteFrames（精灵动画帧）配置

创建 `assets/wolf_sprite_frames.tres`，使用 wolf 素材：

### 动画命名

每个方向（NE/NW/SE/SW）有 5 个动画：
- `{方向}_IDLE` — 待机，loop=true, speed=8.0
- `{方向}_RUN` — 移动，loop=true, speed=16.0
- `{方向}_ATK` — 攻击，loop=false, speed=12.0
- `{方向}_DEATH` — 死亡，loop=false, speed=8.0
- `{方向}_SKILL` — 技能，loop=false, speed=8.0

### 素材对应关系

| 动画 | 素材文件 | 行索引 |
|------|----------|--------|
| *_ATK | wolf-bite.png | 第4行（192-256） |
| *_DEATH | wolf-death.png | 第3行（128-192） |
| *_IDLE | wolf-idle.png | 第2行（64-128） |
| *_RUN | wolf-run.png | 第1行（0-64） |
| *_SKILL | wolf-howl.png | 第1行（0-64） |

每个方向 16 帧（2048px 宽度），每个动作占 4 帧区域。

---

## 八、Autoload（全局单例）配置

### GlobalSignal

```gdscript
extends Node

signal unit_died(unit: Unit)
signal show_damage_text(pos: Vector2, damage: int)
signal show_heal_text(pos: Vector2, amount: int)
```

### VfxManager

管理视觉特效的播放。

---

## 九、Input Map 配置

在 project.godot 中配置：

| Action | Input |
|--------|-------|
| mouse_left | 鼠标左键 |
| mouse_right | 鼠标右键 |
| reset | Key R |

---

## 十、创建场景快照

每个场景都需要创建对应的 `.uid` 文件。例如：

- `battle.gd.uid` → `uid://bdhuihooqftao`
- `game_area.gd.uid` → `uid://dsbkrku32wmt6`

这些 UID 在 `.tscn` 文件的 `ext_resource` 路径中使用。

---

## 十一、场景编辑器中绘制地图

在 Godot 编辑器中打开 `battle.tscn`：

1. 选中 `MainTileMap`，使用瓦片编辑器绘制主地形
2. 选中 `ObstacleTileMap`，绘制障碍物
3. 复制 MainTileMap 的内容到 `BaseTileMap-1` 和 `BaseTileMap-2`（保持数据一致但 z_index 和 position 不同）

### 绘制技巧

- 等距瓦片需要在编辑器中正确对齐
- Rock 障碍需要 `texture_origin = (0, 8)` 对齐地面
- River（不可通行）需要设置在 `MainTileMap` 层
- 确保 `y_sort_enabled = true` 以实现正确的深度排序

---

## 十二、验证场景正确性

1. 运行游戏，按 F5
2. 应该看到 2.5D 等距地图，正确显示阴影层
3. FRIENDLY 单位（绿色）和 ENEMY 单位（红色）应该可见
4. 当前单位头顶显示骷髅图标
5. 左键点击移动，右键取消，R 重置
6. 敌方单位自动行动（移动+攻击）