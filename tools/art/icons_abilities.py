"""Ability icons, one per ability resource (+ River's two basic modes and
Grount's stage passive). 64x64 full-bleed owner tile + one bold symbol.
Naming: <owner>_<slot>_<ability>.svg  (slot = basic|active|passive|ult)."""
import math
from palette import PAL as P, mix
from svgkit import (icon, circle, ellipse, rrect, poly, smooth, star, burst, heart, drop, leaf,
                    leaf_vein, arc, INK)

ICONS = {}
W = "#FFFFFF"
IVORY = "#EFE3C8"
IVORY_S = "#BFA987"
STEEL = P["steel_light"]
STEEL_S = P["steel"]
BLOOD = "#C8323A"
BLOOD_S = "#7E1A22"


def anger(d, cx, cy, s=1.0, col=None):
    """Manga anger mark (four bent ticks)."""
    col = col or P["danger"]
    k = s
    p = (f"M{cx - 7 * k} {cy - 2.5 * k} Q{cx - 2.5 * k} {cy - 2.5 * k} {cx - 2.5 * k} {cy - 7 * k} "
         f"M{cx + 2.5 * k} {cy - 7 * k} Q{cx + 2.5 * k} {cy - 2.5 * k} {cx + 7 * k} {cy - 2.5 * k} "
         f"M{cx - 7 * k} {cy + 2.5 * k} Q{cx - 2.5 * k} {cy + 2.5 * k} {cx - 2.5 * k} {cy + 7 * k} "
         f"M{cx + 2.5 * k} {cy + 7 * k} Q{cx + 2.5 * k} {cy + 2.5 * k} {cx + 7 * k} {cy + 2.5 * k}")
    d.line(p, col, 3.2, 2.2)


def speed_lines(d, segs, col=None, w=3.0):
    col = col or IVORY
    for s in segs:
        d.line(s, col, w, 2.0)


# ============================================================ IRELIA
d = icon("irelia")
speed_lines(d, ["M6 40 L16 30", "M12 52 L22 42", "M24 58 L32 50"])
tf = "rotate(45 32 32)"
d.cel(rrect(28.5, 30, 7, 36, 3), P["wood_light"], P["wood"], tf=tf)
d.cel(rrect(27.5, 42, 9, 6, 2), P["irelia"], P["irelia_dark"], tf=tf)
d.cel("M32 -4 C43 8 44 20 32 32 C20 20 21 8 32 -4Z", STEEL, STEEL_S, tf=tf)
d.cel("M19 31 C24 27 28 30 32 32 C36 30 40 27 45 31 L43 36 L21 36Z", P["gold"], P["gold_dark"], tf=tf)
anger(d, 15, 15, 1.1)
ICONS["irelia_basic_taunting_strike"] = d.svg()

d = icon("irelia")
d.flat(star(32, 35, 31, 20, 10, -90), mix(P["irelia"], "#2A4D53", 0.55), 0)
KITE = "M32 60 C19 52 12 41 12 27 L12 16 C20 16 26 14 32 8 C38 14 44 16 52 16 L52 27 C52 41 45 52 32 60Z"
d.cel(KITE, P["irelia"], P["irelia_dark"], off=(-3, -3))
d.cel("M32 52 C23 46 19 38 19 29 L19 22 C24 22 28 20.5 32 17 C36 20.5 40 22 45 22 L45 29 C45 38 41 46 32 52Z",
      STEEL, STEEL_S, ow=3)
d.cel(star(32, 34, 11, 4.2, 4), P["amber_light"], P["amber"], ow=2.8)
d.line(ellipse(32, 6, 11, 3.6)[:], P["amber_light"], 3, 2.2)
ICONS["irelia_active_divine_shield"] = d.svg()

d = icon("irelia")
d.cel(heart(28, 36, 22), P["danger"], P["danger_dark"], off=(-3, -3.5))
d.fleck(ellipse(18, 27, 4.2, 2.6, -35), W, 0.8)
d.cel(leaf(40, 24, 56, 6, 0.36), P["leaf"], P["moss"])
d.ink(leaf_vein(40, 24, 56, 6), 1.8)
d.cel(circle(48, 48, 11), P["heal"], P["heal_dark"])
d.line("M48 42 V54 M42 48 H54", W, 3.6, 0)
ICONS["irelia_passive_regeneration"] = d.svg()

