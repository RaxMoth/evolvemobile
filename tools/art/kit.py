"""UI kit frames (StyleBoxTexture 9-patch sources), ornaments and overlays.
Every frame lists its 9-patch margins in MARGINS (texture px at 1x); the
theme generator reads them from here so art and theme never drift."""
from palette import PAL as P, mix
from svgkit import Doc, circle, ellipse, rrect, poly, smooth, star, leaf, leaf_vein, arc, INK

ICONS = {}
MARGINS = {}
W = "#FFFFFF"


def frame_ring(d, x, y, w, h, r, col, bw=3.5, outer=4.0, inner=1.6, fill=None, fill_col=None):
    """Copper-style border: outer ink, coloured band, thin inner ink."""
    if fill_col:
        d.flat(rrect(x, y, w, h, r), fill_col, 0)
    d.add(f'<path d="{rrect(x, y, w, h, r)}" fill="none" stroke="{INK}" stroke-width="{outer + bw * 2}"/>')
    d.add(f'<path d="{rrect(x, y, w, h, r)}" fill="none" stroke="{col}" stroke-width="{bw * 2 - 1}" '
          f'stroke-linejoin="round"/>')
    # bottom-right shade on the band (one shade tone)
    d.add(f'<path d="M{x + w} {y + r} V{y + h - r} A{r} {r} 0 0 1 {x + w - r} {y + h} H{x + r}" fill="none" '
          f'stroke="{mix(col, INK, 0.35)}" stroke-width="{bw - 0.5}" stroke-linecap="round" '
          f'transform="translate({bw * 0.35} {bw * 0.35})"/>')
    d.add(f'<path d="{rrect(x + bw, y + bw, w - bw * 2, h - bw * 2, max(r - bw, 1))}" fill="none" '
          f'stroke="{INK}" stroke-width="{inner}" opacity="0.8"/>')


def frame_doc(w, h, col, fill, r=8, bw=3.0, pad=4.0):
    d = Doc(w, h)
    d.flat(rrect(pad, pad, w - pad * 2, h - pad * 2, r), fill, 0)
    frame_ring(d, pad, pad, w - pad * 2, h - pad * 2, r, col, bw)
    return d


def sprig(d, x, y, flip=1, scale=1.0, col=None, shade=None):
    """Three-leaf sprig growing from (x, y), mirrored with flip=-1."""
    col = col or P["leaf"]
    shade = shade or P["moss"]
    s = scale
    d.cel(leaf(x, y, x + flip * 18 * s, y - 10 * s, 0.4), col, shade, ow=2.6)
    d.cel(leaf(x, y, x + flip * 6 * s, y - 18 * s, 0.4), mix(col, W, 0.15), shade, ow=2.6)
    d.cel(leaf(x, y, x + flip * 20 * s, y + 4 * s, 0.38), mix(col, INK, 0.1), shade, ow=2.6)


# =========================================================== CHARACTER CARDS
# 96x150 at 1x, used at any size via 9-patch (margins 14).
def card(name, col, fill, extra=None):
    d = frame_doc(96, 150, col, fill, r=8, bw=3.0, pad=4)
    if extra:
        extra(d)
    ICONS[name] = d.svg()
    MARGINS[name] = (14, 14, 14, 14)


card("card_frame", P["copper"], P["card_fill"])
card("card_frame_locked", P["copper_dark"], mix(P["card_fill"], INK, 0.25))


def _monster_spikes(d):
    for x, y, fl in ((4, 4, 1), (92, 4, -1)):
        d.cel(poly([(x + fl * 2, y + 10), (x - fl * 3, y - 3), (x + fl * 10, y + 2)]), P["monster"], P["monster_dark"], ow=2.4)


card("card_frame_monster", mix(P["monster"], P["copper"], 0.25), P["card_fill"], _monster_spikes)


