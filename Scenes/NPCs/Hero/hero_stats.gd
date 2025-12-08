extends Resource
class_name HeroStats

@export_group("Identity")
@export var hero_name: String = "Unknown Hero"
@export var hero_class: String = "DMG"
@export var description: String = ""
@export var portrait: Texture2D

@export_group("Base Combat Stats")
@export var base_max_health: float = 100.0
@export var base_move_speed: float = 80.0
@export var base_approach_speed: float = 110.0
@export var base_attack_range: float = 50.0
@export var base_attack_damage: float = 10.0

@export_group("Base Behavior")
@export var idle_retarget_time: float = 1.2
@export var idle_wander_radius: float = 160.0
@export var keep_distance: float = 24.0

@export_group("Progression")
@export var health_per_level: float = 10.0
@export var damage_per_level: float = 1.0
@export var speed_per_level: float = 2.0

@export_group("Combat Behavior")
@export var combat_role: Types.CombatRole = Types.CombatRole.MELEE
@export var preferred_distance: float = 50.0
@export var min_distance: float = 30.0
@export var max_distance: float = 150.0
@export var strafe_enabled: bool = true
@export var strafe_speed: float = 60.0
@export var strafe_change_interval: float = 2.0
