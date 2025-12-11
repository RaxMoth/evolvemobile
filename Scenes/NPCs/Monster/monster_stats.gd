extends Resource
class_name MonsterStats

@export_group("Identity")
@export var monster_name: String = "Unknown Monster"
@export var monster_type: String = "Boss"

@export_group("Evolution Thresholds")
@export var stage_2_xp: int = 100
@export var stage_3_xp: int = 300

@export_group("Stage 1 Stats")
@export var stage_1_health: float = 800.0
@export var stage_1_speed: float = 60.0
@export var stage_1_damage_multiplier: float = 1.0
@export var stage_1_scale: Vector2 = Vector2.ONE
@export var stage_1_xp_value: float = 100.0
@export var stage_1_strafe_speed: float = 60.0
@export var stage_1_strafe_interval: float = 2.0

@export_group("Stage 2 Stats")
@export var stage_2_health: float = 1400.0
@export var stage_2_speed: float = 80.0
@export var stage_2_damage_multiplier: float = 1.4
@export var stage_2_scale: Vector2 = Vector2(1.25, 1.25)
@export var stage_2_xp_value: float = 200.0
@export var stage_2_strafe_speed: float = 75.0
@export var stage_2_strafe_interval: float = 1.5

@export_group("Stage 3 Stats")
@export var stage_3_health: float = 2200.0
@export var stage_3_speed: float = 110.0
@export var stage_3_damage_multiplier: float = 2.0
@export var stage_3_scale: Vector2 = Vector2(1.5, 1.5)
@export var stage_3_xp_value: float = 400.0
@export var stage_3_strafe_speed: float = 90.0
@export var stage_3_strafe_interval: float = 1.0

# ============================================
# Helper Methods
# ============================================

func get_health_for_stage(stage: int) -> float:
	match stage:
		1: return stage_1_health
		2: return stage_2_health
		3: return stage_3_health
		_: return stage_1_health

func get_speed_for_stage(stage: int) -> float:
	match stage:
		1: return stage_1_speed
		2: return stage_2_speed
		3: return stage_3_speed
		_: return stage_1_speed

func get_damage_mult_for_stage(stage: int) -> float:
	match stage:
		1: return stage_1_damage_multiplier
		2: return stage_2_damage_multiplier
		3: return stage_3_damage_multiplier
		_: return stage_1_damage_multiplier

func get_scale_for_stage(stage: int) -> Vector2:
	match stage:
		1: return stage_1_scale
		2: return stage_2_scale
		3: return stage_3_scale
		_: return stage_1_scale

func get_xp_value_for_stage(stage: int) -> float:
	match stage:
		1: return stage_1_xp_value
		2: return stage_2_xp_value
		3: return stage_3_xp_value
		_: return stage_1_xp_value

func get_strafe_speed_for_stage(stage: int) -> float:
	match stage:
		1: return stage_1_strafe_speed
		2: return stage_2_strafe_speed
		3: return stage_3_strafe_speed
		_: return stage_1_strafe_speed

func get_strafe_interval_for_stage(stage: int) -> float:
	match stage:
		1: return stage_1_strafe_interval
		2: return stage_2_strafe_interval
		3: return stage_3_strafe_interval
		_: return stage_1_strafe_interval

func get_xp_threshold_for_stage(stage: int) -> int:
	match stage:
		2: return stage_2_xp
		3: return stage_3_xp
		_: return 999999
