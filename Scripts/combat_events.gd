extends Node

## CombatEvents - Typed StringName constants for state chart events.
## Use these instead of raw strings when calling state_chart.send_event(),
## so the addon's debug-build event-name validation catches typos at runtime
## and the editor can autocomplete.
##
## Add new event names HERE first, then add the matching transition in the
## state chart scene. The addon validates that every send_event() target
## exists as a transition in the chart.

# --- AI / combat lifecycle events ---
const ENEMY_ENTERED := &"enemy_entered"
const ENEMY_EXITED  := &"enemy_exited"
const ENEMY_FIGHT   := &"enemy_fight"
const TARGET_LOST   := &"target_lost"
const RE_APPROACH   := &"re_approach"
const SELF_DEAD     := &"self_dead"

# --- Combat reactions (room to grow) ---
# These are not yet wired into any chart transitions, but reserved as the
# canonical names so VFX/AI/animation systems can listen on EventBus.
const DAMAGED       := &"damaged"
const HEALED        := &"healed"
const STAGE_CHANGED := &"stage_changed"