def _selected(d):
    d.add(f'<path d="{rrect(1.5, 1.5, 93, 147, 10)}" fill="none" stroke="{P["amber_light"]}" stroke-width="2" opacity="0.9"/>')
    sprig(d, 10, 12, 1, 0.75)
    sprig(d, 86, 12, -1, 0.75)


card("card_frame_selected", P["amber"], P["card_fill"], _selected)


def inner(name, fill, lt, ground):
    """Inner panel behind the character: darker flat fill, faint jungle
    leaves in the bottom corners, a lighter ground band. 80x100, margins
    L/R 18, T 8, B 34."""
    d = Doc(80, 100)
    cid = d.uid("i")
    shape = rrect(1, 1, 78, 98, 5)
    d.defs.append(f'<clipPath id="{cid}"><path d="{shape}"/></clipPath>')
    d.add(f'<g clip-path="url(#{cid})"><rect width="80" height="100" fill="{fill}"/>'
          f'<path d="M0 84 C20 78 60 78 80 84 V100 H0Z" fill="{ground}"/>'
          f'<path d="{leaf(-4, 104, 14, 66, 0.36, 0.3)}" fill="{lt}"/>'
          f'<path d="{leaf(2, 104, 26, 80, 0.36)}" fill="{lt}"/>'
          f'<path d="{leaf(84, 104, 66, 64, 0.34, -0.3)}" fill="{lt}"/>'
          f'<path d="{leaf(78, 104, 54, 84, 0.36)}" fill="{lt}"/>'
          f'<path d="M0 0 H80 V5 H0Z" fill="{INK}" opacity="0.35"/></g>')
    d.add(f'<path d="{shape}" fill="none" stroke="{INK}" stroke-width="2"/>')
    ICONS[name] = d.svg()
    MARGINS[name] = (18, 8, 18, 34)


inner("card_inner", P["card_inner"], mix(P["card_inner"], W, 0.035), mix(P["card_inner"], W, 0.05))
inner("card_inner_hero", P["card_inner_hero"], mix(P["card_inner_hero"], P["moss"], 0.22), mix(P["card_inner_hero"], P["moss"], 0.14))
inner("card_inner_monster", P["card_inner_monster"], mix(P["card_inner_monster"], P["monster_purple"], 0.25),
      mix(P["card_inner_monster"], P["monster"], 0.12))
inner("card_inner_locked", mix(P["card_inner"], INK, 0.08), mix(P["card_inner"], W, 0.03), mix(P["card_inner"], W, 0.04))

# Big padlock for locked cards (white body, keyhole), 64x76.
d = Doc(64, 76)
d.line("M18 34 V22 C18 6 46 6 46 22 V34", P["text"], 7, 2.8)
d.cel(rrect(6, 32, 52, 40, 8), P["text"], "#C9BFB0", off=(-3, -4), ow=4)
d.flat(circle(32, 48, 6), INK, 0)
d.flat(poly([(29, 50), (35, 50), (37, 63), (27, 63)]), INK, 0)
ICONS["padlock"] = d.svg()

# Notification dot 24x24.
d = Doc(24, 24)
d.cel(circle(12, 12, 9), P["notify"], P["upgrade_ready_dark"], off=(-1.5, -1.5), ow=3)
d.fleck(ellipse(9, 8.5, 2.6, 1.8, -35), W, 0.9)
ICONS["dot_notify"] = d.svg()

# =========================================================== BOTTOM NAV
# Carved-wood plaque tab 112x116 (margins 22/22/22/22).


