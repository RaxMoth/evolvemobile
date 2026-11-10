class_name RigProfile
extends Resource

## Motion tuning of one character's procedural layer (CharacterRig). Shared by
## every instance of the character (per-instance variation comes from the rig's
## private RNG, never from here). Numbers are art units / seconds / radians.

## HUMANOID: upright on two legs with two arms (the heroes, and the monsters
## Grount and Gorrak). QUADRUPED: on four legs (the Hog, Ted's fox). FLYER:
## wings, hovers (the Bat, Nyxa). It picks the moves library.
enum BodyPlan { HUMANOID, QUADRUPED, FLYER }

@export var body_plan: BodyPlan = BodyPlan.HUMANOID
## World units per art unit (a 120-unit-tall chibi * 0.4 = 48 world px).
@export var world_scale: float = 0.4

@export_group("Idle")
@export var breathe_hz: float = 0.9
## Squash amplitude of the breath (scale fraction).
@export var breathe_amount: float = 0.025
@export var head_bob: float = 1.2

@export_group("Locomotion")
## World px/s that counts as a full walk (walk blend 1.0): the character's
## move speed, so its usual walk swings the legs fully.
@export var full_speed: float = 120.0
## World px travelled per full step cycle. Feet do not slide when it is
## 4 x leg length (hip pivot to sole, art units) x sin(leg_swing) x world_scale.
@export var stride: float = 34.0
@export var bounce: float = 3.0
@export var leg_swing: float = 0.45
@export var arm_swing: float = 0.35
@export var lean: float = 0.12
## FLYER: wing beats per second and amplitude; hover bob in art units.
@export var flap_hz: float = 5.0
@export var flap_amount: float = 0.55
@export var hover: float = 5.0

@export_group("Reactions")
@export var hurt_time: float = 0.18
@export var hurt_squash: float = 0.14
@export var attack_time: float = 0.32
## Front-arm swing of the procedural attack (no authored move): wind-up then strike.
@export var attack_windup: float = -1.1
@export var attack_strike: float = 1.4
@export var attack_lunge: float = 6.0

@export_group("Moves")
## The authored one-shots CharacterRig plays (attack, cast, ultimate, hurt,
## cheer and the signature moves): the body plan's library,
## Assets/Characters/_moves/<plan>_moves.tres (HUMANOID humanoid_moves,
## QUADRUPED quadruped_moves, FLYER flyer_moves). Null = the procedural swing
## only.
@export var moves: AnimationLibrary

@export_group("Ground")
## Contact shadow: the dense core's radius per world px of body width
## (RigBody.bounds width x world_scale; CharacterRig.shadow_radius_for). The
## soft rim reaches CharacterRig.SHADOW_SPREAD times further. A flyer's is
## lower: it hovers above a smaller shadow. 0 = no shadow.
@export var shadow_per_width: float = 0.33
