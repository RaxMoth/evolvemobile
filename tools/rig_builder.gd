class_name RigBuilder
extends RefCounted

## Turns one character's hand-written SVG parts into its runtime rig:
##   <root>/<id>/src/rig_src.json   canvas, baseline, optional sheet_scale and
##     the part list (name, z, pivot, parent, stages)
##   <root>/<id>/src/parts/<p>.svg  each part alone on the full canvas
##     (src/ carries a .gdignore: the sources are never imported or exported)
## ->
##   <root>/<id>/<id>_sheet.svg     ONE atlas: every part cropped to its alpha
##     box (+PAD) and shelf-packed. Still an SVG: Godot rasterises it on import
##     at `sheet_scale` px per unit, with mipmaps (one texture per character,
##     so all its parts batch into one draw)
##   <root>/<id>/<id>_body.tscn     the RigBody scene: one Sprite2D per part
##     (region of the sheet), arranged in the art's joint hierarchy, drawn in
##     the art's z order
## <root> is res://Assets/Characters (the game's characters) or
## res://test/fixtures (test_rig_pipeline's fixture character).
##
## Draw order without z_index (z_index is global: a part would draw over OTHER
## entities): children draw after their parent, `show_behind_parent` puts a
## lower-z child before it. When a branch must interleave with a sibling branch
## (a humanoid's cape and back arm hang from the body but draw behind the
## legs), the lower-z children move under a proxy node "<part>__back" placed
## among the siblings; the rig copies the part's local transform onto the proxy
## each animated frame (RigBody.sync_proxies). Anything still out of order is an
## art error (reported, nothing written), as is an SVG id used by two parts (the
## parts share one sheet document, so a clip-path would resolve to the wrong one).
##
## Deterministic text output (sorted keys, fixed float formatting): the golden
## test (test_rig_pipeline.gd) rebuilds in memory and compares with the files.

const ROOT := "res://Assets/Characters"
const FIXTURE_ROOT := "res://test/fixtures"
const ROOTS: Array[String] = [ROOT, FIXTURE_ROOT]
const DEFAULT_SHEET_SCALE := 3.0
const PAD := 2
const SHEET_WIDTH := 256
const MEASURE_SCALE := 2.0
const BODY_SCRIPT := "res://Scripts/Rig/rig_body.gd"
## The body root's material; every node under it uses its parent's, so the
## whole body draws through one shared material (one batch per character, and
## per species across mobs): the hit flash (hit_flash.gdshader).
const BODY_MATERIAL := "res://Assets/Shaders/hit_flash_material.tres"

var id: String
var dir: String
var errors: PackedStringArray = []
var sheet_svg: String = ""
var body_tscn: String = ""
var import_cfg: String = ""

var _canvas := Vector2(128, 160)
var _origin := Vector2(64, 150)
var _scale := DEFAULT_SHEET_SCALE
var _parts: Array[Dictionary] = []  ## z order
var _by_name: Dictionary = {}
var _sheet_size := Vector2i.ZERO


## Ids of the characters under `root` that have a src/rig_src.json, sorted.
static func character_dirs(root: String = ROOT) -> PackedStringArray:
	var out: PackedStringArray = []
	var d := DirAccess.open(root)
	if d == null:
		return out
	for sub in d.get_directories():
		if FileAccess.file_exists("%s/%s/src/rig_src.json" % [root, sub]):
			out.append(sub)
	out.sort()
	return out


## The root (of ROOTS) holding character `character_id`, or "" when none does.
static func root_of(character_id: String) -> String:
	for root in ROOTS:
		if FileAccess.file_exists("%s/%s/src/rig_src.json" % [root, character_id]):
			return root
	return ""


func _init(character_id: String, root: String = ROOT) -> void:
	id = character_id
	dir = "%s/%s" % [root, id]


func sheet_path() -> String:
	return "%s/%s_sheet.svg" % [dir, id]


func body_path() -> String:
	return "%s/%s_body.tscn" % [dir, id]