def plaque(name, wood, wood_s, rim=INK, rim_w=4.0, moss=True, lift=0):
    d = Doc(112, 116)
    y0 = 8 - lift
    body = (f"M10 {y0 + 4} C30 {y0} 50 {y0 + 3} 70 {y0 + 1} C84 {y0} 96 {y0 + 2} 102 {y0 + 4} "
            f"C106 {y0 + 5} 107 {y0 + 9} 107 {y0 + 14} V106 C107 110 104 112 100 112 H12 "
            f"C8 112 5 110 5 106 V{y0 + 14} C5 {y0 + 9} 6 {y0 + 5} 10 {y0 + 4}Z")
    d.cel(body, wood, wood_s, off=(-3, -4), ow=0)
    # grain
    for x, a, b in ((26, 22, 66), (44, 40, 98), (62, 18, 52), (80, 46, 100), (92, 20, 44)):
        d.ink(f"M{x} {y0 + a} C{x - 2} {y0 + (a + b) / 2} {x + 2} {y0 + (a + b) / 2 + 6} {x} {y0 + b}", 2,
              color=mix(wood, INK, 0.3), op=0.7)
    d.ink(f"M16 {y0 + 10} H40", 2.4, color=mix(wood, W, 0.25), op=0.7)
    d.add(f'<path d="{rrect(12, y0 + 12, 88, 104 - y0 - 12 - 2, 6)}" fill="none" stroke="{mix(wood, INK, 0.45)}" '
          f'stroke-width="2.4" opacity="0.8"/>')
    d.add(f'<path d="{body}" fill="none" stroke="{rim}" stroke-width="{rim_w}" stroke-linejoin="round"/>')
    if rim != INK:
        d.add(f'<path d="{body}" fill="none" stroke="{INK}" stroke-width="1.6" stroke-linejoin="round" '
              f'transform="translate(56 58) scale(0.94 0.95) translate(-56 -58)"/>')
    if moss:
        d.cel(f"M5 {y0 + 26} C2 {y0 + 14} 8 {y0 + 2} 22 {y0 + 2} C30 {y0 + 2} 36 {y0 + 6} 34 {y0 + 10} "
              f"C26 {y0 + 8} 18 {y0 + 12} 14 {y0 + 18} C12 {y0 + 22} 8 {y0 + 26} 5 {y0 + 26}Z",
              P["moss_light"], P["moss"], ow=2.6)
        d.cel(leaf(100, y0 + 6, 110, y0 - 6, 0.4), P["leaf"], P["moss"], ow=2.4)
    for x in (18, 94):
        d.flat(circle(x, 104 - lift * 0, 2.6), mix(wood, INK, 0.55), 0)
    ICONS[name] = d.svg()
    MARGINS[name] = (22, 24, 22, 22)


plaque("plaque_tab", P["wood"], P["wood_dark"])
plaque("plaque_tab_selected", P["wood_light"], P["wood"], rim=P["amber"], rim_w=4.5, lift=0)
plaque("plaque_tab_disabled", mix(P["wood"], P["bg_base"], 0.55), mix(P["wood_dark"], P["bg_base"], 0.5), moss=False)


