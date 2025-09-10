extends Node2D
class_name npc_base_class 

@export_category("basestats")
@export var hp: float = 100;
@export var speed: float = 100;
@export var attack_speed: float = 100;
@export var range: float = 100;


@onready var state_chart: StateChart = %StateChart
