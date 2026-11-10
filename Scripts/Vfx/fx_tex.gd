class_name FxTex
extends RefCounted

## The hand-drawn SVG effect sprites (Assets/Vfx/svg): CompressedTexture2D
## with mipmaps (in-world art, like the rig sheets), drawn
## LINEAR_WITH_MIPMAPS. They are white with a grey shade and an ink outline in
## the palette's ink, so a draw's modulate colour tints them. AXE (Gorrak's
## spinning Tusk Axe) is drawn in its own colours (ivory blade, wood haft, the
## monster3 grip), untinted. The per-ability sprites join these in Phase 7
## (AbilityFxRecipe).

const STAR := preload("res://Assets/Vfx/svg/fx_star.svg")
const SPARK := preload("res://Assets/Vfx/svg/fx_spark.svg")
const PUFF := preload("res://Assets/Vfx/svg/fx_puff.svg")
const AXE := preload("res://Assets/Vfx/svg/fx_axe.svg")
## Damage-number glyphs: DIGIT_ORDER.length() equal cells side by side
## (28x40 art units each; the import's svg/scale sets the texture size).
const DIGITS := preload("res://Assets/Vfx/svg/fx_digits.svg")
const DIGIT_ORDER := "0123456789+-"


## One glyph cell of DIGITS in texture pixels.
static func digit_cell() -> Vector2:
	var size: Vector2 = DIGITS.get_size()
	return Vector2(size.x / float(DIGIT_ORDER.length()), size.y)
