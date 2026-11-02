extends Node
class_name Shield

signal shield_broken
signal shield_expired

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
	packet.amount = remaining
	packet.add_tag("shielded")
	if remaining <= 0.0:
		packet.canceled = true

func _process(delta: float) -> void:
	remaining_time -= delta
	
	if remaining_time <= 0.0:
		_expire_shield()
	
	# Update visual indicator if exists
	_update_visual()

func absorb_damage(amount: float) -> float:
	var absorbed: float = minf(amount, shield_amount)
	shield_amount -= absorbed
	
	if shield_amount <= 0.0:
		shield_amount = 0.0
		_break_shield()
		return amount - absorbed
	
	return amount - absorbed

func get_shield_amount() -> float:
	return shield_amount

func get_shield_percent() -> float:
	return shield_amount / max_shield if max_shield > 0 else 0.0

func _update_visual() -> void:
	if not owner_hero:
		return
	
	# Add blue tint based on shield strength
	var shield_percent = get_shield_percent()
	if shield_percent > 0:
		owner_hero.modulate = Color(1.0, 1.0, 1.0 + shield_percent * 0.5)

func _break_shield() -> void:
	shield_broken.emit()
	if owner_hero:
		owner_hero.modulate = Color.WHITE
	queue_free()

func _expire_shield() -> void:
	shield_expired.emit()
	if owner_hero:
		owner_hero.modulate = Color.WHITE
	queue_free()
