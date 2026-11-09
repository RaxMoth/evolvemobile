"""Small UI glyphs. WHITE fill + ink outline (tint with modulate / the
Button icon colours). 64x64, transparent; shown at 24-40 px."""
from svgkit import icon, circle, rrect, poly, star, gear, arc, INK

ICONS = {}
W = "#FFFFFF"
S = "#CFC8BC"


def doc():
    return icon()


d = doc()
d.cel("M6 32 L30 8 L30 22 H56 C58 22 59 23 59 25 V39 C59 41 58 42 56 42 H30 V56Z", W, S, off=(-2.5, -3))
ICONS["ui_back"] = d.svg()

d = doc()
d.cel("M14 6 L32 24 L50 6 L58 14 L40 32 L58 50 L50 58 L32 40 L14 58 L6 50 L24 32 L6 14Z", W, S, off=(-2.5, -3))
ICONS["ui_close"] = d.svg()

d = doc()
d.cel("M16 6 C16 3 19 2 21 3 L57 27 C60 29 60 35 57 37 L21 61 C19 62 16 61 16 58Z", W, S, off=(-3, -3))
ICONS["ui_play"] = d.svg()

d = doc()
d.cel(rrect(12, 6, 15, 52, 4), W, S)
d.cel(rrect(37, 6, 15, 52, 4), W, S)
ICONS["ui_pause"] = d.svg()

d = doc()
d.cel("M4 12 L32 32 L4 52Z", W, S)
d.cel("M30 12 L58 32 L30 52Z", W, S)
ICONS["ui_fast_forward"] = d.svg()

d = doc()
d.cel(circle(32, 32, 27), W, S, off=(-3, -3))
d.flat(circle(32, 18, 4.5), INK, 0)
d.flat(rrect(27.5, 26, 9, 24, 3), INK, 0)
ICONS["ui_info"] = d.svg()

d = doc()
d.cel("M24 5 H40 V24 H59 V40 H40 V59 H24 V40 H5 V24 H24Z", W, S, off=(-3, -3))
ICONS["ui_plus"] = d.svg()

d = doc()
d.cel("M4 34 L14 24 L26 36 L50 8 L60 18 L26 56Z", W, S, off=(-3, -3))
ICONS["ui_check"] = d.svg()

d = doc()
d.cel("M6 22 L20 8 V16 H50 V28 H20 V36Z", W, S)
d.cel("M58 42 L44 28 V36 H14 V48 H44 V56Z", W, S)
ICONS["ui_swap"] = d.svg()

d = doc()
d.cel(circle(32, 32, 22), W, S)
d.ink(circle(32, 32, 11), 3.5)
d.line("M32 2 V14 M32 50 V62 M2 32 H14 M50 32 H62", W, 4.5, 2.2)
d.flat(circle(32, 32, 5), INK, 0)
ICONS["ui_follow"] = d.svg()

d = doc()
d.line("M20 30 V20 C20 8 44 8 44 20 V30", W, 6, 2.5)
d.cel(rrect(10, 28, 44, 32, 6), W, S, off=(-3, -3))
d.flat(circle(32, 41, 5), INK, 0)
d.flat(rrect(29.5, 42, 5, 10, 2), INK, 0)
ICONS["ui_lock"] = d.svg()

d = doc()
d.cel(star(32, 34, 30, 13, 5), W, S, off=(-3, -3))
ICONS["ui_star"] = d.svg()

d = doc()
d.cel(gear(32, 32, 28, 21, 8), W, S, off=(-3, -3))
d.flat(circle(32, 32, 9), INK, 0)
ICONS["ui_settings"] = d.svg()

d = doc()
d.cel("M20 6 L46 32 L20 58 L12 50 L30 32 L12 14Z", W, S, off=(-2.5, -3))
ICONS["ui_chevron_right"] = d.svg()

d = doc()
d.cel("M44 6 L18 32 L44 58 L52 50 L34 32 L52 14Z", W, S, off=(-2.5, -3))
ICONS["ui_chevron_left"] = d.svg()

d = doc()
d.cel("M32 4 L58 30 H46 V58 H18 V30 H6Z", W, S, off=(-3, -3))
ICONS["ui_level_up"] = d.svg()
