class_name DamagePacket
extends RefCounted

## DamagePacket - mutable payload that flows through EventBus.request_damage().
## Listeners on EventBus.damage_requested can mutate `amount`, add `tags`, or
## flip `canceled` to fully block the hit. After the pipeline runs, the target's
## _receive_damage(packet) applies the final value, then damage_applied fires.
##
## RefCounted (not Resource) because these are short-lived per-attack objects
## and should not be saved or shown in the inspector.

enum DamageType { PHYSICAL, MAGICAL, TRUE, HEAL }

var source: Node = null            ## Entity that caused the damage (caster). May be null for environment.
var target: Node = null            ## Entity receiving the damage.
var ability: AbilityBase = null    ## Ability resource that dealt this. Null for non-ability damage (debug, environment).
var base_amount: float = 0.0       ## Original requested amount before modifiers. Read-only by convention.
var amount: float = 0.0            ## Current/final amount. Listeners may mutate this.
var damage_type: int = DamageType.PHYSICAL
var tags: PackedStringArray = []   ## Free-form tags ("knockback", "crit", "lifesteal", "dot")
var canceled: bool = false         ## Set true to fully block the hit before it lands.

static func make(source_: Node, target_: Node, amount_: float, ability_: AbilityBase = null, type_: int = 0) -> DamagePacket:
	var p := DamagePacket.new()
	p.source = source_
	p.target = target_
	p.base_amount = amount_
	p.amount = amount_
	p.ability = ability_
	p.damage_type = type_
	return p

func has_tag(tag: String) -> bool:
	return tags.has(tag)

func add_tag(tag: String) -> void:
	if not tags.has(tag):
		tags.append(tag)
