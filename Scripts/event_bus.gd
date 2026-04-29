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
##   4. damage_applied fires for VFX/UI/analytics listeners

# --- Damage pipeline ---
signal damage_requested(packet: DamagePacket)   ## Emitted before the hit lands. Mutate the packet here.
signal damage_applied(packet: DamagePacket)     ## Emitted after the hit lands. For VFX/UI/audio.
## Emitted after a heal lands. Reserved for the future heal pipeline; not
## emitted by anything yet, but listeners can already subscribe.
@warning_ignore("unused_signal")
signal heal_applied(packet: DamagePacket)

# --- Lifecycle ---
signal entity_died(entity: Node, killer: Node)
signal ability_cast(caster: Node, ability: AbilityBase, target: Node)

# --- State chart bridge ---
## Emitted when any entity's state chart processes an event. Bridged from
## StateChart.event_received in EntityBase._ready(). Lets global systems
## react to per-entity state events without binding to each entity directly.
signal entity_state_event(entity: Node, event: StringName)


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


## Lower-level entry: caller has already built a packet (e.g. with custom tags).
func request_damage(packet: DamagePacket) -> float:
	if packet == null or not is_instance_valid(packet.target):
		return 0.0
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

	damage_applied.emit(packet)
	return packet.amount


## Bridge call from EntityBase: forwards a state chart event to the global bus.
func notify_state_event(entity: Node, event: StringName) -> void:
	entity_state_event.emit(entity, event)


## Called by EntityBase when an entity enters its Dead state.
func notify_died(entity: Node, killer: Node) -> void:
	entity_died.emit(entity, killer)


## Called by AbilitySystem / monster ability dispatcher after a successful cast.
func notify_ability_cast(caster: Node, ability: AbilityBase, target: Node) -> void:
	ability_cast.emit(caster, ability, target)
