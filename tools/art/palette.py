"""Jungle Guild palette (UnderGuild collection screen, jungle-flavoured).

Single source of truth for the SVG generators, the Godot theme and the runtime
palette: `python3 tools/art/make_theme.py palette` writes the UiPalette
resource (Scenes/UI/Theme/palette.tres), the token exports of
Scenes/UI/Theme/ui_palette.gd and tools/art/palette.json from GROUPS. Edit the
colours here, never in those generated files. Every value is sRGB hex; group
order = order in the swatch sheet and in the inspector.
"""

GROUPS = [
    ("Surfaces (warm charcoal)", [
        ("bg_void", "#1E1C1A", "letterbox, under the nav bar, modal scrim base"),
        ("bg_base", "#2A2826", "screen background (flat)"),
        ("bg_fleck", "#33302D", "background texture flecks / stripes, raised strips"),
        ("card_fill", "#3A3633", "character card body"),
        ("card_inner", "#2E2B29", "card inner panel (neutral)"),
        ("card_inner_hero", "#2C302A", "card inner panel, hero side (moss tint)"),
        ("card_inner_monster", "#322A2D", "card inner panel, monster side (plum tint)"),
        ("panel_fill", "#34312E", "panels, dialogs"),
        ("panel_inset", "#242220", "wells, bar troughs, pills, slots"),
        ("divider", "#4A4541", "hairlines inside panels"),
    ]),
    ("Ink and text", [
        ("ink", "#1A1311", "every outline (dark brown-black)"),
        ("ink_soft", "#2B201C", "secondary outlines, inner lines"),
        ("text", "#F6F1E7", "primary text, Lv.N, counters (always with ink outline)"),
        ("text_dim", "#CFC6B8", "secondary text"),
        ("text_muted", "#8F877C", "hints, disabled text"),
        ("text_on_light", "#2A1A10", "text on amber / parchment buttons"),
    ]),
    ("Copper and amber (primary accent)", [
        ("copper", "#C86A32", "card / panel / slot outline"),
        ("copper_dark", "#8A4421", "copper shade, pressed"),
        ("copper_light", "#E38C4E", "copper highlight, hover"),
        ("amber", "#F2A93B", "selected, active tab, focus, cooldown ring"),
        ("amber_light", "#FFD27A", "amber highlight"),
        ("amber_dark", "#B06E1A", "amber shade"),
    ]),
    ("Jungle secondaries", [
        ("moss_dark", "#2E4A2C", "moss shade"),
        ("moss", "#4F7A3A", "moss patches, hero buttons"),
        ("moss_light", "#86AE4E", "moss highlight"),
        ("leaf", "#A8C95E", "leaf ornaments, vines"),
        ("teal_dark", "#1E4744", "teal shade"),
        ("teal", "#2F7570", "secondary accent (water, info)"),
        ("teal_light", "#62B0A3", "teal highlight"),
        ("wood_dark", "#43291F", "carved wood shade"),
        ("wood", "#6B4330", "carved wood plaques"),
        ("wood_light", "#8E6143", "wood highlight / selected plaque"),
        ("wood_hi", "#B4875D", "wood grain flecks"),
        ("stone_dark", "#3B3D39", "mossy stone shade"),
        ("stone", "#5D6058", "mossy stone (central arch)"),
        ("stone_light", "#878A7D", "stone highlight"),
        ("stone_hi", "#ADAE9E", "stone chips"),
        ("parchment", "#D8C6A0", "light labels, tooltips body (rare)"),
        ("parchment_dark", "#AE9670", "parchment shade"),
    ]),
    ("Factions", [
        ("hero", "#E39A3B", "hero side accent (warm amber-copper)"),
        ("hero_dark", "#7A4A1E", "hero shade"),
        ("hero_light", "#F6C878", "hero highlight"),
        ("hero_moss", "#6E9A44", "hero secondary (jungle green)"),
        ("monster", "#C2334A", "monster side accent (crimson)"),
        ("monster_dark", "#5A1626", "monster shade"),
        ("monster_light", "#EE6F7A", "monster highlight"),
        ("monster_purple", "#7B3F95", "monster secondary (purple)"),
        ("monster_purple_dark", "#3F1E50", "monster purple shade"),
    ]),
    ("Hero signatures (UI fills; in-world rings keep their saturated colours)", [
        ("irelia", "#5DB6C2", "Irelia - teal headband, steel"),
        ("irelia_dark", "#2C5E66", ""),
        ("irelia_light", "#A9DDE2", ""),
        ("vlad", "#C9473C", "Vlad - blood red"),
        ("vlad_dark", "#6C1F1C", ""),
        ("vlad_light", "#EA8A7C", ""),
        ("ted", "#E1B43E", "Ted - honey blond"),
        ("ted_dark", "#7E5B1B", ""),
        ("ted_light", "#F4D883", ""),
        ("river", "#69A653", "River - fern green"),
        ("river_dark", "#2F5A2C", ""),
        ("river_light", "#A9D388", ""),
    ]),
    ("Monster signatures", [
        ("grount", "#B8423A", "Grount - rust crimson bull"),
        ("grount_dark", "#5E1D1A", ""),
        ("grount_light", "#E07C6A", ""),
        ("grount_hide", "#6A4A4C", "Grount hide (muted plum-brown)"),
        ("grount_hide_dark", "#46302F", ""),
        ("monster2", "#8D55C2", "monster slot 2 (provisional: Nyxa, violet)"),
        ("monster2_dark", "#42245E", ""),
        ("monster2_light", "#C69BEA", ""),
        ("monster3", "#9AA23A", "monster slot 3 (provisional: Gorrak, bog)"),
        ("monster3_dark", "#4A5020", ""),
        ("monster3_light", "#CFD47A", ""),
    ]),
    ("Currencies", [
        ("gold", "#F0B93A", "Gold (both sides)"),
        ("gold_dark", "#A86E1C", ""),
        ("gold_light", "#FFE08A", ""),
        ("steel", "#A9B6BE", "Steel (heroes)"),
        ("steel_dark", "#5D6A72", ""),
        ("steel_light", "#E3EBEF", ""),
        ("leaves", "#7DB84A", "Leaves (monster)"),
        ("leaves_dark", "#3D6E28", ""),
        ("leaves_light", "#C4E48A", ""),
    ]),
    ("Rank / rarity (skill-tree tiers 1..5, maxed)", [
        ("rank_1", "#A39E94", "common / tier 1 (stone)"),
        ("rank_2", "#6FAE4A", "uncommon / tier 2 (moss)"),
        ("rank_3", "#4EA0C8", "rare / tier 3 (river blue)"),
        ("rank_4", "#9C5ECB", "epic / tier 4 (orchid)"),
        ("rank_5", "#E8963A", "legendary / tier 5 (amber)"),
        ("rank_max", "#F2C94C", "maxed node / star"),
    ]),
    ("States", [
        ("danger", "#E0453A", "damage, enemy HP, warnings"),
        ("danger_dark", "#7E1E18", ""),
        ("heal", "#7CCB4E", "healing, hero HP"),
        ("heal_dark", "#3C7426", ""),
        ("xp", "#63B7E6", "XP bars, level-up"),
        ("xp_dark", "#2B5F80", ""),
        ("shield", "#CFE8EF", "shield HP overlay"),
        ("upgrade_ready", "#D9362B", "progress pill when an upgrade is ready"),
        ("upgrade_ready_dark", "#6E1610", ""),
        ("notify", "#E5402F", "notification dot"),
        ("locked_fill", "#141110", "locked silhouette fill (near-black, darker than card_inner)"),
        ("locked_line", "#4A4541", "locked silhouette highlights (faint)"),
        ("cooldown_veil", "#141110", "ability cooldown veil (alpha 0.70)"),
        ("white", "#FFFFFF", ""),
    ]),
]

PAL = {k: v for _, items in GROUPS for k, v, _ in items}


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def godot_color(h, a=1.0):
    r, g, b = hexrgb(h)
    return f"Color({r:.4g}, {g:.4g}, {b:.4g}, {a:.4g})"


def mix(a, b, t):
    ra, ga, ba = hexrgb(a)
    rb, gb, bb = hexrgb(b)
    c = [round((x * (1 - t) + y * t) * 255) for x, y in ((ra, rb), (ga, gb), (ba, bb))]
    return "#" + "".join(f"{v:02X}" for v in c)