## Builds every output in memory. false (and `errors`) when the source is broken.
func build() -> bool:
	var src := FileAccess.get_file_as_string("%s/src/rig_src.json" % dir)
	var data: Variant = JSON.parse_string(src)
	if not (data is Dictionary):
		errors.append("%s: rig_src.json does not parse" % id)
		return false
	var d: Dictionary = data
	var canvas: Array = d.get("canvas", [128, 160])
	_canvas = Vector2(float(canvas[0]), float(canvas[1]))
	_origin = Vector2(_canvas.x * 0.5, float(d.get("baseline", _canvas.y - 10.0)))
	_scale = float(d.get("sheet_scale", DEFAULT_SHEET_SCALE))
	for p: Dictionary in d.get("parts", []) as Array:
		var stages: Array = p.get("stages") if p.get("stages") is Array else []
		var part := {
			"name": String(p["name"]),
			"z": int(p["z"]),
			"pivot": Vector2(float(p["pivot"][0]), float(p["pivot"][1])),
			"parent": String(p.get("parent", "")),
			"stages": stages,
			"svg": FileAccess.get_file_as_string("%s/src/parts/%s.svg" % [dir, p["name"]]),
		}
		if String(part.svg).is_empty():
			errors.append("%s: missing src/parts/%s.svg" % [id, part.name])
			continue
		_parts.append(part)
		_by_name[part.name] = part
	_parts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.z) < int(b.z))
	var svg_ids: Dictionary[String, String] = {}  # SVG element id -> part using it
	for p in _parts:
		if p.parent != "" and not _by_name.has(p.parent):
			errors.append("%s: part %s hangs from unknown part %s" % [id, p.name, p.parent])
		if not _measure(p):
			errors.append("%s: part %s is empty" % [id, p.name])
		for m in RegEx.create_from_string("\\bid=\"([^\"]+)\"").search_all(String(p.svg)):
			var svg_id := m.get_string(1)
			if svg_ids.has(svg_id):
				errors.append("%s: SVG id %s is used by parts %s and %s" % [id, svg_id, svg_ids[svg_id], p.name])
			svg_ids[svg_id] = String(p.name)
	if not errors.is_empty():
		return false
	_pack()
	var tree := _arrange()
	if tree.is_empty():
		return false
	sheet_svg = _write_sheet()
	body_tscn = _write_body(tree)
	import_cfg = _write_import()
	return true


## Alpha box of the part in canvas units (rasterised by the same ThorVG that
## imports the sheet), padded and clamped to the canvas.
func _measure(p: Dictionary) -> bool:
	var img := Image.new()
	if img.load_svg_from_string(p.svg, MEASURE_SCALE) != OK:
		return false
	var used := img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return false
	var x0 := floori(used.position.x / MEASURE_SCALE) - PAD
	var y0 := floori(used.position.y / MEASURE_SCALE) - PAD
	var x1 := ceili(used.end.x / MEASURE_SCALE) + PAD
	var y1 := ceili(used.end.y / MEASURE_SCALE) + PAD
	p.box = Rect2i(x0, y0, x1 - x0, y1 - y0)
	return true


## Shelf packing, tallest first (stable on name), cells PAD apart.
func _pack() -> void:
	var order: Array[Dictionary] = _parts.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ha: int = (a.box as Rect2i).size.y
		var hb: int = (b.box as Rect2i).size.y
		return ha > hb if ha != hb else String(a.name) < String(b.name))
	var x := 0
	var y := 0
	var shelf_h := 0
	for p in order:
		var cell_size: Vector2i = (p.box as Rect2i).size
		if x > 0 and x + cell_size.x > SHEET_WIDTH:
			x = 0
			y += shelf_h
			shelf_h = 0
		p.cell = Vector2i(x, y)
		x += cell_size.x
		shelf_h = maxi(shelf_h, cell_size.y)
	_sheet_size = Vector2i(SHEET_WIDTH, y + shelf_h)


