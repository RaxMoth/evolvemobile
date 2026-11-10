class_name FxGroundLayer
extends Node2D

## The ground half of AbilityVfx: rings, shield wards, Last Stand halos, cage
## rings, decals and the back half of a cage's stakes. The "Ground" child of
## World.tscn's Vfx/Abilities at absolute z 0, so it draws after the ground
## layers and under every character; `vfx` (wired scene-side) owns the data
## and redraws this canvas only while something on the ground is alive.

@export var vfx: AbilityVfx


func _draw() -> void:
	if vfx != null:
		vfx.paint_ground(self)
