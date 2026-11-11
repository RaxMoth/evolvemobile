class_name TapGuard
extends Node

## Keeps a second tap away from what has just appeared. A screen that slides
## in, a sheet that slides up and a result that fades in are live from their
## first frame, so the second tap of a double tap (or a tap aimed at what was
## there before) lands on whatever now sits under the finger: a picker card,
## a scrim that closes the sheet again, a button that is still invisible.
## The owner has one TapGuard child (in its scene) and calls hold(t) with the
## time its appearing takes; until t + GRACE has passed every new pointer
## press (mouse button, touch) in the viewport is swallowed before the GUI
## sees it. Releases and drags pass, so a press that began earlier ends
## normally. Keys and actions (ui_cancel) pass too; is_holding() is there for
## an owner that wants to ignore those as well.
## Game time (it counts down in _process, as the tweens do), so a test steps
## it with the frames; it follows its owner's process mode (the pause menu's
## and the result screen's run while the tree is paused).

## Seconds a guard stays up after the appearing has settled: the rest of a
## double tap's window.
const GRACE := 0.15

var _left := 0.0


func _ready() -> void:
	set_process(false)


## Swallows new presses for `appear_time` + GRACE seconds from now (never
## shortens a hold that is already running).
func hold(appear_time: float) -> void:
	_left = maxf(_left, maxf(appear_time, 0.0) + GRACE)
	set_process(true)


## Ends the hold now.
func release() -> void:
	_left = 0.0
	set_process(false)


func is_holding() -> bool:
	return _left > 0.0


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		release()


func _input(event: InputEvent) -> void:
	if _left <= 0.0:
		return
	var click := event as InputEventMouseButton
	var touch := event as InputEventScreenTouch
	if (click != null and click.pressed) or (touch != null and touch.pressed):
		get_viewport().set_input_as_handled()
