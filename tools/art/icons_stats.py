"""Stat glyphs (no tile, transparent): colour-coded, used inline next to
numbers (24-32 px), in skill-tree node frames (40-56 px) and tooltips."""
from palette import PAL as P
from svgkit import icon, circle, ellipse, rrect, poly, star, burst, heart, drop, leaf, leaf_vein, arc, INK

ICONS = {}
W = "#FFFFFF"
IVORY, IVORY_S = "#EFE3C8", "#BFA987"
STEEL, STEEL_S = P["steel_light"], P["steel"]

d = icon()
d.cel(heart(32, 34, 27), P["danger"], P["danger_dark"], off=(-3.5, -4))
d.fleck(ellipse(19, 23, 5, 3.2, -35), W, 0.8)
ICONS["stat_hp"] = d.svg()

d = icon()
tf = "rotate(45 32 32)"
d.cel("M27 42 L27 10 L32 2 L37 10 L37 42Z", STEEL, STEEL_S, tf=tf)
d.ink("M32 8 V40", 2, tf=tf, color=STEEL_S)
d.cel(rrect(17, 41, 30, 7, 3), P["copper"], P["copper_dark"], tf=tf)
d.cel(rrect(28.5, 47, 7, 11, 2), P["wood"], P["wood_dark"], tf=tf)
d.cel(circle(32, 60, 4), P["copper"], P["copper_dark"], ow=3, tf=tf)
ICONS["stat_damage"] = d.svg()

d = icon()
for s in ("M3 30 H15", "M6 40 H16", "M3 50 H14"):
    d.line(s, P["teal_light"], 3.4, 2.2)
d.cel("M24 6 H42 L42 30 C42 34 46 36 52 37 C59 38 62 43 62 49 L62 54 H22 L24 30Z", P["teal_light"], P["teal"])
d.cel(rrect(21, 51, 42, 8, 3), P["teal_dark"], INK, ow=3)
d.cel(rrect(22.5, 4, 21, 8, 3), P["amber"], P["amber_dark"], ow=3)
ICONS["stat_speed"] = d.svg()

d = icon()
d.line("M12 20 C24 6 42 4 54 10", P["wood_light"], 5, 2.4)
d.line("M12 20 C6 32 8 46 14 56", P["wood_light"], 5, 2.4)
d.ink("M54 10 L14 56", 2.2, color=IVORY)
d.line("M18 48 L50 16", P["wood"], 4, 2.2)
d.cel(poly([(46, 12), (60, 4), (54, 20)]), STEEL, STEEL_S, ow=3)
d.cel(poly([(18, 40), (10, 44), (8, 56), (20, 54), (24, 46)]), P["danger"], P["danger_dark"], ow=3)
ICONS["stat_range"] = d.svg()

d = icon()
d.line(arc(32, 32, 26, 200, 330), P["amber"], 4, 2.2)
d.line(arc(32, 32, 26, 20, 150), P["amber"], 4, 2.2)
for tf in ("rotate(40 32 32)", "rotate(-40 32 32)"):
    d.cel("M29 40 L29 8 L32 3 L35 8 L35 40Z", STEEL, STEEL_S, tf=tf, ow=3)
    d.cel(rrect(22, 39, 20, 5.5, 2.5), P["copper"], P["copper_dark"], tf=tf, ow=3)
    d.cel(rrect(29.5, 44, 5, 12, 2), P["wood"], P["wood_dark"], tf=tf, ow=3)
ICONS["stat_attack_speed"] = d.svg()

d = icon()
d.cel(rrect(12, 4, 40, 8, 3), P["wood_light"], P["wood"])
d.cel(rrect(12, 52, 40, 8, 3), P["wood_light"], P["wood"])
d.cel("M17 12 H47 C47 24 38 28 35 32 C38 36 47 40 47 52 H17 C17 40 26 36 29 32 C26 28 17 24 17 12Z",
      "#DDEFF0", "#A8C4C8", off=(-3, -2))
d.flat("M22 17 H42 C41 22 36 25 32 29 C28 25 23 22 22 17Z", P["amber"], 0)
d.flat("M32 34 L33 44 C38 45 43 47 44 50 H20 C21 47 26 45 31 44Z", P["amber"], 0)
d.ink("M17 12 H47 C47 24 38 28 35 32 C38 36 47 40 47 52 H17 C17 40 26 36 29 32 C26 28 17 24 17 12Z", 3.5)
ICONS["stat_cooldown"] = d.svg()

d = icon()
d.cel("M2 32 C12 14 52 14 62 32 C52 50 12 50 2 32Z", IVORY, IVORY_S, off=(-2, -3))
d.cel(circle(32, 32, 13), P["teal_light"], P["teal"], ow=3)
d.cel(circle(32, 32, 6), INK, INK, ow=0)
d.fleck(circle(28, 28, 2.6), W, 0.95)
ICONS["stat_vision"] = d.svg()