def arch(name, selected):
    """Central HUNT arch (the reference's Lobby tab): mossy stone gothic arch,
    dark recess for the glyph, keystone gem, hanging vines. 140x160."""
    d = Doc(140, 160)
    outer = "M6 156 V76 C6 40 40 14 70 4 C100 14 134 40 134 76 V156Z"
    inner_ = "M26 156 V82 C26 56 48 36 70 26 C92 36 114 56 114 82 V156Z"
    d.cel(outer, P["stone"], P["stone_dark"], off=(-4, -4), ow=0)
    # voussoir seams between outer and inner arch
    for (x0, y0, x1, y1) in ((6, 116, 26, 116), (134, 116, 114, 116), (8, 76, 27, 82), (132, 76, 113, 82),
                             (22, 42, 38, 54), (118, 42, 102, 54), (48, 16, 56, 33), (92, 16, 84, 33)):
        d.ink(f"M{x0} {y0} L{x1} {y1}", 2.6, color=P["stone_dark"])
    for (x, y) in ((14, 100), (124, 132), (12, 138), (126, 94)):
        d.fleck(circle(x, y, 2.2), P["stone_hi"], 0.6)
    d.add(f'<path d="{outer}" fill="none" stroke="{INK}" stroke-width="4.5" stroke-linejoin="round"/>')
    rec = mix(P["bg_void"], P["moss_dark"], 0.18) if not selected else mix(P["bg_void"], P["amber_dark"], 0.22)
    d.cel(inner_, rec, mix(rec, INK, 0.4), off=(3, 4), ow=3.5)
    if selected:
        d.add(f'<path d="{inner_}" fill="none" stroke="{P["amber"]}" stroke-width="3" stroke-linejoin="round" '
              f'transform="translate(70 92) scale(0.9 0.93) translate(-70 -92)"/>')
    # keystone + gem
    d.cel(poly([(58, 4), (82, 4), (78, 30), (62, 30)]), P["stone_light"], P["stone"], ow=3.5)
    gem = P["amber"] if selected else P["moss_light"]
    d.cel(poly([(70, 9), (76, 16), (70, 24), (64, 16)]), gem, mix(gem, INK, 0.4), ow=2.6)
    # moss on the shoulders
    d.cel("M4 86 C2 70 8 54 20 44 C24 52 22 60 26 66 C18 70 12 78 4 86Z", P["moss_light"], P["moss"], ow=3)
    d.cel("M136 86 C138 70 132 54 120 44 C116 52 118 60 114 66 C122 70 128 78 136 86Z", P["moss"], P["moss_dark"], ow=3)
    # vines hanging down the OUTER faces of the pillars (the recess stays clear for the glyph)
    d.line("M10 78 C4 92 12 104 8 118 C6 126 8 134 10 140", P["moss"], 2.6, 1.8)
    d.line("M130 80 C136 94 128 108 132 120", P["moss"], 2.6, 1.8)
    for (x0, y0, x1, y1) in ((8, 96, 0, 104), (9, 112, 18, 120), (8, 132, 0, 142), (132, 98, 140, 106), (131, 116, 122, 126)):
        d.cel(leaf(x0, y0, x1, y1, 0.42), P["leaf"], P["moss"], ow=2.2)
    ICONS[name] = d.svg()
    MARGINS[name] = (34, 90, 34, 24)


arch("arch_tab", False)
arch("arch_tab_selected", True)

# =========================================================== BUTTONS
BTN = {
    "primary": (P["amber"], P["amber_dark"], P["amber_light"]),
    "copper": (P["copper"], P["copper_dark"], P["copper_light"]),
    "secondary": (P["stone"], P["stone_dark"], P["stone_light"]),
    "hero": (P["moss"], P["moss_dark"], P["moss_light"]),
    "monster": (P["monster"], P["monster_dark"], P["monster_light"]),
    "disabled": (mix(P["stone_dark"], P["bg_base"], 0.4), mix(P["stone_dark"], INK, 0.3), mix(P["stone"], P["bg_base"], 0.5)),
}


def button(name, base, shade, light, pressed=False, hover=False):
    d = Doc(96, 60)
    lip = 2 if pressed else 7
    top = 9 if pressed else 4
    if hover:
        base, light = mix(base, W, 0.12), mix(light, W, 0.15)
    d.flat(rrect(3, top, 90, 47 + (4 - top) + 5, 11), shade, 0)
    d.flat(rrect(3, top, 90, 47 - lip + 5 + (4 - top) + (0 if not pressed else 0), 11), base, 0)
    d.ink(f"M14 {top + 6} H44", 3, color=light, op=0.9)
    d.ink(f"M50 {top + 6} H56", 3, color=light, op=0.9)
    d.add(f'<path d="{rrect(3, top, 90, 52 - top + 4, 11)}" fill="none" stroke="{INK}" stroke-width="3.6" stroke-linejoin="round"/>')
    ICONS[name] = d.svg()
    MARGINS[name] = (16, 14, 16, 16)


for k, (b, s, l) in BTN.items():
    button(f"btn_{k}", b, s, l)
    if k != "disabled":
        button(f"btn_{k}_pressed", b, s, l, pressed=True)
        button(f"btn_{k}_hover", b, s, l, hover=True)


