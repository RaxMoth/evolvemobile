# ============================================
# BASE STATS RESOURCE (Read-Only Data)
# ============================================
extends Resource
class_name HeroStats

@export_group("Identity")
@export var hero_name: String = "Unknown Hero"
@export var hero_class: String = "DMG"  # DMG, Tank, Support, etc.
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