d = icon("irelia")
d.line("M3 28 L10 35 L3 42", P["amber"], 3.6, 2.2)
d.line("M61 28 L54 35 L61 42", P["amber"], 3.6, 2.2)
d.cel(circle(32, 37, 22), P["steel"], P["steel_dark"])
d.cel(circle(32, 37, 16.5), P["monster"], P["monster_dark"], ow=3)
d.cel(circle(32, 37, 10.5), IVORY, IVORY_S, ow=3)
d.cel(circle(32, 37, 4.6), P["monster"], P["monster_dark"], ow=2.6)
d.cel(rrect(45, 1, 10, 17, 4.5), P["amber"], P["amber_dark"], ow=3)
d.cel(circle(50, 24.5, 4.4), P["amber"], P["amber_dark"], ow=3)
ICONS["irelia_ult_monster_taunt"] = d.svg()

# ============================================================ VLAD
d = icon("vlad")
d.flat("M62 3 C50 27 30 47 3 60 C25 40 42 22 62 3Z", P["vlad_light"], 0, op=0.55)
tf = "rotate(38 32 32)"
d.cel("M25 44 C22 30 24 14 34 0 C38 4 44 12 44 22 C44 30 41 38 39 44Z", STEEL, STEEL_S, tf=tf)
d.cel("M34 0 C38 4 44 12 44 22 C44 30 41 38 39 44 L36.5 44 C38.5 36 40 28 39 20 C38 12 36 6 34 0Z",
      BLOOD, BLOOD_S, ow=0, tf=tf)
d.ink("M25 44 C22 30 24 14 34 0 C38 4 44 12 44 22 C44 30 41 38 39 44Z", 3.5, tf=tf)
d.cel("M15 45 C21 41 27 43 32 45 C37 43 43 41 49 45 L47 51 L17 51Z", P["gold"], P["gold_dark"], tf=tf)
d.cel(rrect(28.5, 50, 7, 10, 2), P["vlad_dark"], INK, tf=tf)
d.cel(circle(32, 61.5, 3.6), P["gold"], P["gold_dark"], ow=3, tf=tf)
d.cel(drop(55, 31, 4), BLOOD, BLOOD_S, ow=2.8)
d.cel(drop(59, 17, 2.8), BLOOD, BLOOD_S, ow=2.5)
ICONS["vlad_basic_blood_strike"] = d.svg()

d = icon("vlad")
d.cel(drop(32, 47, 10.5), BLOOD, BLOOD_S, off=(-3, -3))
d.fleck(ellipse(28, 45, 2.6, 4), W, 0.7)
d.cel("M14 13 L22 41 L29 16Z", IVORY, IVORY_S)
d.cel("M35 16 L42 41 L50 13Z", IVORY, IVORY_S)
d.cel("M4 8 C14 22 50 22 60 8 L60 3 C48 11 16 11 4 3Z", P["vlad_dark"], INK)
d.cel(drop(21, 48, 2.4), BLOOD, BLOOD_S, ow=2.2)
d.cel(drop(43, 49, 2.4), BLOOD, BLOOD_S, ow=2.2)
ICONS["vlad_passive_bloodlust"] = d.svg()

d = icon("vlad")
d.flat(ellipse(32, 53, 27, 7), INK, 0, op=0.6)
d.line("M19 9 Q15.5 16 19 23", P["danger"], 2.8, 2)
d.line("M45 9 Q48.5 16 45 23", P["danger"], 2.8, 2)
d.cel(rrect(28, 22, 8, 10, 2), P["stone_light"], P["stone"], ow=3)
d.cel("M9 47 C9 25 55 25 55 47Z", P["stone"], P["stone_dark"], off=(-3, -3))
d.cel(rrect(5, 43, 54, 10, 4), P["amber"], P["amber_dark"])
d.add('<path d="M12 52 L17 44 M22 52 L27 44 M32 52 L37 44 M42 52 L47 44" stroke="#1A1311" '
      'stroke-width="3.4" stroke-linecap="butt"/>')
d.add(f'<path d="{rrect(5, 43, 54, 10, 4)}" fill="none" stroke="{INK}" stroke-width="3.5"/>')
d.cel(circle(32, 18, 5.6), P["danger"], P["danger_dark"], ow=3)
d.fleck(circle(30.3, 16.3, 1.7), W, 0.9)
ICONS["vlad_active_land_mine"] = d.svg()

d = icon("vlad")
d.cel(burst(37, 33, 30, 17, 11, -80), P["amber"], P["amber_dark"], ow=2.6)
d.flat(burst(37, 33, 18, 10, 11, -64), P["amber_light"], 0)
d.line("M41 18 C45 11 48 9 52 8", P["wood_light"], 3, 2.2)
d.cel(rrect(34, 15, 10, 9, 2), P["stone"], P["stone_dark"], ow=3, tf="rotate(40 39 19.5)")
d.cel(circle(28, 40, 18), BLOOD, BLOOD_S, off=(-3.5, -3.5))
d.fleck(ellipse(21, 32, 5, 3.2, -35), W, 0.55)
d.cel(drop(28, 44, 5), "#F0A090", "#C8636A", ow=2.6)
d.cel(star(53, 8, 7, 2.6, 4), W, P["amber_light"], ow=2.4)
ICONS["vlad_ult_blood_bomb"] = d.svg()

