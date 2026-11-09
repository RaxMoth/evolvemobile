class_name RigProfile
extends Resource

## Motion tuning of one character's procedural layer (CharacterRig). Shared by
## every instance of the character (per-instance variation comes from the rig's
## private RNG, never from here). Numbers are art units / seconds / radians.

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
## World px/s that counts as a full walk (walk blend 1.0).
@export var full_speed: float = 120.0
## World px travelled per full step cycle (feet do not slide).
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