## Node layout realising the z order. Returns [{name, parent_path, part|proxy}...]
## in tree (= file) order, or [] on an unrealisable layout.
func _arrange() -> Array[Dictionary]:
	var children: Dictionary = {}  # tree parent name ("" = root) -> Array of names
	for p in _parts:
		(children.get_or_add(p.parent, []) as Array).append(p.name)
	# Proxies: a child branch that must draw on the other side of a SIBLING root
	# branch (a cape behind the legs, a head over the front leg) moves under
	# "<part>__back" / "<part>__front" placed among the root branches.
	var proxies: Dictionary = {}  # proxy name -> {source, z, members}
	var roots: Array = children.get("", [])
	for r: String in roots:
		var rz: int = _by_name[r].z
		for c: String in (children.get(r, []) as Array).duplicate():
			var lo := _min_z(c, children)
			var hi := _max_z(c, children)
			var side := ""
			for other: String in roots:
				var oz: int = _by_name[other].z
				if other == r:
					continue
				if hi < rz and oz > hi and oz < rz:
					side = "__back"
				elif lo > rz and oz > rz and oz < lo:
					side = "__front"
			if side.is_empty():
				continue
			var proxy := r + side
			var info: Dictionary = proxies.get_or_add(proxy, {"source": r, "z": lo, "members": []})
			info.z = mini(int(info.z), lo)
			(info.members as Array).append(c)
			(children[r] as Array).erase(c)
	# Emit the draw sequence and the node list together.
	var nodes: Array[Dictionary] = []
	var seq: PackedStringArray = []
	var top: Array[Dictionary] = []
	for r: String in roots:
		top.append({"name": r, "z": int(_by_name[r].z), "proxy": false})
	for px: String in proxies:
		top.append({"name": px, "z": int(proxies[px].z), "proxy": true})
	top.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.z) < int(b.z))
	for t in top:
		if t.proxy:
			var info: Dictionary = proxies[t.name]
			nodes.append({"name": t.name, "path": ".", "proxy": info.source})
			var members: Array = info.members
			members.sort_custom(func(a: String, b: String) -> bool: return int(_by_name[a].z) < int(_by_name[b].z))
			for m: String in members:
				_emit(m, String(t.name), children, nodes, seq, String(info.source))
		else:
			_emit(String(t.name), ".", children, nodes, seq, "")
	var want: PackedStringArray = []
	for p in _parts:
		want.append(p.name)
	if seq != want:
		errors.append("%s: draw order %s cannot follow z order %s with this parenting" % [id, ",".join(seq), ",".join(want)])
		return []
	return nodes


func _min_z(n: String, children: Dictionary) -> int:
	var z: int = _by_name[n].z
	for c: String in children.get(n, []):
		z = mini(z, _min_z(c, children))
	return z


func _max_z(n: String, children: Dictionary) -> int:
	var z: int = _by_name[n].z
	for c: String in children.get(n, []):
		z = maxi(z, _max_z(c, children))
	return z


## Depth first: lower-z children (show_behind_parent) before the part, the rest after.
func _emit(n: String, tree_parent: String, children: Dictionary, nodes: Array[Dictionary],
		seq: PackedStringArray, pivot_parent: String) -> void:
	var p: Dictionary = _by_name[n]
	var kids: Array = (children.get(n, []) as Array).duplicate()
	kids.sort_custom(func(a: String, b: String) -> bool: return int(_by_name[a].z) < int(_by_name[b].z))
	var behind: Array = kids.filter(func(c: String) -> bool: return int(_by_name[c].z) < int(p.z))
	var front: Array = kids.filter(func(c: String) -> bool: return int(_by_name[c].z) > int(p.z))
	var pivot_of_parent: Vector2 = _origin
	var pp: String = pivot_parent if pivot_parent != "" else String(p.parent)
	if pp != "":
		pivot_of_parent = _by_name[pp].pivot
	nodes.append({"name": n, "path": tree_parent, "part": p, "behind": int(p.z) < _parent_z(p),
		"pos": (Vector2(p.pivot) - pivot_of_parent) * _scale})
	var here := n if tree_parent == "." else "%s/%s" % [tree_parent, n]
	for c: String in behind:
		_emit(c, here, children, nodes, seq, "")
	seq.append(n)
	for c: String in front:
		_emit(c, here, children, nodes, seq, "")


func _parent_z(p: Dictionary) -> int:
	return int(_by_name[p.parent].z) if p.parent != "" and _by_name.has(p.parent) else -(1 << 30)


static func _inner(svg: String) -> String:
	var open := svg.find("<svg")
	var start := svg.find(">", open) + 1
	var end := svg.rfind("</svg>")
	return svg.substr(start, end - start)


func _write_sheet() -> String:
	var s := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">\n' % [
		_sheet_size.x, _sheet_size.y, _sheet_size.x, _sheet_size.y]
	s += "<!-- GENERATED by tools/build_rigs.sh from src/ (do not edit). -->\n"
	for p in _parts:
		var box: Rect2i = p.box
		var cell: Vector2i = p.cell
		s += '<g id="%s" transform="translate(%d %d)">%s</g>\n' % [p.name, cell.x - box.position.x, cell.y - box.position.y, _inner(p.svg)]
	return s + "</svg>\n"


static func _f(v: float) -> String:
	return String.num(v, 3)


static func _v(v: Vector2) -> String:
	return "Vector2(%s, %s)" % [_f(v.x), _f(v.y)]