# ============================================================ TED


def _slash(dx, dy):
    return (f"M{51 + dx} {2 + dy} C{45 + dx} {21 + dy} {31 + dx} {39 + dy} {9 + dx} {56 + dy} "
            f"C{35 + dx} {45 + dy} {52 + dx} {28 + dy} {58 + dx} {6 + dy}Z")


d = icon("ted")
for dx, dy in ((-11, -7), (0, 0), (11, 7)):
    d.cel(_slash(dx, dy), IVORY, IVORY_S, off=(-2, -1.5), ow=3, tf="translate(32 33) scale(0.84) translate(-32 -32)")
ICONS["ted_basic_claw_swipe"] = d.svg()

d = icon("ted")
FUR, FUR_S = "#D9A766", "#97693A"
d.cel(ellipse(13, 30, 6, 7.5, -28), FUR, FUR_S, ow=3.2)
d.cel(ellipse(24, 16.5, 6.5, 8.5, -10), FUR, FUR_S, ow=3.2)
d.cel(ellipse(40, 16.5, 6.5, 8.5, 10), FUR, FUR_S, ow=3.2)
d.cel(ellipse(51, 30, 6, 7.5, 28), FUR, FUR_S, ow=3.2)
d.cel("M32 31 C43 31 52 40 50 50 C48 58 39 57 32 57 C25 57 16 58 14 50 C12 40 21 31 32 31Z", FUR, FUR_S)
d.cel(heart(32, 45, 8.5), P["vlad"], P["vlad_dark"], ow=2.8)
ICONS["ted_passive_loyal_companion"] = d.svg()

d = icon("ted")
d.line("M45 5 Q52 8 55 15", IVORY, 3, 2.2)
d.line("M51 1 Q59 5 62 13", IVORY, 2.6, 2)
d.line("M57 22 Q59.5 26.5 59 32", IVORY, 3, 2.2)
g = "translate(-4 5)"
d.cel("M8 50 C12 54 20 52 26 46 C33 39 37 28 40 15 L55 30 C44 38 36 48 28 54 C20 60 10 60 6 54Z",
      IVORY, IVORY_S, tf=g)
d.line("M19 45.5 L24.5 52.5", P["gold"], 4, 2.2, tf=g)
d.line("M30 36.5 L38.5 45", P["gold"], 4, 2.2, tf=g)
d.cel(ellipse(47.5, 22.5, 11.5, 5, 45), P["wood_dark"], INK, ow=3, tf=g)
d.ink(ellipse(47.5, 22.5, 8, 2.8, 45), 2, tf=g, color=P["gold"])
ICONS["ted_active_rally_cry"] = d.svg()

d = icon("ted")
d.flat("M8 50 A24 24 0 0 1 56 50Z", INK, 0, op=0.7)
d.line("M22 34 L28 36.5", P["grount_light"], 3, 0)
d.line("M42 34 L36 36.5", P["grount_light"], 3, 0)
for x, yt in ((14, 34), (23, 28), (32, 26), (41, 28), (50, 34)):
    d.line(f"M{x} {yt} V50", STEEL, 3.2, 1.8)
d.line("M8 50 A24 24 0 0 1 56 50", STEEL, 4.4, 2.2)
d.line("M32 26 V19", STEEL, 3, 2)
d.line(circle(32, 15.5, 3.8), STEEL, 2.6, 2)
d.cel(rrect(5, 48, 54, 10, 3.5), P["wood_light"], P["wood"])
d.line("M27 41 V37 A5 5 0 0 1 37 37 V41", P["gold_light"], 3, 2)
d.cel(rrect(23.5, 39.5, 17, 13, 3), P["gold"], P["gold_dark"], ow=3)
d.flat(circle(32, 45, 2.1), INK, 0)
d.flat(rrect(31, 45.5, 2, 4.2, 1), INK, 0)
ICONS["ted_ult_trap_cage"] = d.svg()

