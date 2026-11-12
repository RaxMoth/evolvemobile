class_name SafeArea
extends RefCounted

## The display's safe area (a notch, a punch-hole camera, the home indicator),
## mapped into the viewport: the one place the project reads it. The game
## draws edge to edge (stretch aspect "expand"); MenuRoot and the MatchHud's
## Root fit themselves inside the safe area with fit() in _ready and on the
## viewport's size_changed, so the menus' top bar and nav bar and the match's
## top bar and bottom cards stay clear of the cut-outs. Outside them the
## screen shows the clear colour (menus) or the world (a match).
##
## Only a phone reports a safe area that matters: on desktop
## get_display_safe_area() is the screen minus the menu bar and the dock, in
## screen coordinates, and has nothing to do with the window, so everywhere
## but on a mobile build the insets are zero (and every headless run, test and
## sim lays out as before). Not checked on a device yet.

## Insets (x = top, y = bottom, viewport px) used instead of the display's,
## for tests and previews; negative = none.
static var simulated := Vector2(-1.0, -1.0)


## The insets at the top (x) and the bottom (y) of `viewport`, in its own
## (stretched) pixels.
static func insets(viewport: Viewport) -> Vector2:
	if simulated.x >= 0.0 and simulated.y >= 0.0:
		return simulated
	if viewport == null or not OS.has_feature("mobile"):
		return Vector2.ZERO
	var window := Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size())
	return from_display(DisplayServer.get_display_safe_area(), window, viewport.get_visible_rect().size)


## The pure mapping: the safe rect and the window rect in screen pixels, and
## the viewport's visible size -> the top and bottom insets in viewport px.
## The canvas stretches the window's height onto the viewport's.
static func from_display(safe: Rect2i, window: Rect2i, view: Vector2) -> Vector2:
	if window.size.y <= 0 or safe.size.y <= 0:
		return Vector2.ZERO
	var k := view.y / float(window.size.y)
	var top := maxf(float(safe.position.y - window.position.y), 0.0)
	var bottom := maxf(float(window.end.y - safe.end.y), 0.0)
	return Vector2(top, bottom) * k


## Insets a full-rect `control` by the safe area: its top and bottom offsets.
static func fit(control: Control) -> void:
	var inset := insets(control.get_viewport())
	control.offset_top = inset.x
	control.offset_bottom = -inset.y
