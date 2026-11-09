"""Currencies + the generic upgrade token. 64x64, transparent."""
from palette import PAL as P
from svgkit import icon, circle, ellipse, rrect, poly, star, leaf, leaf_vein, INK

ICONS = {}
W = "#FFFFFF"

# Gold: thick coin, embossed leaf, rim. Slightly tilted ellipse = chunky coin.
d = icon()
d.cel(ellipse(33, 36, 26, 24), P["gold_dark"], INK, ow=3.5)
d.cel(ellipse(30, 32, 26, 24), P["gold"], P["gold_dark"], off=(-2.5, -2.5))
d.ink(ellipse(30, 32, 19, 17.5), 2.6, color=P["gold_dark"])
d.cel(leaf(22, 42, 40, 20, 0.38), P["gold_light"], P["gold_dark"], ow=2.8)
d.ink(leaf_vein(22, 42, 40, 20), 2.2, color=P["gold_dark"])
d.fleck(ellipse(17, 20, 4, 2.4, -40), W, 0.85)
ICONS["currency_gold"] = d.svg()

# Steel: forged ingot, two-tone top/front, hammer notch.
d = icon()
d.cel(poly([(4, 40), (14, 26), (54, 26), (60, 40), (60, 50), (4, 50)]), P["steel"], P["steel_dark"], off=(-2, -2))
d.flat(poly([(4, 40), (14, 26), (54, 26), (60, 40)]), P["steel_light"], 3)
d.ink("M4 40 H60", 3)
d.cel(poly([(14, 22), (20, 12), (48, 12), (52, 22), (52, 28), (14, 28)]), P["steel"], P["steel_dark"], off=(-2, -2), ow=3.2)
d.flat(poly([(14, 22), (20, 12), (48, 12), (52, 22)]), P["steel_light"], 3.2)
d.fleck("M22 15 L28 15 L25 19 L19 19Z", W, 0.9)
d.fleck("M16 31 L24 31 L20 37 L12 37Z", W, 0.8)
ICONS["currency_steel"] = d.svg()

# Leaves: three jungle leaves fanned from one stem.
d = icon()
d.line("M30 62 C30 54 31 46 32 40", P["leaves_dark"], 3.2, 2.2)
d.cel(leaf(31, 42, 8, 12, 0.36, 0.1), P["leaves"], P["leaves_dark"])
d.ink(leaf_vein(31, 42, 8, 12), 2.2, color=P["leaves_dark"])
d.cel(leaf(33, 42, 58, 16, 0.36, -0.1), P["leaves"], P["leaves_dark"])
d.ink(leaf_vein(33, 42, 58, 16), 2.2, color=P["leaves_dark"])
d.cel(leaf(32, 44, 34, 2, 0.34), P["leaves_light"], P["leaves"])
d.ink(leaf_vein(32, 44, 34, 2), 2.2, color=P["leaves"])
ICONS["currency_leaves"] = d.svg()

# Upgrade point (skill-tree point / "1/1" shard): amber star seal.
d = icon()
d.cel(circle(32, 32, 27), P["copper"], P["copper_dark"])
d.cel(star(32, 33, 20, 9, 5), P["amber_light"], P["amber"], ow=3)
d.fleck(circle(25, 24, 2.4), W, 0.9)
ICONS["currency_upgrade_point"] = d.svg()
