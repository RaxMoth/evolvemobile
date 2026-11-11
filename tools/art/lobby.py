"""Lobby art the generators own: the cave above the monsters' lair.

lobby_monsters_top.svg (720x420) continues lobby_monsters.svg upward for
screens taller than 16:9 (LobbyScreen's BackdropTop sits on the backdrop's top
edge; on a 16:9 screen the stage clips it away). Its bottom edge is the lair
art's top edge (strip y = lair y + 420), so everything that crosses that edge
repeats the lair art's own geometry and colours:
  * the lair's first row of wall arches (ROW0: the same centres) closes above
    the edge, and the row behind it is filled with the lair's base colour, so
    the gaps between the arches match on both sides;
  * the two thorn vines run on up from the lair art's own curves.
Above the edge the wall recedes in darker rows and the vines hang from the
top, so the strip can be cut at any height (a 19.5:9 screen shows its lower
280 px, a 21:9 one all of it). Flat fills and ink outlines only (svgkit rules).
"""
import random

from palette import mix
from svgkit import INK, f2

ICONS = {}

W, H = 720, 420
# lobby_monsters.svg's own colours (it predates palette.py's tokens).
LAIR_BASE = "#2E2329"      # its background rect: the wall between the arches
LAIR_ARCH = "#3A2C32"      # its row of wall arches
LAIR_DEEP = "#160F13"      # the mouth of the lair
VINE, THORN, EYE = "#3F1E50", "#7B3F95", "#FF5A3A"
# Centres (lair y) of the lair art's arches, left to right from x = -40 in
# steps of 110; each is an ellipse rx 90, ry 150 with a 5 px ink outline.
ROW0 = (136.99461006503782, 137.94423111972708, 135.69733376194318, 103.34202707322734,
        123.68108907542941, 116.94989632939846, 121.20352040472025, 105.21211764989923)
RX, RY, STEP = 90, 150, 110


def _arch(cx, cy, fill):
    """One wall arch (lair coordinates), as the lair art draws it."""
    y = f2(cy + H)
    return (f'<ellipse cx="{f2(cx)}" cy="{y}" rx="{RX}" ry="{RY}" fill="{fill}"/>'
            f'<ellipse cx="{f2(cx)}" cy="{y}" rx="{RX}" ry="{RY}" fill="none" stroke="{INK}" '
            f'stroke-width="5" stroke-linejoin="round" stroke-linecap="round"/>')


def _bezier(p0, p1, p2, p3, t):
    u = 1 - t
    x = u ** 3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t ** 3 * p3[0]
    y = u ** 3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t ** 3 * p3[1]
    dx = 3 * u * u * (p1[0] - p0[0]) + 6 * u * t * (p2[0] - p1[0]) + 3 * t * t * (p3[0] - p2[0])
    dy = 3 * u * u * (p1[1] - p0[1]) + 6 * u * t * (p2[1] - p1[1]) + 3 * t * t * (p3[1] - p2[1])
    return x, y, dx, dy


def _vine(points, tail=""):
    """A thorn vine through cubic segments (lair coordinates: four points per
    segment, each starting where the last ended), then `tail` (path data, the
    lair art's own curve past the edge). A thorn every 40 px of height, on
    alternating sides."""
    out = []
    d = f"M{f2(points[0][0])} {f2(points[0][1] + H)}"
    segs = [points[i:i + 4] for i in range(0, len(points) - 1, 3)]
    for s in segs:
        d += " C" + " ".join(f"{f2(x)} {f2(y + H)}" for x, y in s[1:])
    d += tail
    out.append(f'<path d="{d}" fill="none" stroke="{INK}" stroke-width="12" stroke-linecap="round" stroke-linejoin="round"/>')
    out.append(f'<path d="{d}" fill="none" stroke="{VINE}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>')
    side = 1
    next_y = points[0][1] + 34
    for s in segs:
        for k in range(1, 40):
            x, y, dx, dy = _bezier(s[0], s[1], s[2], s[3], k / 40)
            if y < next_y or y > -18:
                continue
            next_y = y + 40
            n = (dx * dx + dy * dy) ** 0.5
            tx, ty = dx / n, dy / n          # along the vine (downward)
            nx, ny = -ty * side, tx * side   # out of it
            a = (x + nx * 3 - tx * 5, y + ny * 3 - ty * 5)
            b = (x + nx * 17 - tx * 9, y + ny * 17 - ty * 9)
            c = (x + nx * 4 + tx * 5, y + ny * 4 + ty * 5)
            pts = " ".join(f"{f2(px)},{f2(py + H)}" for px, py in (a, b, c))
            out.append(f'<polygon points="{pts}" fill="{THORN}"/>')
            out.append(f'<polygon points="{pts}" fill="none" stroke="{INK}" stroke-width="3" '
                       f'stroke-linejoin="round" stroke-linecap="round"/>')
            side = -side
    return "".join(out)


def _top():
    rng = random.Random(11)
    body = [f'<rect x="0" y="0" width="{W}" height="{H}" fill="{mix(LAIR_BASE, LAIR_DEEP, 0.62)}"/>']
    # The wall recedes upward: rows of arches, the far ones first and darker.
    # Row 1 is the lair's base colour: it is what shows between ROW0's arches
    # on the lair art's side of the edge.
    rows = ((-465, 0, mix(LAIR_BASE, LAIR_DEEP, 0.50)), (-335, 55, mix(LAIR_BASE, LAIR_DEEP, 0.34)),
            (-205, 0, mix(LAIR_BASE, LAIR_DEEP, 0.18)), (-75, 55, LAIR_BASE))
    for cy, shift, fill in rows:
        for i in range(-1, 8):
            body.append(_arch(-40 + shift + STEP * i, cy + rng.uniform(-14, 14), fill))
    for i, cy in enumerate(ROW0):
        body.append(_arch(-40 + STEP * i, cy, LAIR_ARCH))
    # The dark of the cave roof, in soft steps from the top.
    for ry, op in ((400, 0.16), (310, 0.18), (220, 0.2), (130, 0.22)):
        body.append(f'<ellipse cx="{W / 2}" cy="-30" rx="620" ry="{ry}" fill="{LAIR_DEEP}" opacity="{op}"/>')
    # Eyes in the dark (clear of the lobby's plaques, HUNT buttons and VS
    # badge on a 19.5:9 screen, which shows the strip from y 140 down).
    for x, y in ((150, 252), (538, 96), (402, 232)):
        for dx in (-9, 9):
            body.append(f'<ellipse cx="{x + dx}" cy="{y}" rx="5" ry="3" fill="{EYE}"/>')
    # The lair art's two vines run on upward (their last control point lies on
    # the tangent of the lair's own curve at (x, -4)), then follow that curve
    # across the edge; three more hang from the roof.
    body.append(_vine([(34, -430), (72, -352), (-8, -272), (16, -200), (40, -128), (10, -98), (40, -4)],
                      " Q70 510 30 600"))
    body.append(_vine([(668, -430), (630, -360), (690, -290), (654, -214), (618, -138), (610, -98), (640, -4)],
                      " Q670 510 630 600"))
    body.append(_vine([(212, -430), (236, -372), (188, -318), (206, -262)]))
    body.append(_vine([(486, -430), (462, -350), (508, -290), (492, -196)]))
    body.append(_vine([(330, -430), (346, -398), (318, -372), (328, -338)]))
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
            + "".join(body) + "</svg>\n")


ICONS["lobby_monsters_top"] = _top()