def round_button(name, base, shade, light, pressed=False):
    d = Doc(64, 68)
    top = 8 if pressed else 3
    d.flat(circle(32, 36, 29), shade, 0)
    d.flat(circle(32, top + 29, 29), base, 0)
    d.ink(arc(32, top + 29, 21, 200, 250), 3, color=light, op=0.9)
    d.add(f'<path d="M3 {top + 29} A29 29 0 0 1 61 {top + 29} V36 A29 29 0 0 1 3 36Z" fill="none" '
          f'stroke="{INK}" stroke-width="3.6" stroke-linejoin="round"/>')
    ICONS[name] = d.svg()


for k in ("primary", "secondary", "hero", "monster"):
    b, s, l = BTN[k]
    round_button(f"btn_round_{k}", b, s, l)
    round_button(f"btn_round_{k}_pressed", b, s, l, pressed=True)

# =========================================================== PANELS
d = frame_doc(96, 96, P["copper"], P["panel_fill"], r=10, bw=3.0, pad=4)
ICONS["panel"] = d.svg()
MARGINS["panel"] = (16, 16, 16, 16)

d = Doc(96, 96)
d.flat(rrect(3, 3, 90, 90, 8), P["panel_inset"], 0)
d.flat("M6 6 H90 V12 C60 9 36 9 6 12Z", INK, 0, op=0.45)
d.add(f'<path d="{rrect(3, 3, 90, 90, 8)}" fill="none" stroke="{INK}" stroke-width="3"/>')
d.add(f'<path d="M10 92.5 H86" stroke="{P["divider"]}" stroke-width="1.5" opacity="0.8"/>')
ICONS["panel_inset"] = d.svg()
MARGINS["panel_inset"] = (12, 14, 12, 12)

d = frame_doc(96, 96, P["copper"], P["panel_fill"], r=10, bw=3.0, pad=4)
sprig(d, 12, 14, 1, 0.9)
sprig(d, 84, 14, -1, 0.9)
ICONS["panel_leafy"] = d.svg()
MARGINS["panel_leafy"] = (26, 26, 26, 16)

d = frame_doc(96, 96, mix(P["monster"], P["copper"], 0.25), P["panel_fill"], r=10, bw=3.0, pad=4)
_monster_spikes(d)
ICONS["panel_monster"] = d.svg()
MARGINS["panel_monster"] = (18, 18, 18, 16)


def banner(name, wood, shade, leaves=True):
    """Carved wood header plank with swallow-tail ends. 220x64."""
    d = Doc(220, 64)
    d.cel("M4 14 H34 V52 H4 L14 33Z", mix(wood, INK, 0.25), mix(wood, INK, 0.5), ow=3.2)
    d.cel("M216 14 H186 V52 H216 L206 33Z", mix(wood, INK, 0.25), mix(wood, INK, 0.5), ow=3.2)
    body = rrect(22, 6, 176, 46, 6)
    d.cel(body, wood, shade, off=(-3, -4), ow=0)
    for x, a, b in ((60, 14, 30), (120, 30, 46), (160, 12, 26), (90, 40, 48)):
        d.ink(f"M{x} {a + 2} C{x + 16} {a + 4} {x + 30} {a} {x + 46} {a + 2}", 2, color=mix(wood, INK, 0.3), op=0.6)
    d.ink("M32 12 H70", 2.4, color=mix(wood, W, 0.25), op=0.7)
    d.add(f'<path d="{body}" fill="none" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>')
    if leaves:
        sprig(d, 30, 12, 1, 0.8)
        sprig(d, 190, 12, -1, 0.8)
    ICONS[name] = d.svg()
    MARGINS[name] = (44, 16, 44, 16)


