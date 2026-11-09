class_name NavArch
extends NavTab

## The raised mossy-stone arch in the middle of the nav bar: HUNT, the lobby.
## Its inner glow (an additive radial light behind the crossed-axes icon) takes
## the chosen side's colour, which NavBar sets from the palette (amber for the
## heroes, crimson for the monster). The glow's pulse is the scene's
## AnimationPlayer (autoplay), so no script runs per frame.

@export var glow_color: Color = Color.WHITE:
	set(v):
		glow_color = v
		if is_node_ready():
			_glow.modulate = glow_color

@onready var _glow: CanvasItem = %Glow


func _ready() -> void:
	super()
	_glow.modulate = glow_color
