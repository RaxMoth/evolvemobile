"""Hand-authored SVG helpers in the Jungle Guild style.

Style rules encoded here (see spec):
  * flat fills, ONE shade tone per shape (cel offset crescent, lower-right),
    no gradients anywhere;
  * every shape carries a heavy ink outline (#1A1311), round joins/caps;
  * optional tiny highlight fleck, used sparingly.
Everything is plain SVG that ThorVG (Godot's rasteriser) renders: paths,
basic shapes, <use>, <clipPath>, transforms, opacity. No text, filters, masks.
"""
import math
from palette import PAL as P, mix

INK = P["ink"]
OW = 3.5          # default outline width at 64 px (=2.2 px at 40 px)


class Doc:
    """Collects defs (clip paths) with unique ids plus the body."""

    def __init__(self, w=64, h=None, vb=None):
        self.w = w
        self.h = h or w
        self.vb = vb or f"0 0 {self.w} {self.h}"
        self.defs = []
        self.body = []
        self._n = 0

    def uid(self, p="c"):
        self._n += 1
        return f"{p}{self._n}"

    def add(self, s):
        self.body.append(s)
        return self

    # ---- primitives --------------------------------------------------------
    def cel(self, d, base, shade=None, off=(-2.2, -2.8), ow=OW, tf="", hl=None, line=INK, op=1.0):
        """Shape with a flat base, a shade crescent on the lower-right and an
        ink outline. `d` is path data. `tf` an optional transform."""
        shade = shade or mix(base, INK, 0.38)
        cid = self.uid()
        t = f' transform="{tf}"' if tf else ""
        o = f' opacity="{op}"' if op != 1.0 else ""
        self.defs.append(f'<clipPath id="{cid}"><path d="{d}"/></clipPath>')
        s = (f'<g{t}{o}><path d="{d}" fill="{shade}"/>'
             f'<g clip-path="url(#{cid})"><path d="{d}" fill="{base}" transform="translate({off[0]} {off[1]})"/></g>')
        if hl:
            s += hl
        if ow > 0:
            s += f'<path d="{d}" fill="none" stroke="{line}" stroke-width="{ow}" stroke-linejoin="round" stroke-linecap="round"/>'
        s += "</g>"
        return self.add(s)

    def flat(self, d, fill, ow=OW, tf="", op=1.0, line=INK):
        t = f' transform="{tf}"' if tf else ""
        o = f' opacity="{op}"' if op != 1.0 else ""
        st = (f' stroke="{line}" stroke-width="{ow}" stroke-linejoin="round" stroke-linecap="round"'
              if ow > 0 else "")
        return self.add(f'<path d="{d}" fill="{fill}"{st}{t}{o}/>')

    def line(self, d, color, w=3.0, ow=None, tf="", op=1.0, cap="round"):
        """Coloured stroke with an ink casing (ink drawn wider underneath)."""
        ow = OW if ow is None else ow
        t = f' transform="{tf}"' if tf else ""
        o = f' opacity="{op}"' if op != 1.0 else ""
        s = ""
        if ow > 0:
            s += (f'<path d="{d}" fill="none" stroke="{INK}" stroke-width="{w + ow * 2 - 1:.2f}" '
                  f'stroke-linecap="{cap}" stroke-linejoin="round"{t}{o}/>')
        s += (f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{w}" '
              f'stroke-linecap="{cap}" stroke-linejoin="round"{t}{o}/>')
        return self.add(s)

    def ink(self, d, w=OW, tf="", color=INK, op=1.0):
        t = f' transform="{tf}"' if tf else ""
        o = f' opacity="{op}"' if op != 1.0 else ""
        return self.add(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{w}" '
                        f'stroke-linecap="round" stroke-linejoin="round"{t}{o}/>')

    def fleck(self, d, color="#FFFFFF", op=0.85):
        return self.add(f'<path d="{d}" fill="{color}" opacity="{op}"/>')

    def svg(self):
        d = f"<defs>{''.join(self.defs)}</defs>" if self.defs else ""
        return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}" '
                f'viewBox="{self.vb}">{d}{"".join(self.body)}</svg>\n')


# ---- path builders ---------------------------------------------------------

def f2(v):
    return f"{v:.2f}".rstrip("0").rstrip(".")


def circle(cx, cy, r):
    return (f"M{f2(cx - r)} {f2(cy)} A{f2(r)} {f2(r)} 0 1 0 {f2(cx + r)} {f2(cy)} "
            f"A{f2(r)} {f2(r)} 0 1 0 {f2(cx - r)} {f2(cy)}Z")


