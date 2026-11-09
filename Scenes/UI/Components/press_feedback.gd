class_name PressFeedback
extends RefCounted

## The one press feel of the menu kit (cards, stage characters, nav plaques):
## the control shrinks to PRESSED_SCALE while held and springs back with a
## TRANS_BACK tween on release, around its centre. Components connect their
## own button_down / button_up scene-side and call down() / up(); the tween in
## flight is kept in the control's metadata so a quick tap never leaves two
## tweens fighting over `scale`.

const PRESSED_SCALE := Vector2(0.95, 0.95)
const DOWN_TIME := 0.05
const UP_TIME := 0.09
const _META := &"press_feedback_tween"


static func down(control: Control) -> void:
	_tween_to(control, PRESSED_SCALE, DOWN_TIME, Tween.TRANS_QUAD)


static func up(control: Control) -> void:
	_tween_to(control, Vector2.ONE, UP_TIME, Tween.TRANS_BACK)


static func _tween_to(control: Control, target: Vector2, time: float, trans: Tween.TransitionType) -> void:
	if control.has_meta(_META):
		var old := control.get_meta(_META) as Tween
		if old != null and old.is_valid():
			old.kill()
	control.pivot_offset = control.size * 0.5
	var tween := control.create_tween().set_trans(trans).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, ^"scale", target, time)
	control.set_meta(_META, tween)