# ============================================================ RIVER
d = icon("river")
d.cel(circle(32, 32, 26), P["stone_dark"], INK)
d.cel(circle(32, 32, 19.5), "#9FD3DC", "#5E9AA8", off=(-3, -3), ow=3)
d.ink("M14 32 H25 M39 32 H50 M32 14 V25 M32 39 V50", 3)
d.ink("M19 29.5 V34.5 M45 29.5 V34.5 M29.5 19 H34.5 M29.5 45 H34.5", 2.2)
d.cel(circle(32, 32, 3.8), P["danger"], P["danger_dark"], ow=2.4)
d.fleck("M18 26 A15 15 0 0 1 26 17.5 L28 20 A12 12 0 0 0 21 27Z", W, 0.6)
ICONS["river_basic_sniper"] = d.svg()

d = icon("river")
d.cel(circle(32, 33, 24), "#E7F5DC", "#A9CF94", off=(-3, -3))
d.cel("M26 14 H38 V27 H51 V39 H38 V52 H26 V39 H13 V27 H26Z", P["heal"], P["heal_dark"])
d.cel(star(52, 10, 7, 2.6, 4), W, P["leaves_light"], ow=2.4)
d.cel(star(11, 53, 5, 2, 4), W, P["leaves_light"], ow=2.2)
ICONS["river_basic_heal"] = d.svg()

d = icon("river")
d.line(arc(32, 32, 19, 200, 340), P["amber"], 6, 2.2, cap="butt")
d.cel(poly([(48, 14), (56, 28), (42, 28)]), P["amber"], P["amber_dark"], ow=3, tf="rotate(20 49 24)")
d.line(arc(32, 32, 19, 20, 160), P["heal"], 6, 2.2, cap="butt")
d.cel(poly([(16, 50), (8, 36), (22, 36)]), P["heal"], P["heal_dark"], ow=3, tf="rotate(20 15 40)")
d.cel(circle(32, 32, 9), P["river"], P["river_dark"], ow=3)
d.ink("M27 32 H37 M32 27 V37", 2.6, color=W)
ICONS["river_active_weapon_swap"] = d.svg()

d = icon("river")
speed_lines(d, ["M3 37 H14", "M6 45 H15", "M3 53 H13"])
d.cel("M28 22 C21 14 12 13 6 16 C13 18 17 22 19 26 C13 25 9 26 6 29 C13 30 18 32 22 34Z",
      W, "#C9D3D6", ow=3)
d.cel("M22 10 H40 L40 34 C40 38 44 40 50 41 C57 42 60 46 60 52 L60 56 H20 L22 34Z",
      P["wood_light"], P["wood"])
d.cel(rrect(20, 52, 41, 6, 2.5), P["wood_dark"], INK, ow=3)
d.cel(rrect(20.5, 8, 21, 8, 3), P["river"], P["river_dark"], ow=3)
d.cel(burst(50, 15, 10, 5, 6, -90, (1.0, 0.75, 1.1)), P["danger"], P["danger_dark"], ow=2.6)
ICONS["river_passive_adaptive_movement"] = d.svg()

d = icon("river")
d.cel("M6 30 C6 13 18 4 32 4 C46 4 58 13 58 30 C52 26 46 26 40 30 C36 26 28 26 24 30 C18 26 12 26 6 30Z",
      P["danger"], P["danger_dark"])
d.cel("M24 30 C28 26 36 26 40 30 C40 18 37 8 32 4 C27 8 24 18 24 30Z", IVORY, IVORY_S, ow=2.8)
d.ink("M8 30 L22 44 M56 30 L42 44 M24 30 L28 42 M40 30 L36 42", 2)
d.cel(rrect(17, 40, 30, 21, 3), P["wood_light"], P["wood"])
d.ink("M17 47 H47", 2.4)
d.cel(rrect(26.5, 44, 11, 13, 2), W, "#D7D0C4", ow=2.4)
d.add(f'<path d="M30.5 46.5 H33.5 V49 H36 V52 H33.5 V54.5 H30.5 V52 H28 V49 H30.5Z" fill="{P["danger"]}"/>')
ICONS["river_ult_supply_drop"] = d.svg()

# ============================================================ GROUNT
d = icon("grount")
d.cel("M6 54 C8 30 24 10 52 4 C40 14 30 28 26 46 Z", IVORY, IVORY_S, off=(-2.5, -2))
d.cel("M14 58 C20 40 34 26 58 18 C46 28 38 40 34 56 Z", P["grount_light"], P["grount"], off=(-2.5, -2), ow=3)
d.line("M46 30 L58 32 M44 40 L56 46 M40 50 L50 58", IVORY, 3, 2)
ICONS["grount_front_cleave"] = d.svg()

