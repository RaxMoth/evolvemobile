class_name AbilityFxRecipe
extends Resource

## How one ability LOOKS in the match: the AbilityVfx program that plays it
## (`cue`) and the palette tokens and sizes that program uses. Assigned on the
## ability resource (AbilityBase.fx; the recipes live in
## Assets/Vfx/recipes/fx_<character>_<ability>.tres) and read only by the
## presentation layer (AbilityVfx), never by gameplay, so any value here can
## change without touching tools/sim_trace.sh. Colours are UiPalette token
## names (UiPalette.color), never colour values.
##
## Every copy of an ability shares its recipe (abilities are duplicated per
## entity, the recipe is not): nothing writes it at runtime.

## The AbilityVfx program (AbilityVfx.CUES; &"" = no world effect):
##   strike, claw, sniper (on each hit the ability lands),
##   shield, taunt, rally, weapon_swap, mine, blood_bomb (on the cast),
##   cage, supply_drop, last_stand (on the ability's FxEvents only).
## The FxEvents an ability emits (a ward, a tether, a heal hop) take their
## colours from the same recipe whatever its cue.
@export var cue: StringName = &""

@export_group("Colours (UiPalette tokens)")
## Body of strokes, rings and tinted sprites.
@export var accent: StringName = &"hero"
## Shade: second rings, decals.
@export var shade: StringName = &"hero_dark"
## Hot core of a stroke or a blast.
@export var core: StringName = &"text"
## The ability's second look: River's heal staff (shot, swap), a rally mark,
## a mine's arming ring, a supply drop's leaves.
@export var alt: StringName = &"heal"

@export_group("Size and weight")
## Multiplier on the program's sizes (a smaller swipe, a bigger blast).
@export var size: float = 1.0
## World px the program's area spans; 0 = the ability's own (area_of_effect,
## ability_range, the cage's radius).
@export var radius: float = 0.0
## Camera trauma (GameCamera.add_trauma) at the program's biggest moment.
@export_range(0.0, 1.0) var trauma: float = 0.0
## Seconds a ground decal (blood splat, blast scorch) stays.
@export var decal_life: float = 3.0