d = icon()
d.cel(poly([(32, 3), (54, 18), (54, 44), (32, 61), (10, 44), (10, 18)]), P["xp"], P["xp_dark"], off=(-3, -3))
d.flat(poly([(32, 11), (46, 21), (32, 31), (18, 21)]), "#A9DCF5", 0)
d.ink("M10 18 L32 31 L54 18 M32 31 V61", 2.4)
d.ink(poly([(32, 3), (54, 18), (54, 44), (32, 61), (10, 44), (10, 18)]), 3.5)
d.cel(star(52, 10, 7.5, 2.8, 4), W, "#CFE8EF", ow=2.4)
ICONS["stat_xp"] = d.svg()

d = icon()
KITE = "M32 61 C18 53 10 42 10 27 L10 13 C19 13 26 10 32 4 C38 10 45 13 54 13 L54 27 C54 42 46 53 32 61Z"
d.cel(KITE, P["copper"], P["copper_dark"], off=(-3, -3))
d.cel("M32 53 C22 47 17 39 17 28 L17 19 C23 19 28 17 32 13 C36 17 41 19 47 19 L47 28 C47 39 42 47 32 53Z",
      STEEL, STEEL_S, ow=3)
d.ink("M32 15 V52", 2.4, color=STEEL_S)
ICONS["stat_armor"] = d.svg()

d = icon()
d.cel("M24 4 H40 V24 H60 V40 H40 V60 H24 V40 H4 V24 H24Z", P["heal"], P["heal_dark"], off=(-3, -3))
d.fleck(rrect(27, 8, 6, 12, 2.5), W, 0.6)
ICONS["stat_heal"] = d.svg()

d = icon()
d.cel(heart(26, 34, 21), P["heal"], P["heal_dark"], off=(-3, -3))
d.cel(leaf(36, 22, 56, 4, 0.36), P["leaf"], P["moss"], ow=3)
d.cel(circle(47, 47, 11), W, "#D9D2C4", ow=3)
d.line("M47 41 V53 M41 47 H53", P["heal"], 3.6, 0)
ICONS["stat_regen"] = d.svg()

d = icon()
d.cel(drop(28, 44, 17), "#C8323A", "#7E1A22", off=(-3, -3))
d.fleck(ellipse(20, 40, 3.4, 5.4), W, 0.6)
d.cel(heart(48, 48, 12), P["heal"], P["heal_dark"], ow=3)
d.line("M44 8 C54 12 58 22 56 30", P["heal"], 3.4, 2.2)
d.cel(poly([(50, 28), (62, 28), (56, 38)]), P["heal"], P["heal_dark"], ow=2.6)
ICONS["stat_lifesteal"] = d.svg()

d = icon()
d.cel(burst(32, 32, 30, 20, 10, -90, (1.0, 0.85)), P["amber"], P["amber_dark"], ow=3)
d.cel(circle(32, 32, 14), P["copper_light"], P["copper"], ow=3)
d.cel(circle(32, 32, 6), P["amber_light"], P["amber"], ow=2.6)
ICONS["stat_aoe"] = d.svg()

d = icon()
d.cel(rrect(27, 2, 10, 7, 2), P["copper"], P["copper_dark"], ow=3)
d.cel(rrect(46, 9, 8, 6, 2), P["copper"], P["copper_dark"], ow=3, tf="rotate(45 50 12)")
d.cel(circle(32, 36, 24), IVORY, IVORY_S, off=(-3, -3))
d.flat("M32 36 L32 16 A20 20 0 0 1 51 41Z", P["teal_light"], 0, op=0.9)
d.ink(circle(32, 36, 24), 3.5)
d.line("M32 36 V19 M32 36 L43 43", INK, 3.2, 0)
d.flat(circle(32, 36, 3.2), INK, 0)
ICONS["stat_duration"] = d.svg()

d = icon()
d.cel("M32 2 L58 14 V38 C58 50 46 58 32 62 C18 58 6 50 6 38 V14Z", P["amber"], P["amber_dark"], off=(-3, -3))
d.cel("M14 36 L32 20 L50 36 L50 46 L32 30 L14 46Z", W, "#E2D8C6", ow=3)
ICONS["stat_level"] = d.svg()

d = icon()
d.cel("M8 52 C10 40 18 30 32 28 C46 30 54 40 56 52 C46 50 40 54 32 60 C24 54 18 50 8 52Z",
      P["monster"], P["monster_dark"])
d.cel("M14 32 C6 26 4 16 8 6 C12 14 18 18 24 22Z", IVORY, IVORY_S, ow=3)
d.cel("M50 32 C58 26 60 16 56 6 C52 14 46 18 40 22Z", IVORY, IVORY_S, ow=3)
d.flat("M20 40 L29 44 L27 47 L20 44Z", P["amber_light"], 2.6)
d.flat("M44 40 L35 44 L37 47 L44 44Z", P["amber_light"], 2.6)
ICONS["stat_threat"] = d.svg()