d = icon("grount")
speed_lines(d, ["M2 20 H14", "M4 30 H12", "M2 42 H14", "M6 52 H15"])
HIDE, HIDE_S = P["grount_hide"], P["grount_hide_dark"]
d.cel("M22 16 C14 12 8 6 9 1 C16 4 22 8 28 13Z", IVORY, IVORY_S, ow=3)
d.cel("M48 16 C56 12 62 6 61 1 C54 4 48 8 42 13Z", IVORY, IVORY_S, ow=3)
d.cel("M35 9 C48 9 56 18 56 30 C56 37 54 42 52 46 L50 54 C46 60 24 60 20 54 L18 46 C16 42 14 37 14 30 C14 18 22 9 35 9Z",
      HIDE, HIDE_S, off=(-3, -3))
d.cel(ellipse(35, 47, 13, 9), "#C98F86", "#9A615C", ow=3)
d.flat(ellipse(30, 47, 2.2, 3), INK, 0)
d.flat(ellipse(40, 47, 2.2, 3), INK, 0)
d.line("M29 54 C31 57 39 57 41 54", P["gold"], 2.6, 1.8)
d.flat("M20 27 L31 31 L28 35 L20 31Z", P["danger"], 2.8)
d.flat("M50 27 L39 31 L42 35 L50 31Z", P["danger"], 2.8)
ICONS["grount_ram_dash"] = d.svg()

d = icon("grount")
# Ground Slam: Grount's fist driven knuckles-first into cracked stone. Read
# order at 40 px: amber impact burst -> pale fist silhouette -> stone slab.
FIST, FIST_S = mix(P["grount_hide"], IVORY, 0.4), P["grount_hide"]
_bp = []
for _i in range(16):   # fat 8-point impact burst, flattened onto the ground line
    _r = (34 * (1.0, 0.82, 0.95, 0.86)[(_i // 2) % 4]) if _i % 2 == 0 else 21
    _a = math.radians(-90 + 22.5 / 2 + _i * 22.5)
    _bp.append((32 + _r * math.cos(_a), 50 + _r * 0.7 * math.sin(_a)))
d.cel(poly(_bp), P["amber"], P["amber_dark"], ow=2.6)
d.cel(ellipse(32, 51, 17, 6), P["amber_light"], P["amber"], ow=0)
d.cel(rrect(1, 55, 62, 11, 3), P["stone"], P["stone_dark"])
d.ink("M30 56 L26 60 L31 63 L28 66 M36 56 L40 60 L37 64", 2.4)
for (x, y, s_) in ((7, 21, 3.0), (57, 19, 3.4)):
    d.cel(poly([(x - s_, y), (x, y - s_), (x + s_, y + s_ * 0.4), (x - s_ * 0.3, y + s_)]), P["stone_light"], P["stone"], ow=2.2)
speed_lines(d, ["M11 4 V16", "M53 4 V16"], IVORY, 2.4)
# forearm with a crimson war-paint band, leaving the top edge
tf = "translate(32 0) scale(0.84 0.92) translate(-32 0)"
d.cel(rrect(22, -6, 20, 26, 6), HIDE, HIDE_S, off=(-3, -2), tf=tf)
d.cel(rrect(21, 8, 22, 6, 2.5), P["grount"], P["grount_dark"], ow=2.6, tf=tf)
# back of the fist + four knuckles hitting the ground
d.cel(rrect(13, 17, 38, 22, 9), FIST, FIST_S, off=(-3, -3), tf=tf)
for i in range(4):
    d.cel(rrect(13 + i * 9.5, 29, 9.5, 22, 4.7), FIST, FIST_S, off=(-2, -2.5), ow=3, tf=tf)
d.cel("M12 30 C12 25 16 23 21 24 L33 26 C37 27 37 33 33 34 L19 35 C15 35 12 33.5 12 30Z", FIST, FIST_S, ow=3, tf=tf)
d.fleck(ellipse(20, 20, 3.4, 1.5, -8), W, 0.45)
ICONS["grount_ground_slam"] = d.svg()

d = icon("grount")
for i, y in enumerate((44, 30, 16)):
    col = [P["grount"], P["monster_light"], P["amber"]][i]
    sh = [P["grount_dark"], P["grount"], P["amber_dark"]][i]
    d.cel(f"M10 {y + 12} L32 {y - 4} L54 {y + 12} L54 {y + 20} L32 {y + 4} L10 {y + 20}Z", col, sh, ow=3.2)
d.cel("M8 14 C4 8 6 2 12 0 C12 6 15 10 20 12Z", IVORY, IVORY_S, ow=2.8)
d.cel("M56 14 C60 8 58 2 52 0 C52 6 49 10 44 12Z", IVORY, IVORY_S, ow=2.8)
ICONS["grount_passive_evolution"] = d.svg()