def ellipse(cx, cy, rx, ry, rot=0.0):
    pts = []
    n = 32
    a0 = math.radians(rot)
    for i in range(n):
        t = 2 * math.pi * i / n
        x, y = rx * math.cos(t), ry * math.sin(t)
        pts.append((cx + x * math.cos(a0) - y * math.sin(a0), cy + x * math.sin(a0) + y * math.cos(a0)))
    return smooth(pts)


def rrect(x, y, w, h, r):
    r = min(r, w / 2, h / 2)
    return (f"M{f2(x + r)} {f2(y)} H{f2(x + w - r)} A{f2(r)} {f2(r)} 0 0 1 {f2(x + w)} {f2(y + r)} "
            f"V{f2(y + h - r)} A{f2(r)} {f2(r)} 0 0 1 {f2(x + w - r)} {f2(y + h)} H{f2(x + r)} "
            f"A{f2(r)} {f2(r)} 0 0 1 {f2(x)} {f2(y + h - r)} V{f2(y + r)} A{f2(r)} {f2(r)} 0 0 1 {f2(x + r)} {f2(y)}Z")


def poly(pts, close=True):
    s = "M" + " L".join(f"{f2(x)} {f2(y)}" for x, y in pts)
    return s + ("Z" if close else "")


def smooth(pts, close=True, k=0.5):
    """Catmull-Rom through points -> cubic beziers (closed blob by default)."""
    n = len(pts)
    if n < 3:
        return poly(pts, close)
    s = f"M{f2(pts[0][0])} {f2(pts[0][1])}"
    rng = range(n) if close else range(n - 1)
    for i in rng:
        p0 = pts[(i - 1) % n] if (close or i > 0) else pts[i]
        p1 = pts[i]
        p2 = pts[(i + 1) % n]
        p3 = pts[(i + 2) % n] if (close or i + 2 < n) else p2
        c1 = (p1[0] + (p2[0] - p0[0]) * k / 3, p1[1] + (p2[1] - p0[1]) * k / 3)
        c2 = (p2[0] - (p3[0] - p1[0]) * k / 3, p2[1] - (p3[1] - p1[1]) * k / 3)
        s += f" C{f2(c1[0])} {f2(c1[1])} {f2(c2[0])} {f2(c2[1])} {f2(p2[0])} {f2(p2[1])}"
    return s + ("Z" if close else "")


