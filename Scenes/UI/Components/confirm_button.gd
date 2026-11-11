class_name ConfirmButton
extends Button

## A button whose action needs a second tap (Reset Progress, Quit to lobby).
## The first tap arms it (armed_changed(true): the owner shows "Tap again
## ..."); a tap while it is armed disarms it (armed_changed(false)) and
## reports confirmed. Two rules keep an accident out:
##   - the confirming tap counts only MIN_GAP seconds after the arming one,
##     so the two taps of one double tap (or a bouncing finger) never confirm;
##   - an armed button that is not confirmed within arm_time disarms itself
##     (armed_changed(false)).
## The time since the arming tap is one counter (_process, only while armed),
## so arming again starts a fresh window and disarm() leaves nothing running.
## ConfirmButton.tscn is the crimson ButtonMonster with its own pressed wired
## to the script; the owner instances it, connects armed_changed and confirmed
## in its scene, sets the texts and calls disarm() when it opens again.

signal armed_changed(armed: bool)
signal confirmed

## Seconds after arming before a tap confirms.
const MIN_GAP := 0.6

## Seconds the armed button waits for its second tap.
@export var arm_time: float = 3.0

var _armed := false
var _armed_for := 0.0


func _ready() -> void:
	set_process(false)


func is_armed() -> bool:
	return _armed


## Back to the unarmed state (armed_changed(false) when it was armed).
func disarm() -> void:
	if not _armed:
		return
	_armed = false
	set_process(false)
	armed_changed.emit(false)


func _process(delta: float) -> void:
	_armed_for += delta
	if _armed_for >= arm_time:
		disarm()


# --- scene-side connections (ConfirmButton.tscn) ---

func _on_pressed() -> void:
	if not _armed:
		_armed = true
		_armed_for = 0.0
		set_process(true)
		armed_changed.emit(true)
		return
	if _armed_for < MIN_GAP:
		return
	disarm()
	confirmed.emit()