banner("banner", P["wood"], P["wood_dark"])
banner("banner_hero", mix(P["wood"], P["hero"], 0.25), P["wood_dark"])
banner("banner_monster", mix(P["monster_dark"], P["monster_purple"], 0.3), mix(P["monster_dark"], INK, 0.4), leaves=False)
# The match result's outcome ribbons (MatchResultScreen): copper for a heroes
# win, crimson for a monster win, grey stone for a loss or TIME UP.
banner("banner_victory", P["copper"], P["copper_dark"])
banner("banner_victory_monster", P["monster"], P["monster_dark"], leaves=False)
banner("banner_defeat", P["stone"], P["stone_dark"], leaves=False)

# =========================================================== HUD ABILITY SLOTS
# 72x72 ring frames drawn OVER the 64x64 icon (icon at offset 4,4).


def slot(name, col, r=13, extra=None):
    d = Doc(72, 72)
    ring = rrect(3.5, 3.5, 65, 65, r)
    hole = rrect(9, 9, 54, 54, max(r - 5, 4))
    d.add(f'<path d="{ring} {hole}" fill="{col}" fill-rule="evenodd"/>')
    d.add(f'<path d="M68.5 {3.5 + r} V{68.5 - r} A{r} {r} 0 0 1 {68.5 - r} 68.5 H{3.5 + r}" fill="none" '
          f'stroke="{mix(col, INK, 0.35)}" stroke-width="2.6" transform="translate(-1.4 -1.4)"/>')
    d.add(f'<path d="{ring}" fill="none" stroke="{INK}" stroke-width="3.5"/>')
    d.add(f'<path d="{hole}" fill="none" stroke="{INK}" stroke-width="2.4"/>')
    if extra:
        extra(d)
    ICONS[name] = d.svg()


slot("slot_basic", P["stone_light"])
slot("slot_active", P["copper"])
def _passive(d):
    d.cel(leaf(12, 12, 0, -2, 0.42), P["leaf"], P["moss"], ow=2.4)
    d.cel(leaf(12, 12, -2, 8, 0.42), P["moss_light"], P["moss"], ow=2.4)


slot("slot_passive", P["moss_light"], extra=_passive)
slot("slot_locked", P["locked_line"])


def _ult(d):
    for (x0, y0, x1, y1) in ((10, 10, -2, -2), (62, 10, 74, -2), (10, 62, -2, 74), (62, 62, 74, 74)):
        d.cel(leaf(x0, y0, x1, y1, 0.42), P["amber_light"], P["amber_dark"], ow=2.4)


slot("slot_ult", P["amber"], extra=_ult)

# =========================================================== ORNAMENTS
d = Doc(64, 64)
d.cel(leaf(4, 4, 46, 14, 0.36, 0.1), P["moss_light"], P["moss"], ow=2.8)
d.cel(leaf(4, 4, 14, 46, 0.36, -0.1), P["moss"], P["moss_dark"], ow=2.8)
d.cel(leaf(4, 4, 34, 32, 0.34), P["leaf"], P["moss"], ow=2.8)
d.ink(leaf_vein(4, 4, 34, 32), 1.8, color=P["moss"])
ICONS["orn_leaf_corner"] = d.svg()

d = Doc(240, 32)
d.line("M8 18 C40 8 70 26 100 16 C110 13 116 14 120 16 C124 14 130 13 140 16 C170 26 200 8 232 18", P["moss"], 3, 2)
for (x0, y0, x1, y1) in ((40, 13, 30, 2), (64, 20, 76, 30), (88, 17, 96, 6), (152, 17, 144, 6), (176, 20, 164, 30),
                         (200, 13, 210, 2)):
    d.cel(leaf(x0, y0, x1, y1, 0.42), P["leaf"], P["moss"], ow=2.2)
d.cel(poly([(120, 6), (128, 16), (120, 26), (112, 16)]), P["amber"], P["amber_dark"], ow=2.8)
ICONS["orn_vine_divider"] = d.svg()