func _write_body(nodes: Array[Dictionary]) -> String:
	var bounds := Rect2()
	var first := true
	for p in _parts:
		var r := Rect2(Vector2((p.box as Rect2i).position) - _origin, Vector2((p.box as Rect2i).size))
		bounds = r if first else bounds.merge(r)
		first = false
	var stage_parts: PackedStringArray = []
	var proxies: PackedStringArray = []
	var order: PackedStringArray = []
	for p in _parts:
		order.append('"%s"' % p.name)
		if not (p.stages as Array).is_empty():
			var st: PackedStringArray = []
			for s: Variant in p.stages:
				st.append(str(int(s)))
			stage_parts.append('"%s": PackedInt32Array(%s)' % [p.name, ", ".join(st)])
	for n in nodes:
		if n.has("proxy"):
			proxies.append('"%s": "%s"' % [n.name, n.proxy])
	var t := '[gd_scene load_steps=4 format=3]\n\n'
	t += '[ext_resource type="Script" path="%s" id="1_body"]\n' % BODY_SCRIPT
	t += '[ext_resource type="Texture2D" path="%s" id="2_sheet"]\n' % sheet_path()
	t += '[ext_resource type="Material" path="%s" id="3_material"]\n\n' % BODY_MATERIAL
	t += '[node name="%sBody" type="Node2D"]\n' % id.to_pascal_case()
	t += "texture_filter = 4\nmaterial = ExtResource(\"3_material\")\nscript = ExtResource(\"1_body\")\n"
	t += 'character_id = &"%s"\nsheet_scale = %s\norigin = %s\n' % [id, _f(_scale), _v(_origin)]
	t += "bounds = Rect2(%s, %s, %s, %s)\n" % [_f(bounds.position.x), _f(bounds.position.y), _f(bounds.size.x), _f(bounds.size.y)]
	t += "part_order = PackedStringArray(%s)\n" % ", ".join(order)
	t += "stage_parts = {%s}\n" % ", ".join(stage_parts)
	t += "proxies = {%s}\n" % ", ".join(proxies)
	for n in nodes:
		t += "\n"
		if n.has("proxy"):
			var src: Dictionary = _by_name[n.proxy]
			t += '[node name="%s" type="Node2D" parent="%s"]\n' % [n.name, n.path]
			t += "use_parent_material = true\n"
			t += "position = %s\n" % _v((Vector2(src.pivot) - _origin) * _scale)
			continue
		var p: Dictionary = n.part
		var box: Rect2i = p.box
		var cell: Vector2i = p.cell
		t += '[node name="%s" type="Sprite2D" parent="%s"]\n' % [n.name, n.path]
		t += "unique_name_in_owner = true\n"
		t += "use_parent_material = true\n"
		if n.behind:
			t += "show_behind_parent = true\n"
		var stages: Array = p.stages
		if not stages.is_empty() and not stages.has(1.0) and not stages.has(1):
			t += "visible = false\n"
		t += "position = %s\n" % _v(n.pos)
		t += 'texture = ExtResource("2_sheet")\ncentered = false\n'
		t += "offset = %s\n" % _v((Vector2(box.position) - Vector2(p.pivot)) * _scale)
		t += "region_enabled = true\n"
		t += "region_rect = Rect2(%s, %s, %s, %s)\n" % [_f(cell.x * _scale), _f(cell.y * _scale), _f(box.size.x * _scale), _f(box.size.y * _scale)]
	return t


func _write_import() -> String:
	return ('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\n'
		+ "compress/mode=0\nmipmaps/generate=true\nmipmaps/limit=-1\n"
		+ "process/fix_alpha_border=true\nprocess/premult_alpha=false\n"
		+ "detect_3d/compress_to=0\nsvg/scale=%s\n" % _f(_scale))


## The res:// paths write() creates or rewrites: sheet, its .import, body.
func output_paths() -> PackedStringArray:
	return PackedStringArray([sheet_path(), sheet_path() + ".import", body_path()])


## Writes the outputs; the .import only when missing or its svg/scale changed
## (Godot adds uid / dest_files to it on the next import).
func write() -> Error:
	for pair: Array in [[sheet_path(), sheet_svg], [body_path(), body_tscn]]:
		var out := FileAccess.open(String(pair[0]), FileAccess.WRITE)
		if out == null:
			return FileAccess.get_open_error()
		out.store_string(String(pair[1]))
	var imp := sheet_path() + ".import"
	var old := FileAccess.get_file_as_string(imp)
	if old.is_empty() or not old.contains("svg/scale=%s" % _f(_scale)) or not old.contains("mipmaps/generate=true"):
		var cfg := FileAccess.open(imp, FileAccess.WRITE)
		if cfg == null:
			return FileAccess.get_open_error()
		cfg.store_string(import_cfg)
	return OK
