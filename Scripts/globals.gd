extends Node

## Verbose gameplay logging. Off by default — the F3 overlay is the debugging
## surface; these prints only exist for console tracing in debug builds.
## Flip it from code with Globals.verbose_logs = true (a static var, so the
## editor's Remote tree does not list it).
static var verbose_logs: bool = false


func debug_log(a: Variant, b: Variant = "", c: Variant = "", d: Variant = "", e: Variant = "", f: Variant = "", g: Variant = "", h: Variant = "") -> void:
	if verbose_logs and OS.is_debug_build():
		print(str(a), str(b), str(c), str(d), str(e), str(f), str(g), str(h))


## The entity a hit collider belongs to: its scene owner, else its parent,
## else the collider itself (the first of them that is a Node2D).
func get_entity_from_collider(collider: Node) -> Node2D:
	var main_owner: Node = collider.get_owner()
	if main_owner is Node2D and main_owner != collider:
		return main_owner as Node2D

	var parent: Node = collider.get_parent()
	if parent is Node2D and parent != collider:
		return parent as Node2D

	return collider as Node2D
