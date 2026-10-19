extends Node

## Verbose gameplay logging. Off by default — the F3 overlay is the debugging
## surface; these prints only exist for console tracing in debug builds.
## Flip at runtime (e.g. from the editor's Remote tree) with Globals.verbose_logs = true.
static var verbose_logs: bool = false


static func debug_log(a: Variant, b: Variant = "", c: Variant = "", d: Variant = "", e: Variant = "", f: Variant = "", g: Variant = "", h: Variant = "") -> void:
	if verbose_logs and OS.is_debug_build():
		print(str(a), str(b), str(c), str(d), str(e), str(f), str(g), str(h))


static func get_entity_from_collider(collider: Node) -> Node2D:
	if collider.has_method("get_owner"):
		var main_owner = collider.get_owner()
		if main_owner and main_owner is Node2D and main_owner != collider:
			return main_owner
	
	if collider.has_method("get_parent"):
		var parent = collider.get_parent()
		if parent and parent is Node2D and parent != collider:
			return parent
	
	return collider if collider is Node2D else null
