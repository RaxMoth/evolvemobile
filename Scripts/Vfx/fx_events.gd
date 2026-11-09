class_name FxEvents
extends RefCounted

## Names for EventBus.ability_event: moments INSIDE an ability's lifetime that
## the cast notifier (ability_cast) cannot see. Gameplay scripts emit them at
## points they already reach, after their own state change; only the
## presentation layer listens. Arguments: (source, ability, event, pos, value).
## The emits and their listeners (per-ability effects, telegraphs) land with
## the ability recipes (Phase 7); VfxManager's core listens to damage only.

const SLAM_LEAP := &"slam_leap"            # source = caster, pos = landing, value = airtime
const SLAM_LANDED := &"slam_landed"        # pos = impact, value = radius
const DASH_STARTED := &"dash_started"      # pos = end point, value = hit radius
const DASH_ENDED := &"dash_ended"
const MINE_ARMED := &"mine_armed"          # source = mine node, value = trigger radius
const MINE_EXPLODED := &"mine_exploded"    # pos, value = radius
const KIT_LANDED := &"kit_landed"          # source = kit node, value = pickup radius
const KIT_PICKED := &"kit_picked"          # source = healed hero, value = heal
const HEAL_SHOT := &"heal_shot"            # source = healer, pos = healed hero, value = heal
const SHIELD_UP := &"shield_up"            # source = the Shield node (owner_hero rides it)
const SHIELD_HIT := &"shield_hit"          # source = shielded hero, value = absorbed
const SHIELD_BROKEN := &"shield_broken"
const SHIELD_EXPIRED := &"shield_expired"
const TAUNTED := &"taunted"                # source = taunted enemy, pos = taunter, value = duration
const CAGE_CLOSED := &"cage_closed"        # source = cage node, value = radius
const CAGE_OPENED := &"cage_opened"
const LAST_STAND := &"last_stand"          # source = the hero saved at 1 HP, value = invulnerable seconds