d = Doc(28, 120)
d.line("M14 0 C8 20 20 40 12 60 C6 76 16 96 14 116", P["moss"], 3, 2)
for (x0, y0, x1, y1) in ((12, 22, 2, 30), (16, 44, 26, 52), (10, 68, 0, 76), (15, 92, 25, 100), (14, 114, 8, 120)):
    d.cel(leaf(x0, y0, x1, y1, 0.42), P["leaf"], P["moss"], ow=2.2)
ICONS["orn_vine_hang"] = d.svg()

# Canopy silhouette for the top edge of screens (stretch 2x to 720 wide).
d = Doc(360, 110)
dark, mid = mix(P["bg_base"], INK, 0.45), mix(P["bg_base"], P["moss_dark"], 0.35)
d.flat("M0 0 H360 V20 C330 26 300 18 280 24 C250 34 220 20 190 26 C160 32 130 20 100 28 C70 34 40 22 0 30Z", dark, 0)
for i, (x, l, a) in enumerate(((12, 60, 20), (40, 90, -14), (78, 50, 10), (110, 80, -24), (150, 66, 16),
                                (190, 96, -8), (226, 56, 22), (262, 84, -18), (300, 64, 12), (338, 92, -20))):
    import math
    x1 = x + math.sin(math.radians(a)) * l
    y1 = 14 + math.cos(math.radians(a)) * l
    d.flat(leaf(x, 14, x1, y1, 0.3, 0.1 if i % 2 else -0.1), mid if i % 3 else dark, 0)
d.line("M0 8 C60 20 120 4 180 12 C240 20 300 6 360 14", mix(P["wood_dark"], INK, 0.3), 4, 0)
ICONS["orn_canopy_top"] = d.svg()

# Tileable background texture: flecks + faint fronds on bg_base.
d = Doc(256, 256)
d.flat("M0 0 H256 V256 H0Z", P["bg_base"], 0)
import random
rng = random.Random(7)
for i in range(70):
    x, y = rng.uniform(0, 256), rng.uniform(0, 256)
    w = rng.uniform(4, 14)
    d.ink(f"M{x:.1f} {y:.1f} l{w:.1f} {rng.uniform(-1.5, 1.5):.1f}", rng.uniform(1.2, 2.4),
          color=P["bg_fleck"] if i % 3 else mix(P["bg_base"], INK, 0.3), op=0.9)
for (x0, y0, x1, y1) in ((30, 220, 70, 150), (190, 60, 236, 4), (150, 250, 120, 190)):
    d.flat(leaf(x0, y0, x1, y1, 0.34), mix(P["bg_base"], P["moss_dark"], 0.12), 0)
ICONS["bg_texture"] = d.svg()

# =========================================================== FORM CONTROLS
d = Doc(32, 32)
d.cel(circle(16, 16, 12), P["amber"], P["amber_dark"], off=(-2, -2), ow=3.2)
d.fleck(ellipse(12, 11, 3.4, 2.2, -35), W, 0.8)
ICONS["slider_grabber"] = d.svg()


def toggle(name, on):
    d = Doc(60, 34)
    track = P["moss"] if on else P["panel_inset"]
    d.cel(rrect(3, 4, 54, 26, 13), track, mix(track, INK, 0.35), off=(0, -3), ow=3.2)
    cx = 43 if on else 17
    d.cel(circle(cx, 17, 10), P["text"] if on else P["stone_light"], "#C9BFB0" if on else P["stone"], off=(-2, -2), ow=3)
    ICONS[name] = d.svg()


toggle("toggle_on", True)
toggle("toggle_off", False)


def checkbox(name, on):
    d = Doc(36, 36)
    d.cel(rrect(3, 3, 30, 30, 7), P["panel_inset"], INK, off=(0, 2), ow=3.2)
    if on:
        d.cel("M7 18 L13 12 L17 16 L28 4 L33 10 L17 28Z", P["amber"], P["amber_dark"], ow=2.8)
    ICONS[name] = d.svg()


checkbox("check_on", True)
checkbox("check_off", False)