def star(cx, cy, ro, ri, n, rot=-90.0):
    pts = []
    for i in range(n * 2):
        r = ro if i % 2 == 0 else ri
        a = math.radians(rot + i * 180.0 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return poly(pts)


def burst(cx, cy, ro, ri, n, rot=-90.0, jitter=(1.0, 0.8, 1.1, 0.9)):
    """Irregular comic burst."""
    pts = []
    for i in range(n * 2):
        r = ro * jitter[(i // 2) % len(jitter)] if i % 2 == 0 else ri
        a = math.radians(rot + i * 180.0 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return poly(pts)


def heart(cx, cy, s):
    def p(x, y):
        return f"{f2(cx + x * s)} {f2(cy + y * s)}"
    return (f"M{p(0, 0.95)} C{p(-0.55, 0.55)} {p(-1, 0.2)} {p(-1, -0.3)} "
            f"C{p(-1, -0.75)} {p(-0.65, -0.98)} {p(-0.4, -0.98)} "
            f"C{p(-0.18, -0.98)} {p(-0.04, -0.85)} {p(0, -0.62)} "
            f"C{p(0.04, -0.85)} {p(0.18, -0.98)} {p(0.4, -0.98)} "
            f"C{p(0.65, -0.98)} {p(1, -0.75)} {p(1, -0.3)} "
            f"C{p(1, 0.2)} {p(0.55, 0.55)} {p(0, 0.95)}Z")


def drop(cx, cy, r):
    """Tear drop, tip up; (cx, cy) = centre of the round bottom."""
    return (f"M{f2(cx)} {f2(cy - 2.1 * r)} C{f2(cx + 0.35 * r)} {f2(cy - 1.3 * r)} {f2(cx + r)} {f2(cy - 0.7 * r)} "
            f"{f2(cx + r)} {f2(cy)} A{f2(r)} {f2(r)} 0 0 1 {f2(cx - r)} {f2(cy)} "
            f"C{f2(cx - r)} {f2(cy - 0.7 * r)} {f2(cx - 0.35 * r)} {f2(cy - 1.3 * r)} {f2(cx)} {f2(cy - 2.1 * r)}Z")


def leaf(x0, y0, x1, y1, wid=0.42, bend=0.0):
    """Pointed jungle leaf from (x0,y0) stem to (x1,y1) tip. wid = half width
    relative to length, bend skews the belly (-1..1)."""
    dx, dy = x1 - x0, y1 - y0
    L = math.hypot(dx, dy)
    nx, ny = -dy / L, dx / L
    w = L * wid
    a = (x0 + dx * 0.3 + nx * w * (1 + bend), y0 + dy * 0.3 + ny * w * (1 + bend))
    b = (x0 + dx * 0.75 + nx * w * 0.8, y0 + dy * 0.75 + ny * w * 0.8)
    c = (x0 + dx * 0.75 - nx * w * 0.8, y0 + dy * 0.75 - ny * w * 0.8)
    d = (x0 + dx * 0.3 - nx * w * (1 - bend), y0 + dy * 0.3 - ny * w * (1 - bend))
    return (f"M{f2(x0)} {f2(y0)} C{f2(a[0])} {f2(a[1])} {f2(b[0])} {f2(b[1])} {f2(x1)} {f2(y1)} "
            f"C{f2(c[0])} {f2(c[1])} {f2(d[0])} {f2(d[1])} {f2(x0)} {f2(y0)}Z")


def leaf_vein(x0, y0, x1, y1):
    return f"M{f2(x0 + (x1 - x0) * 0.12)} {f2(y0 + (y1 - y0) * 0.12)} L{f2(x0 + (x1 - x0) * 0.78)} {f2(y0 + (y1 - y0) * 0.78)}"


def gear(cx, cy, ro, ri, teeth):
    pts = []
    n = teeth * 4
    for i in range(n):
        a = math.radians(i * 360.0 / n - 90 + 360.0 / n / 2)
        r = ro if (i % 4) in (1, 2) else ri
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return poly(pts)


def arc(cx, cy, r, a0, a1):
    """Open arc path, degrees, clockwise from a0 to a1 (0 = right, 90 = down)."""
    x0, y0 = cx + r * math.cos(math.radians(a0)), cy + r * math.sin(math.radians(a0))
    x1, y1 = cx + r * math.cos(math.radians(a1)), cy + r * math.sin(math.radians(a1))
    large = 1 if (a1 - a0) % 360 > 180 else 0
    return f"M{f2(x0)} {f2(y0)} A{f2(r)} {f2(r)} 0 {large} 1 {f2(x1)} {f2(y1)}"


# ---- ability tile ------------------------------------------------------------

TILE = {
    # owner: (tile base, tile leaf tone)
    "irelia": ("#2A4D53", "#33606A"),
    "vlad": ("#56231F", "#6A2C27"),
    "ted": ("#5E4620", "#735727"),
    "river": ("#2D4A2A", "#385C34"),
    "grount": ("#4A1E26", "#5E2630"),
    "monster2": ("#36204A", "#452A5E"),
    "monster3": ("#3E4220", "#4D5228"),
    "neutral": ("#3A3633", "#45413D"),
}


def tile(doc, owner):
    """Full-bleed 64x64 tile: flat owner tone, two big faint jungle leaves,
    a darker lower band. The copper slot frame is drawn by the UI on top,
    so the tile has no outline of its own (rx 9 to sit inside the frame)."""
    base, lt = TILE[owner]
    cid = doc.uid("t")
    doc.defs.append(f'<clipPath id="{cid}"><path d="{rrect(0, 0, 64, 64, 9)}"/></clipPath>')
    doc.add(f'<g clip-path="url(#{cid})">'
            f'<rect width="64" height="64" fill="{base}"/>'
            f'<path d="{leaf(-6, 70, 20, 30, 0.38, 0.2)}" fill="{lt}"/>'
            f'<path d="{leaf(70, 66, 44, 34, 0.36, -0.2)}" fill="{lt}"/>'
            f'<path d="{leaf(66, -4, 48, 14, 0.4)}" fill="{lt}" opacity="0.7"/>'
            f'<path d="M0 50 C16 46 40 54 64 47 V64 H0Z" fill="{mix(base, INK, 0.3)}" opacity="0.8"/>'
            f'</g>')
    return doc


def icon(owner=None, w=64):
    d = Doc(w)
    if owner:
        tile(d, owner)
    return d
