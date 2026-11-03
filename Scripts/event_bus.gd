extends Node

## EventBus - global signal hub for combat events.
##
## Design rule: the state chart owns combat STATE; EventBus is the outbound
## NOTIFIER for systems that don't care about state machines (UI, VFX, audio,
## analytics, skill-tree mods, achievements). Never replace state_chart.send_event
## with EventBus signals — they serve different purposes.
##
## Damage flow:
##   1. Ability calls EventBus.deal_damage(source, target, amount, ability)
##   2. damage_requested fires; listeners may mutate packet.amount or flip packet.canceled
##      (Irelia shield, lifesteal, skill-tree damage mods all hook here)
##   3. If not canceled, target._receive_damage(packet) applies the final amount
##      and may send CombatEvents.SELF_DEAD to its own state chart
##   4. If the target is a living EntityBase, target._on_damage_taken(packet)
##      runs — the per-target reaction hook (flinch, "help!" broadcasts).
##      This is a direct call, NOT a signal: with ~150 entities alive a global
##      subscription that filtered `packet.target != self` cost ~150 callbacks
##      per hit.
##   5. damage_applied fires for TRUE global listeners only (TeamRegistry
##      threat, audio, analytics). Do not subscribe per-entity.

# --- Damage pipeline ---
signal damage_requested(packet: DamagePacket)   ## Emitted before the hit lands. Mutate the packet here.
signal damage_applied(packet: DamagePacket)     ## Emitted after the hit lands. For VFX/UI/audio.

# --- Lifecycle ---
signal entity_died(entity: Node, killer: Node)
signal monster_evolved(monster: Node, stage: int)
signal ability_cast(caster: Node, ability: AbilityBase, target: Node)


## Run an attack through the damage pipeline. Returns the final amount applied
## (post-modifiers, post-cancel). This is the ONLY entry point abilities should
## use — never call target.take_damage() or target._receive_damage() directly.
##
## damage_type defaults to 0 (DamagePacket.DamageType.PHYSICAL). We use the
## raw int here (not the enum reference) because GDScript requires default
## parameter values to be constant expressions, and class-name enum lookups
## across autoload load-order are not always considered constant at parse time.
## Callers should still pass DamagePacket.DamageType.X for readability.
func deal_damage(source: Node, target: Node, amount: float, ability: AbilityBase = null, damage_type: int = 0) -> float:
	if not is_instance_valid(target) or amount <= 0.0:
		return 0.0
	var packet := DamagePacket.make(source, target, amount, ability, damage_type)
	return _route_packet(packet)


func _route_packet(packet: DamagePacket) -> float:
	damage_requested.emit(packet)
	if packet.canceled or packet.amount <= 0.0 or not is_instance_valid(packet.target):
		return 0.0

	var t := packet.target
	if t.has_method("_receive_damage"):
		t._receive_damage(packet)
	else:
		push_warning("EventBus: target ", t, " has no _receive_damage(packet) method. Damage dropped.")
		return 0.0

	# Targeted reaction hook. Guarded: Ted's pet is a valid AoE target but not
	# an EntityBase, and a killing blow skips the flinch on purpose.
	var entity := t as EntityBase
	if entity != null and entity.is_alive():
		entity._on_damage_taken(packet)

	damage_applied.emit(packet)
	return packet.amount


## Called by EntityBase when an entity enters its Dead state.
func notify_died(entity: Node, killer: Node) -> void:
	entity_died.emit(entity, killer)


## Called by MonsterBase._evolve_to_stage after the new stage is applied.
func notify_monster_evolved(monster: Node, stage: int) -> void:
	monster_evolved.emit(monster, stage)


## Called by AbilitySystem / monster ability dispatcher after a successful cast.
func notify_ability_cast(caster: Node, ability: AbilityBase, target: Node) -> void:
	ability_cast.emit(caster, ability, target)
