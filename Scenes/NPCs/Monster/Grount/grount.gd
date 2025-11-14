# A powerful bull-like monster with:
# - Ability 1: Front Cleave (small frontal cone attack)
# - Ability 2: Ram Dash (charges forward, knockback)
# - Ability 3: Ground Slam (jump + AOE damage)
# ============================================
extends MonsterBase
class_name Grount

func _ready() -> void:
	# Configure bull stats
	max_health = 800.0
	base_move_speed = 65.0
	base_attack_range = 60.0
	
	# Phase thresholds (2 phases)
	phase_health_thresholds = [0.5]  # Phase 2 at 50% HP
	speed_per_phase = 0.25  # 25% faster in phase 2
	
	super._ready()

func _on_phase_entered(new_phase: int, old_phase: int) -> void:
	match new_phase:
		2:
			print(name + " becomes enraged! Attack speed increased!")
			# In phase 2, bull attacks faster
			if ability_1:
				ability_1.cooldown = 1.5  # Faster cleaves
			if ability_2:
				ability_2.cooldown = 6.0  # More frequent charges

func _on_monster_death() -> void:
	print(name + " has been defeated!")
	# Could spawn loot, play death animation, etc.
