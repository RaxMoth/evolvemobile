class_name FxEvents
extends RefCounted

## Names for EventBus.ability_event: moments INSIDE an ability's lifetime that
## the cast notifier (ability_cast) cannot see. Gameplay scripts emit them at
## points they already reach, after their own state change; only the
## presentation layer listens (AbilityVfx draws them, VfxManager shows the heal
## numbers). Arguments: (source, ability, event, pos, value); `ability` is the
## caster's own copy (its AbilityFxRecipe colours the effect), or null.
## The hero abilities emit theirs since Phase 7 (7.2), the monsters' since
## 7.3: their abilities the SLAM_*, DASH_*, STUNNED and RECRUITED moments,
## MonsterBase the capstone moments (RAMPAGE, SCATTERED, REFORMED; `ability`
## = the monster's passive, whose recipe colours them) and the hero CC that
## skips an Unstoppable monster CC_SHRUGGED.

const SLAM_LEAP := &"slam_leap"            # source = caster, pos = landing, value = airtime
const SLAM_LANDED := &"slam_landed"        # source = caster, pos = impact, value = radius
const DASH_STARTED := &"dash_started"      # source = caster, pos = end point, value = hit radius
const DASH_TURNED := &"dash_turned"        # source = caster, pos = new end point, value = hit radius (Echo Strike)
const DASH_ENDED := &"dash_ended"          # source = caster, pos = where it stopped
const STUNNED := &"stunned"                # source = stunned entity, pos = its feet, value = stun seconds
const RECRUITED := &"recruited"            # source = recruited mob, pos = the stomp, value = seconds in the warband
const RAMPAGE := &"rampage"                # source = monster, pos = its feet, value = HP healed
const SCATTERED := &"scattered"            # source = monster, pos = where the bats burst
const REFORMED := &"reformed"              # source = monster (at the re-form point), pos = where the bats were
const CC_SHRUGGED := &"cc_shrugged"        # source = immune monster, pos = the taunter / the cage
const MINE_ARMED := &"mine_armed"          # source = mine node, pos = mine, value = trigger radius
const MINE_EXPLODED := &"mine_exploded"    # source = mine node, pos, value = radius
const KIT_LANDED := &"kit_landed"          # source = kit node, pos, value = pickup radius
const KIT_PICKED := &"kit_picked"          # source = healed hero, value = HP healed
const HEAL_SHOT := &"heal_shot"            # source = healed ally, pos = healer's mid-body, value = HP healed
const CHAIN_HEAL := &"chain_heal"          # source = chained hero, pos = mid-body it jumped from, value = HP healed
const SHIELD_UP := &"shield_up"            # source = the Shield node (owner_hero rides it), value = shield HP
const SHIELD_HIT := &"shield_hit"          # source = shielded hero, value = absorbed
const SHIELD_BROKEN := &"shield_broken"    # source = shielded hero
const SHIELD_EXPIRED := &"shield_expired"  # source = shielded hero
const TAUNTED := &"taunted"                # source = taunted enemy, pos = taunter, value = duration
const RALLIED := &"rallied"                # source = boosted ally (hero or pet), pos = rallier, value = duration
const CAGE_CLOSED := &"cage_closed"        # source = cage node, pos, value = radius
const CAGE_OPENED := &"cage_opened"        # source = cage node, pos, value = radius
const LAST_STAND := &"last_stand"          # source = the hero saved at 1 HP, value = invulnerable seconds
