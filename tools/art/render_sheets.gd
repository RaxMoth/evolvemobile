extends SceneTree
## Rasterises SVGs with Godot's own loader (ThorVG, the importer's code path)
## and writes one review sheet. Run by build.py on a throwaway project:
##   godot --headless --path <tmp project> -s render_sheets.gd -- <svg_dir> <out_png>
##       <sizes csv> <cols> <prefix csv> <screen hex> <card hex> <sheet hex>
## sizes: "64" = width in px, "x2" = scale factor. prefix "" = every SVG.
## Each cell shows the SVG at every requested size, the first on the screen
## colour, the rest alternating screen / card fill (build.py passes the palette).

const GAP := 10


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 8:
		push_error("render_sheets.gd: expected 8 arguments, got %d" % a.size())
		quit(1)
		return
	var dir := a[0]
	var out := a[1]
	var sizes := a[2].split(",")
	var cols := maxi(1, int(a[3]))
	var prefixes := a[4].split(",")
	var screen := Color(a[5])
	var card := Color(a[6])
	var files: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".svg") and _has_prefix(f, prefixes):
			files.append(f)
	files.sort()
	var rows: Array[Array] = []
	var cell_w := 0
	var cell_h := 0
	for f in files:
		var row: Array[Image] = []
		var w := GAP
		var h := 0
		for spec in sizes:
			var img := _load(dir.path_join(f), spec)
			row.append(img)
			w += img.get_width() + GAP
			h = maxi(h, img.get_height())
		rows.append(row)
		cell_w = maxi(cell_w, w)
		cell_h = maxi(cell_h, h + GAP * 2)
	var n_rows := maxi(1, ceili(files.size() / float(cols)))
	var sheet := Image.create(cols * cell_w + GAP, n_rows * cell_h + GAP, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(a[7]))
	for i in files.size():
		var x := GAP + (i % cols) * cell_w
		var y := GAP + floori(i / float(cols)) * cell_h
		var row: Array = rows[i]
		for j in row.size():
			var img: Image = row[j]
			sheet.fill_rect(Rect2i(x, y, img.get_width() + GAP, cell_h - GAP), screen if j % 2 == 0 else card)
			var top := y + floori((cell_h - GAP - img.get_height()) / 2.0)
			sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(x + floori(GAP / 2.0), top))
			x += img.get_width() + GAP
	sheet.save_png(out)
	print(out.get_file(), ": ", ", ".join(PackedStringArray(files)).replace(".svg", ""))
	quit()


func _has_prefix(file: String, prefixes: PackedStringArray) -> bool:
	for p in prefixes:
		if file.begins_with(p):
			return true
	return false


## The SVG at a width in px ("64") or a scale factor ("x2").
func _load(path: String, spec: String) -> Image:
	var txt := FileAccess.get_file_as_string(path)
	var w := 64.0
	var re := RegEx.create_from_string("width=\"([0-9.]+)\"")
	var m := re.search(txt)
	if m:
		w = float(m.get_string(1))
	var factor := float(spec.substr(1)) if spec.begins_with("x") else float(spec) / w
	var img := Image.new()
	if img.load_svg_from_string(txt, factor) != OK:
		push_error("svg failed " + path)
		img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(Color.MAGENTA)
	img.convert(Image.FORMAT_RGBA8)
	return img
