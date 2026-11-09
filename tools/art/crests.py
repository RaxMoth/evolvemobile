"""Side crests for the side picker / headers / match result. 128x144.
Heroes read warm (copper rim, moss field, amber), the monster reads
dangerous (crimson rim, purple field, ivory skull)."""
from palette import PAL as P, mix
from svgkit import Doc, circle, ellipse, rrect, poly, star, leaf, leaf_vein, INK

ICONS = {}
W = "#FFFFFF"
IVORY, IVORY_S = "#EFE3C8", "#BFA987"
STEEL, STEEL_S = P["steel_light"], P["steel"]

# ------------------------------------------------------------- HEROES
d = Doc(128, 144)
# laurel of jungle leaves behind the shield
for i, (x0, y0, x1, y1) in enumerate(((30, 128, 6, 100), (22, 110, 2, 76), (18, 88, 6, 52),
                                      (98, 128, 122, 100), (106, 110, 126, 76), (110, 88, 122, 52))):
    d.cel(leaf(x0, y0, x1, y1, 0.36), P["moss_light"] if i % 2 else P["leaf"], P["moss"], ow=3)
SHIELD = "M64 140 C34 126 16 104 16 72 V24 C34 24 50 18 64 8 C78 18 94 24 112 24 V72 C112 104 94 126 64 140Z"
FIELD = "M64 128 C40 116 26 98 26 72 V32 C40 31 53 26 64 18 C75 26 88 31 102 32 V72 C102 98 88 116 64 128Z"
d.cel(SHIELD, P["copper"], P["copper_dark"], off=(-4, -4), ow=4.5)
d.cel(FIELD, P["moss"], P["moss_dark"], off=(-4, -4), ow=3.5)
d.flat("M64 18 C75 26 88 31 102 32 V72 C102 76 101 80 100 84 L64 48Z", P["hero_moss"], 0, op=0.55)
# sword
tf = ""
d.cel("M58 96 V40 L64 28 L70 40 V96Z", STEEL, STEEL_S, ow=3.5)
d.ink("M64 36 V92", 2.4, color=STEEL_S)
d.cel(rrect(44, 92, 40, 9, 4), P["amber"], P["amber_dark"], ow=3.5)
d.cel(rrect(59.5, 100, 9, 16, 3), P["wood"], P["wood_dark"], ow=3.2)
d.cel(circle(64, 120, 5.5), P["amber"], P["amber_dark"], ow=3)
# leaf crossing the blade
d.cel(leaf(40, 84, 90, 52, 0.3, 0.1), P["leaf"], P["moss"], ow=3)
d.ink(leaf_vein(40, 84, 90, 52), 2, color=P["moss"])
# star above
d.cel(star(64, 14, 13, 5.5, 5), P["amber_light"], P["amber"], ow=3.2)
ICONS["crest_heroes"] = d.svg()

# ------------------------------------------------------------- MONSTER
d = Doc(128, 144)
# thorns radiating behind
for (x0, y0, x1, y1) in ((24, 40, 2, 22), (104, 40, 126, 22), (18, 84, 0, 88), (110, 84, 128, 88),
                         (34, 120, 18, 136), (94, 120, 110, 136)):
    import math
    dx, dy = x1 - x0, y1 - y0
    L = math.hypot(dx, dy)
    nx, ny = -dy / L * 6, dx / L * 6
    d.cel(poly([(x0 + nx, y0 + ny), (x1, y1), (x0 - nx, y0 - ny)]), P["monster_dark"], INK, ow=3)
SHIELD = "M64 142 L40 124 C24 110 16 92 16 70 L16 20 L40 30 L64 10 L88 30 L112 20 L112 70 C112 92 104 110 88 124Z"
FIELD = "M64 128 L46 114 C32 102 26 88 26 70 V34 L42 40 L64 22 L86 40 L102 34 V70 C102 88 96 102 82 114Z"
d.cel(SHIELD, P["monster"], P["monster_dark"], off=(-4, -4), ow=4.5)
d.cel(FIELD, P["monster_purple"], P["monster_purple_dark"], off=(-4, -4), ow=3.5)
# claw marks across the field
for k in (-12, 0, 12):
    d.flat(f"M{78 + k} 40 C{72 + k} 64 {62 + k} 86 {46 + k} 110 C{58 + k} 90 {70 + k} 68 {82 + k} 44Z",
           P["monster_purple_dark"], 0, op=0.8)
# bull skull
d.cel("M40 58 C28 54 22 44 24 30 C30 40 38 44 48 46Z", IVORY, IVORY_S, ow=3.2)
d.cel("M88 58 C100 54 106 44 104 30 C98 40 90 44 80 46Z", IVORY, IVORY_S, ow=3.2)
d.cel("M64 44 C78 44 86 54 86 66 C86 74 82 78 80 84 L78 96 C72 104 56 104 50 96 L48 84 C46 78 42 74 42 66 C42 54 50 44 64 44Z",
      IVORY, IVORY_S, off=(-3, -3))
d.cel("M48 63 L60 68 L57 75 L48 71Z", P["monster"], P["monster_dark"], ow=2.8)
d.cel("M80 63 L68 68 L71 75 L80 71Z", P["monster"], P["monster_dark"], ow=2.8)
d.flat("M60 84 L64 79 L68 84Z", INK, 0)
d.ink("M56 92 L58 98 M64 92 V99 M72 92 L70 98", 2.6)
d.ink("M64 46 L62 54 L66 58", 2.4, color=IVORY_S)
# crimson gem at the top
d.cel(poly([(64, 4), (72, 14), (64, 24), (56, 14)]), P["monster_light"], P["monster"], ow=3)
ICONS["crest_monster"] = d.svg()
