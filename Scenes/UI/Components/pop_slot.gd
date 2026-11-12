class_name PopSlot
extends Control

## A plain Control around content that pops (a scale tween): the LEVEL UP!
## pill, the result ribbon, the NEW QUARRY banner, the match toast.
##
## A container lays its children out whenever one of them changes size or
## visibility, and fit_child_in_rect sets each child's scale back to 1, in the
## same frame, before anything is drawn. A pop on a container's own child is
## undone the frame it starts (a pill shown and popped in one call never
## shows anything but full size). Inside this slot the content is laid out by
## its anchors (full rect in the scenes), so nothing touches its scale; the
## slot takes the content's minimum size, so the container around it places
## it as it placed the content before. The content pops around its centre
## (pivot_offset_ratio in the scenes).


func _ready() -> void:
	for child in get_children():
		var content := child as Control
		if content == null:
			continue
		# The content's own size can change at runtime (a new toast text).
		content.minimum_size_changed.connect(update_minimum_size)
		content.visibility_changed.connect(update_minimum_size)
	update_minimum_size()


## The largest minimum size of the visible content.
func _get_minimum_size() -> Vector2:
	var out := Vector2.ZERO
	for child in get_children():
		var content := child as Control
		if content != null and content.visible:
			out = out.max(content.get_combined_minimum_size())
	return out
