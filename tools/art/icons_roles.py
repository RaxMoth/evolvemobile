"""Role / filter silhouettes. WHITE fill + ink outline so the UI tints them
with modulate: inactive = text_dim, active = amber (like the reference's
filter row). 64x64, transparent."""
from svgkit import icon, circle, ellipse, rrect, poly, star, INK

ICONS = {}
W = "#FFFFFF"
S = "#CFC8BC"     # shade stays light so tinting keeps the shape readable


def doc():
    return icon()


d = doc()
for x, y in ((6, 6), (35, 6), (6, 35), (35, 35)):
    d.cel(rrect(x, y, 23, 23, 5), W, S)
ICONS["role_all"] = d.svg()

d = doc()
d.cel("M32 61 C18 53 9 42 9 27 L9 12 C18 12 26 9 32 3 C38 9 46 12 55 12 L55 27 C55 42 46 53 32 61Z", W, S,
      off=(-3, -3))
d.ink("M32 10 V54 M15 27 H49", 3)
ICONS["role_tank"] = d.svg()

d = doc()
tf = "rotate(45 32 32)"
d.cel("M26 42 L26 9 L32 1 L38 9 L38 42Z", W, S, tf=tf)
d.cel(rrect(15, 41, 34, 8, 3.5), W, S, tf=tf)
d.cel(rrect(28, 48, 8, 11, 2), W, S, tf=tf)
d.cel(circle(32, 61, 4.2), W, S, ow=3, tf=tf)
ICONS["role_melee"] = d.svg()

d = doc()
d.cel(circle(32, 32, 22), W, S)
d.cel(circle(32, 32, 12), INK, INK, ow=0)
d.cel(circle(32, 32, 9), W, S, ow=0)
d.line("M32 2 V18 M32 46 V62 M2 32 H18 M46 32 H62", W, 4.5, 2.2)
d.flat(circle(32, 32, 3.5), INK, 0)
ICONS["role_ranged"] = d.svg()

d = doc()
d.cel("M24 5 H40 V24 H59 V40 H40 V59 H24 V40 H5 V24 H24Z", W, S, off=(-3, -3))
ICONS["role_support"] = d.svg()

d = doc()
d.cel(ellipse(13, 30, 6.5, 8, -28), W, S, ow=3.2)
d.cel(ellipse(24, 16, 7, 9, -10), W, S, ow=3.2)
d.cel(ellipse(40, 16, 7, 9, 10), W, S, ow=3.2)
d.cel(ellipse(51, 30, 6.5, 8, 28), W, S, ow=3.2)
d.cel("M32 31 C43 31 52 40 50 50 C48 58 39 58 32 58 C25 58 16 58 14 50 C12 40 21 31 32 31Z", W, S)
ICONS["role_summoner"] = d.svg()

d = doc()
d.cel("M14 30 C6 24 3 14 6 3 C11 12 17 16 24 20Z", W, S, ow=3.2)
d.cel("M50 30 C58 24 61 14 58 3 C53 12 47 16 40 20Z", W, S, ow=3.2)
d.cel("M32 14 C46 14 52 24 52 34 C52 42 48 46 46 50 L44 58 C40 62 24 62 20 58 L18 50 C16 46 12 42 12 34 C12 24 18 14 32 14Z",
      W, S)
d.flat("M19 32 L29 36 L27 40 L19 37Z", INK, 0)
d.flat("M45 32 L35 36 L37 40 L45 37Z", INK, 0)
d.ink("M26 51 L28 55 M38 51 L36 55", 2.8)
ICONS["role_brute"] = d.svg()

d = doc()
for dx in (-12, 0, 12):
    d.cel(f"M{40 + dx} 3 C{36 + dx} 22 {28 + dx} 40 {16 + dx} 60 C{32 + dx} 46 {44 + dx} 26 {47 + dx} 6Z", W, S, ow=3.2)
ICONS["role_stalker"] = d.svg()

d = doc()
d.cel(ellipse(18, 22, 10, 6, -30), W, S, ow=3)
d.cel(ellipse(46, 22, 10, 6, 30), W, S, ow=3)
d.cel(ellipse(32, 38, 10, 17), W, S)
d.ink("M23 34 H41 M24 42 H40 M26 50 H38", 3)
d.cel(circle(32, 18, 7.5), W, S, ow=3.2)
d.ink("M28 12 C26 6 22 4 18 4 M36 12 C38 6 42 4 46 4", 3)
ICONS["role_swarm"] = d.svg()
