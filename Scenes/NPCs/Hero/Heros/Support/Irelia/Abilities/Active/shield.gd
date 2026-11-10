extends Node
class_name Shield

var shield_amount: float = 0.0
var max_shield: float = 0.0
var duration: float = 0.0
var remaining_time: float = 0.0
var owner_hero: Node2D = null

func _ready() -> void:
	remaining_time = duration
	max_shield = shield_amount
	# Canonical damage-modifier pattern: absorb hits aimed at our owner BEFORE
	# they reach _receive_damage (see EventBus header).
	EventBus.damage_requested.connect(_on_damage_requested)


func _exit_tree() -> void:
	if EventBus.damage_requested.is_connected(_on_damage_requested):
		EventBus.damage_requested.disconnect(_on_damage_requested)


func _on_damage_requested(packet: DamagePacket) -> void:
	if packet.canceled or packet.target != owner_hero or shield_amount <= 0.0:
		return
	var remaining: float = absorb_damage(packet.amount)
	if shield_amount > 0.0:
		EventBus.notify_ability_event(owner_hero, null, FxEvents.SHIELD_HIT, owner_hero.global_position,
				packet.amount - remaining)
	packet.amount = remaining
	packet.add_tag("shielded")
	if remaining <= 0.0:
		packet.canceled = true

func _process(delta: float) -> void:
	remaining_time -= delta
	
	if remaining_time <= 0.0:
		_expire_shield()

func absorb_damage(amount: float) -> float:
	var absorbed: float = minf(amount, shield_amount)
	shield_amount -= absorbed
	
	if shield_amount <= 0.0:
		shield_amount = 0.0
		_break_shield()
		return amount - absorbed
	
	return amount - absorbed

## The shield's strength (0..1). Its look is AbilityVfx's ward at the hero's
## feet (FxEvents.SHIELD_*: its alpha follows this); the hero is never tinted.
func get_shield_percent() -> float:
	return shield_amount / max_shield if max_shield > 0 else 0.0

func _break_shield() -> void:
	if is_instance_valid(owner_hero):
		EventBus.notify_ability_event(owner_hero, null, FxEvents.SHIELD_BROKEN, owner_hero.global_position)
	queue_free()

func _expire_shield() -> void:
	if is_instance_valid(owner_hero):
		EventBus.notify_ability_event(owner_hero, null, FxEvents.SHIELD_EXPIRED, owner_hero.global_position)
	queue_free()
