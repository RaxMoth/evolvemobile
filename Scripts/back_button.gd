class_name BackButton
extends RefCounted

## The Android back button (and the Escape key) as one gesture. The project
## turns application/config/quit_on_go_back off, so the OS's back press
## arrives as NOTIFICATION_WM_GO_BACK_REQUEST; the scene's root of the moment
## (MenuRoot in the menu, MatchHud in a match) hands it to press(), which
## replays it as ui_cancel. Every screen, sheet and overlay already treats
## ui_cancel as back (the topmost one takes it), so the back button closes
## what is open first, then pops a screen; MenuRoot leaves the game only when
## nothing took it (the bare lobby).


## Feeds one ui_cancel press through `viewport`'s input pipeline (GUI, then
## _unhandled_input, the topmost node first). True when a node took it.
static func press(viewport: Viewport) -> bool:
	if viewport == null:
		return false
	var back := InputEventAction.new()
	back.action = &"ui_cancel"
	back.pressed = true
	viewport.push_input(back)
	return viewport.is_input_handled()
