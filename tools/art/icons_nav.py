"""Bottom-nav glyphs, drawn in colour (they sit on carved wood / mossy stone
plaques like the reference's Inventory / Mercenary / Lobby ... tabs).
64x64, transparent; shown at 40-56 px."""
from palette import PAL as P, mix
from svgkit import icon, circle, ellipse, rrect, poly, star, gear, leaf, leaf_vein, arc, INK

ICONS = {}
W = "#FFFFFF"
IVORY, IVORY_S = "#EFE3C8", "#BFA987"
STEEL, STEEL_S = P["steel_light"], P["steel"]

# HUNT (central arch, = the reference's "Lobby"): crossed spears over a leaf.
d = icon()
d.cel(leaf(32, 60, 32, 4, 0.42), P["moss_light"], P["moss"])
d.ink(leaf_vein(32, 60, 32, 4), 2.4, color=P["moss_dark"])
for tf in ("rotate(38 32 32)", "rotate(-38 32 32)"):
    d.cel(rrect(29.5, 20, 5, 44, 2.5), P["wood_light"], P["wood"], tf=tf, ow=3)
    d.cel("M32 0 C38 6 39 14 32 22 C25 14 26 6 32 0Z", STEEL, STEEL_S, tf=tf, ow=3)
    d.cel(rrect(28, 21, 8, 5, 2), P["copper"], P["copper_dark"], tf=tf, ow=2.6)
ICONS["nav_hunt"] = d.svg()

# HEROES: round helmet with nose guard and a hero-amber plume.
d = icon()
d.cel("M30 12 C30 4 40 0 50 4 C44 6 40 10 38 16Z", P["hero"], P["hero_dark"], ow=3)
d.cel("M10 40 C10 22 20 12 32 12 C44 12 54 22 54 40 L54 50 C54 54 50 56 46 56 L40 56 L40 42 L24 42 L24 56 L18 56 C14 56 10 54 10 50Z",
      STEEL, STEEL_S, off=(-3, -3))
d.cel(rrect(29, 30, 6, 22, 2.5), P["copper"], P["copper_dark"], ow=3)
d.cel(rrect(8, 30, 48, 7, 3), P["copper"], P["copper_dark"], ow=3)
d.fleck("M17 26 C18 21 22 17 26 16 L27 19 C24 20 21 23 20 27Z", W, 0.8)
ICONS["nav_heroes"] = d.svg()

# MONSTERS: bull skull, crimson eyes.
d = icon()
d.cel("M16 26 C6 22 2 12 4 2 C9 10 16 14 24 16Z", IVORY, IVORY_S, ow=3.2)
d.cel("M48 26 C58 22 62 12 60 2 C55 10 48 14 40 16Z", IVORY, IVORY_S, ow=3.2)
d.cel("M32 12 C45 12 52 21 52 31 C52 38 48 42 46 46 L44 56 C40 62 24 62 20 56 L18 46 C16 42 12 38 12 31 C12 21 19 12 32 12Z",
      IVORY, IVORY_S)
d.cel("M18 29 L29 33 L27 39 L18 36Z", P["monster"], P["monster_dark"], ow=2.8)
d.cel("M46 29 L35 33 L37 39 L46 36Z", P["monster"], P["monster_dark"], ow=2.8)
d.flat("M29 47 L32 43 L35 47Z", INK, 0)
d.ink("M25 52 L27 57 M32 52 V58 M39 52 L37 57", 2.4)
d.ink("M32 14 L30 21 L33 25", 2.2, color=IVORY_S)
ICONS["nav_monsters"] = d.svg()

# GROWTH (skill tree): sapling with three leaves on a mossy stone.
d = icon()
d.cel(ellipse(32, 54, 24, 8), P["stone"], P["stone_dark"])
d.flat("M14 52 C18 48 24 50 26 52 C22 54 18 54 14 52Z", P["moss_light"], 0)
d.line("M32 52 C32 42 30 34 32 24", P["wood_light"], 4, 2.2)
d.line("M31 40 C26 36 22 36 18 36", P["wood_light"], 3, 2)
d.cel(leaf(31, 26, 32, 2, 0.4), P["leaf"], P["moss"])
d.cel(leaf(31, 32, 8, 18, 0.38, 0.1), P["moss_light"], P["moss"])
d.cel(leaf(33, 32, 58, 20, 0.38, -0.1), P["moss_light"], P["moss"])
d.cel(star(48, 46, 6, 2.4, 4), P["amber_light"], P["amber"], ow=2.4)
ICONS["nav_growth"] = d.svg()

# CODEX / records: bound book with a leaf bookmark.
d = icon()
d.cel(rrect(10, 8, 44, 50, 4), P["wood"], P["wood_dark"])
d.cel(rrect(14, 12, 40, 44, 3), IVORY, IVORY_S, ow=3)
d.cel(rrect(10, 8, 12, 50, 4), P["copper"], P["copper_dark"], ow=3)
d.ink("M28 22 H46 M28 30 H46 M28 38 H40", 2.6, color=IVORY_S)
d.cel("M42 50 L42 64 L46 60 L50 64 L50 50Z", P["monster"], P["monster_dark"], ow=2.6)
ICONS["nav_codex"] = d.svg()

# SETTINGS: carved stone cog with a moss tuft.
d = icon()
d.cel(gear(32, 32, 28, 21, 8), P["stone_light"], P["stone"], off=(-3, -3))
d.cel(circle(32, 32, 9), P["bg_base"], INK, ow=3.2)
d.flat("M8 22 C10 16 16 14 20 16 C16 18 12 20 8 22Z", P["moss_light"], 2.4)
ICONS["nav_settings"] = d.svg()
