extends Resource
class_name MonsterVisualConfig

@export var stage_1_sprite_frames: SpriteFrames
@export var stage_2_sprite_frames: SpriteFrames
@export var stage_3_sprite_frames: SpriteFrames

@export var stage_1_animation_name: String = "default"
@export var stage_2_animation_name: String = "default"
@export var stage_3_animation_name: String = "default"

@export var enable_stage_effects: bool = true

func get_sprite_frames_for_stage(stage: int) -> SpriteFrames:
	match stage:
		1: return stage_1_sprite_frames
		2: return stage_2_sprite_frames
		3: return stage_3_sprite_frames
		_: return stage_1_sprite_frames

func get_animation_name_for_stage(stage: int) -> String:
	match stage:
		1: return stage_1_animation_name
		2: return stage_2_animation_name
		3: return stage_3_animation_name
		_: return stage_1_animation_name