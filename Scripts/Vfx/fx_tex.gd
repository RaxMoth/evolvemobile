class_name FxTex
extends RefCounted

## The hand-drawn SVG effect sprites (Assets/Vfx/svg): CompressedTexture2D
## with mipmaps (in-world art, like the rig sheets), drawn
## LINEAR_WITH_MIPMAPS. The tintable ones are white with a grey shade and an
## ink outline in the palette's ink, so a draw's modulate colour tints them.
## The others keep their own palette colours and are drawn untinted: AXE
## (Gorrak's spinning Tusk Axe: ivory blade, wood haft, the monster3 grip),
## STAKE (Trap Cage: wood and rope), ROCK (stone), LEAF (moss) and DUST
## (parchment). The Land Mine's pod and lamp and the supply drop's crate and
## chute (fx_mine, fx_lamp, fx_crate, fx_chute) are sprites of Mine.tscn and
## MediKit.tscn, not drawn from here.

const STAR := preload("res://Assets/Vfx/svg/fx_star.svg")
const SPARK := preload("res://Assets/Vfx/svg/fx_spark.svg")
const PUFF := preload("res://Assets/Vfx/svg/fx_puff.svg")
const AXE := preload("res://Assets/Vfx/svg/fx_axe.svg")
## Ability effects (AbilityVfx): tintable.
const SLASH := preload("res://Assets/Vfx/svg/fx_slash.svg")
const CLAW := preload("res://Assets/Vfx/svg/fx_claw.svg")
const BUBBLE := preload("res://Assets/Vfx/svg/fx_bubble.svg")
const DROP := preload("res://Assets/Vfx/svg/fx_drop.svg")
const PLUS := preload("res://Assets/Vfx/svg/fx_plus.svg")
const SPLAT := preload("res://Assets/Vfx/svg/fx_splat.svg")
const BANG := preload("res://Assets/Vfx/svg/fx_bang.svg")
const ANGER := preload("res://Assets/Vfx/svg/fx_anger.svg")
const SHARD := preload("res://Assets/Vfx/svg/fx_shard.svg")
const CRACK := preload("res://Assets/Vfx/svg/fx_crack.svg")
## Nyxa's bats (Night Swarm, Shadow Swoop, Vampiric Rebirth): tintable.
const BAT := preload("res://Assets/Vfx/svg/fx_bat.svg")
## Ability effects (AbilityVfx): in their own colours.
const STAKE := preload("res://Assets/Vfx/svg/fx_stake.svg")
const ROCK := preload("res://Assets/Vfx/svg/fx_rock.svg")
const LEAF := preload("res://Assets/Vfx/svg/fx_leaf.svg")
const DUST := preload("res://Assets/Vfx/svg/fx_dust.svg")
## Damage-number glyphs: DIGIT_ORDER.length() equal cells side by side
## (28x40 art units each; the import's svg/scale sets the texture size).
const DIGITS := preload("res://Assets/Vfx/svg/fx_digits.svg")
const DIGIT_ORDER := "0123456789+-"
## The "+" cell of DIGITS (a heal number's sign).
const DIGIT_PLUS: int = 10


## One glyph cell of DIGITS in texture pixels.
static func digit_cell() -> Vector2:
	var size: Vector2 = DIGITS.get_size()
	return Vector2(size.x / float(DIGIT_ORDER.length()), size.y)
