class_name NavTab
extends Button

## One carved-wood plaque of the bottom navigation bar (NavPlaque: the
## selected plaque is the lighter wood with the amber rim and label). A toggle
## button in NavBar's ButtonGroup; it reports its tab_id when pressed. A red
## notify dot sits on its top-right corner.

signal chosen(tab_id: StringName)

@export var tab_id: StringName = &""
@export var notify: bool = false:
	set(v):
		notify = v
		if is_node_ready():
			_dot.visible = notify

@onready var _dot: CanvasItem = $Dot


func _ready() -> void:
	_dot.visible = notify


func _on_pressed() -> void:
	chosen.emit(tab_id)


func _on_button_down() -> void:
	PressFeedback.down(self)


func _on_button_up() -> void:
	PressFeedback.up(self)
