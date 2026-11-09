"""Generates the Godot side of the art direction from the palette + kit.

Usage: python3 tools/art/make_theme.py [palette] [theme] [shaders]   (no args = all)
  palette  Scenes/UI/Theme/palette.tres     - the UiPalette resource: every token's value
           Scenes/UI/Theme/ui_palette.gd    - its @export token block (between the markers)
           tools/art/palette.json           - the same tokens for tests and the spec
  theme    Scenes/UI/Theme/ui_theme.tres    - the project Theme (gui/theme/custom, and the
           `theme` of every UI scene), built over the SVG kit in Assets/UI/Kit with the
           Lilita One display font from Assets/Fonts
  shaders  Assets/UI/Shaders/ability_cooldown.gdshader, card_locked.gdshader
"""
import json
import os
import re
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from palette import PAL as P, GROUPS, godot_color as C, hexrgb  # noqa: E402
import kit  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))      # the Godot project (res://)
UI = os.path.join(ROOT, "Assets", "UI")
RES = "res://Assets/UI"
THEME_DIR = os.path.join(ROOT, "Scenes", "UI", "Theme")
THEME_TRES = os.path.join(THEME_DIR, "ui_theme.tres")
THEME_UID = "uid://eroe1xxhr5fc"   # the UI scenes reference ui_theme.tres by this uid: keep it
FONT_DISPLAY = "res://Assets/Fonts/LilitaOne-Regular.ttf"   # SIL OFL 1.1, Assets/Fonts/LilitaOne-OFL.txt
TARGETS = sys.argv[1:] or ["palette", "theme", "shaders"]
for _t in TARGETS:
    if _t not in ("palette", "theme", "shaders"):
        sys.exit(f"unknown target {_t!r}: use palette, theme and/or shaders")

ext = []          # (id, path, type)
subs = []         # text blocks
props = []        # theme property lines


def tex(name):
    rid = "k_" + name
    if not any(e[0] == rid for e in ext):
        ext.append((rid, f"{RES}/Kit/{name}.svg", "Texture2D"))
    return rid


def icon_res(group, name):
    rid = "i_" + name
    if not any(e[0] == rid for e in ext):
        ext.append((rid, f"{RES}/Icons/{group}/{name}.svg", "Texture2D"))
    return rid


def font_res(rid, path):
    if not any(e[0] == rid for e in ext):
        ext.append((rid, path, "FontFile"))
    return rid


def import_uid(res_path):
    """The uid Godot gave an imported file (its .import), so the theme's
    ext_resources carry it the way the editor writes them; "" before the
    first import."""
    imp = os.path.join(ROOT, res_path[len("res://"):]) + ".import"
    if not os.path.exists(imp):
        return ""
    with open(imp) as f:
        m = re.search(r'^uid="(uid://[a-z0-9]+)"', f.read(), re.M)
    return f' uid="{m.group(1)}"' if m else ""


def sb_tex(sid, name, content=None, modulate=None, draw_center=True, expand=None):
    l, t, r, b = kit.MARGINS[name]
    lines = [f'[sub_resource type="StyleBoxTexture" id="{sid}"]']
    if content:
        cl, ct, cr, cb = content
        lines += [f"content_margin_left = {cl:.1f}", f"content_margin_top = {ct:.1f}",
                  f"content_margin_right = {cr:.1f}", f"content_margin_bottom = {cb:.1f}"]
    lines += [f'texture = ExtResource("{tex(name)}")',
              f"texture_margin_left = {l:.1f}", f"texture_margin_top = {t:.1f}",
              f"texture_margin_right = {r:.1f}", f"texture_margin_bottom = {b:.1f}"]
    if expand:
        el, et, er, eb = expand
        lines += [f"expand_margin_left = {el:.1f}", f"expand_margin_top = {et:.1f}",
                  f"expand_margin_right = {er:.1f}", f"expand_margin_bottom = {eb:.1f}"]
    if modulate:
        lines.append(f"modulate_color = {modulate}")
    if not draw_center:
        lines.append("draw_center = false")
    subs.append("\n".join(lines))
    return sid


def sb_flat(sid, bg, border=None, bw=(0, 0, 0, 0), radius=0, content=None, expand=None, shadow=None, aa=True):
    lines = [f'[sub_resource type="StyleBoxFlat" id="{sid}"]']
    if content:
        cl, ct, cr, cb = content
        lines += [f"content_margin_left = {cl:.1f}", f"content_margin_top = {ct:.1f}",
                  f"content_margin_right = {cr:.1f}", f"content_margin_bottom = {cb:.1f}"]
    lines.append(f"bg_color = {bg}")
    if border:
        l, t, r, b = bw
        lines += [f"border_width_left = {l}", f"border_width_top = {t}", f"border_width_right = {r}",
                  f"border_width_bottom = {b}", f"border_color = {border}"]
    if radius:
        rs = radius if isinstance(radius, tuple) else (radius,) * 4
        lines += [f"corner_radius_top_left = {rs[0]}", f"corner_radius_top_right = {rs[1]}",
                  f"corner_radius_bottom_right = {rs[2]}", f"corner_radius_bottom_left = {rs[3]}"]
    if expand:
        el, et, er, eb = expand
        lines += [f"expand_margin_left = {el:.1f}", f"expand_margin_top = {et:.1f}",
                  f"expand_margin_right = {er:.1f}", f"expand_margin_bottom = {eb:.1f}"]
    if shadow:
        col, size, off = shadow
        lines += [f"shadow_color = {col}", f"shadow_size = {size}", f"shadow_offset = Vector2({off[0]}, {off[1]})"]
    if not aa:
        lines.append("anti_aliasing = false")
    subs.append("\n".join(lines))
    return sid


def sb_empty(sid, content=None):
    lines = [f'[sub_resource type="StyleBoxEmpty" id="{sid}"]']
    if content:
        cl, ct, cr, cb = content
        lines += [f"content_margin_left = {cl:.1f}", f"content_margin_top = {ct:.1f}",
                  f"content_margin_right = {cr:.1f}", f"content_margin_bottom = {cb:.1f}"]
    subs.append("\n".join(lines))
    return sid


def p(key, val):
    props.append(f"{key} = {val}")


def SR(i):
    return f'SubResource("{i}")'


def ER(i):
    return f'ExtResource("{i}")'


INK = C(P["ink"])
TXT = C(P["text"])

# ------------------------------------------------------------------ fonts
# font_display, for all display text ("Lv.N", headers, banner titles, nav
# labels, cooldown numbers, counters, buttons), is Lilita One (one weight,
# Latin only). It falls back to font_body for any glyph it lacks.
# font_body, for small body text, is Godot's built-in fallback font (Open Sans
# SemiBold, wide script coverage): a FontVariation without a base_font uses
# it. A slight embolden keeps it legible under the ink outline.
subs.append('[sub_resource type="FontVariation" id="font_body"]\nvariation_embolden = 0.25')
subs.append('[sub_resource type="FontVariation" id="font_display"]\n'
            'fallbacks = Array[Font]([SubResource("font_body")])\n'
            f'base_font = ExtResource("{font_res("f_display", FONT_DISPLAY)}")\nspacing_glyph = 1')
p("default_font", SR("font_body"))
p("default_font_size", 20)

# ------------------------------------------------------------------ labels


def label_type(name, size, color=TXT, outline=6, font="font_display", base=True):
    if base:
        p(f"{name}/base_type", '&"Label"')
    p(f"{name}/fonts/font", SR(font))
    p(f"{name}/font_sizes/font_size", size)
    p(f"{name}/colors/font_color", color)
    p(f"{name}/colors/font_outline_color", INK)
    p(f"{name}/constants/outline_size", outline)


label_type("Label", 20, outline=5, font="font_body", base=False)
label_type("CardLevel", 26, outline=9)               # "Lv.1"
label_type("CardName", 15, C(P["text_dim"]), 5, "font_body")
label_type("PillText", 15, outline=5)                 # "0/1"
label_type("HeaderLarge", 36, outline=11)
label_type("HeaderSmall", 22, C(P["amber"]), 7)
label_type("BannerTitle", 24, outline=8)
label_type("Counter", 20, outline=6)                  # currency amounts
label_type("CooldownNumber", 26, outline=9)
label_type("NavLabel", 15, outline=6)
label_type("Caption", 14, C(P["text_muted"]), 0, "font_body")
label_type("BodyDim", 17, C(P["text_dim"]), 0, "font_body")
label_type("DangerLabel", 20, C(P["danger"]), 6)
label_type("HeroAccentLabel", 20, C(P["hero"]), 6)
label_type("MonsterAccentLabel", 20, C(P["monster_light"]), 6)

# ------------------------------------------------------------------ buttons
BTN_CONTENT = (20, 10, 20, 16)
BTN_PRESSED = (20, 15, 20, 11)


def button_type(name, kind, base=True, txt=TXT):
    if base:
        p(f"{name}/base_type", '&"Button"')
    nm = f"btn_{kind}"
    s_n = sb_tex(f"{name}_normal", nm, BTN_CONTENT)
    if kind == "disabled":
        return
    s_h = sb_tex(f"{name}_hover", nm + "_hover", BTN_CONTENT)
    s_p = sb_tex(f"{name}_pressed", nm + "_pressed", BTN_PRESSED)
    s_d = sb_tex(f"{name}_disabled", "btn_disabled", BTN_CONTENT)
    p(f"{name}/styles/normal", SR(s_n))
    p(f"{name}/styles/hover", SR(s_h))
    p(f"{name}/styles/pressed", SR(s_p))
    p(f"{name}/styles/hover_pressed", SR(s_p))
    p(f"{name}/styles/disabled", SR(s_d))
    p(f"{name}/styles/focus", SR("focus_ring"))
    p(f"{name}/fonts/font", SR("font_display"))
    p(f"{name}/font_sizes/font_size", 22)
    for st in ("font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"):
        p(f"{name}/colors/{st}", txt)
    p(f"{name}/colors/font_disabled_color", C(P["text_muted"]))
    p(f"{name}/colors/font_outline_color", INK)
    p(f"{name}/constants/outline_size", 7)
    p(f"{name}/colors/icon_normal_color", C("#FFFFFF"))
    p(f"{name}/colors/icon_disabled_color", C(P["text_muted"]))
    p(f"{name}/constants/h_separation", 8)
    p(f"{name}/constants/icon_max_width", 36)


sb_flat("focus_ring", C("#000000", 0), C(P["amber_light"], 0.9), (3, 3, 3, 3), 12, expand=(3, 3, 3, 3))
sb_tex("btn_disabled_sb", "btn_disabled", BTN_CONTENT)
button_type("Button", "secondary", base=False)
button_type("ButtonPrimary", "primary")
button_type("ButtonCopper", "copper")
button_type("ButtonHero", "hero")
button_type("ButtonMonster", "monster")

# Round icon buttons (pause / speed / settings / close): 64x68 art, fixed size.
for kind in ("secondary", "primary", "hero", "monster"):
    name = "ButtonRound" + ("" if kind == "secondary" else kind.capitalize())
    p(f"{name}/base_type", '&"Button"')
    n = f"btn_round_{kind}"
    kit.MARGINS.setdefault(n, (24, 24, 24, 26))
    kit.MARGINS.setdefault(n + "_pressed", (24, 24, 24, 26))
    s_n = sb_tex(f"{name}_normal", n, (14, 12, 14, 18))
    s_p = sb_tex(f"{name}_pressed", n + "_pressed", (14, 17, 14, 13))
    for st, s in (("normal", s_n), ("hover", s_n), ("pressed", s_p), ("hover_pressed", s_p), ("disabled", s_n)):
        p(f"{name}/styles/{st}", SR(s))
    p(f"{name}/styles/focus", SR("focus_ring"))
    p(f"{name}/constants/icon_max_width", 34)
    p(f"{name}/colors/icon_normal_color", C("#FFFFFF"))
    p(f"{name}/colors/icon_hover_color", C(P["amber_light"]))
    p(f"{name}/colors/icon_pressed_color", C(P["amber"]))

# Bottom navigation: carved plaques + the central arch.
for name, art, sel in (("NavPlaque", "plaque_tab", "plaque_tab_selected"), ("NavArch", "arch_tab", "arch_tab_selected")):
    p(f"{name}/base_type", '&"Button"')
    cm = (10, 18, 10, 10) if name == "NavPlaque" else (16, 46, 16, 14)
    s_n = sb_tex(f"{name}_normal", art, cm)
    s_s = sb_tex(f"{name}_selected", sel, cm)
    for st, s in (("normal", s_n), ("hover", s_n), ("pressed", s_s), ("hover_pressed", s_s), ("disabled", s_n)):
        p(f"{name}/styles/{st}", SR(s))
    p(f"{name}/styles/focus", SR("empty"))
    p(f"{name}/fonts/font", SR("font_display"))
    p(f"{name}/font_sizes/font_size", 15 if name == "NavPlaque" else 18)
    for st in ("font_color", "font_hover_color", "font_focus_color"):
        p(f"{name}/colors/{st}", C(P["text_dim"]))
    for st in ("font_pressed_color", "font_hover_pressed_color"):
        p(f"{name}/colors/{st}", C(P["amber_light"]))
    p(f"{name}/colors/font_outline_color", INK)
    p(f"{name}/constants/outline_size", 6)
    p(f"{name}/constants/icon_max_width", 52 if name == "NavPlaque" else 64)
    p(f"{name}/constants/h_separation", 2)
sb_empty("empty")
sb_flat("nav_disabled", C(P["bg_void"], 0))

# Filter row (role silhouettes): flat, active = amber underline + amber icon.
p("FilterTab/base_type", '&"Button"')
sb_empty("filter_normal", (8, 6, 8, 8))
sb_flat("filter_active", C(P["amber"], 0.14), C(P["amber"]), (0, 0, 0, 4), (8, 8, 2, 2), (8, 6, 8, 8))
for st, s in (("normal", "filter_normal"), ("hover", "filter_normal"), ("pressed", "filter_active"),
              ("hover_pressed", "filter_active"), ("disabled", "filter_normal"), ("focus", "empty")):
    p(f"FilterTab/styles/{st}", SR(s))
p("FilterTab/colors/icon_normal_color", C(P["text_dim"]))
p("FilterTab/colors/icon_hover_color", C(P["text"]))
p("FilterTab/colors/icon_pressed_color", C(P["amber"]))
p("FilterTab/colors/icon_hover_pressed_color", C(P["amber_light"]))
p("FilterTab/constants/icon_max_width", 34)

# ------------------------------------------------------------------ panels
p("PanelContainer/styles/panel", SR(sb_tex("panel_sb", "panel", (18, 16, 18, 16))))
p("Panel/styles/panel", SR("panel_sb"))
for name, art, cm in (("PanelInset", "panel_inset", (12, 12, 12, 12)),
                      ("PanelLeafy", "panel_leafy", (20, 24, 20, 16)),
                      ("PanelMonster", "panel_monster", (18, 18, 18, 16)),
                      ("CharacterCard", "card_frame", (9, 9, 9, 9)),
                      ("CharacterCardSelected", "card_frame_selected", (9, 9, 9, 9)),
                      ("CharacterCardLocked", "card_frame_locked", (9, 9, 9, 9)),
                      ("CharacterCardMonster", "card_frame_monster", (9, 9, 9, 9)),
                      ("CardInner", "card_inner", (4, 4, 4, 4)),
                      ("CardInnerHero", "card_inner_hero", (4, 4, 4, 4)),
                      ("CardInnerMonster", "card_inner_monster", (4, 4, 4, 4)),
                      ("CardInnerLocked", "card_inner_locked", (4, 4, 4, 4)),
                      ("Banner", "banner", (46, 8, 46, 16)),
                      ("BannerHero", "banner_hero", (46, 8, 46, 16)),
                      ("BannerMonster", "banner_monster", (46, 8, 46, 16))):
    p(f"{name}/base_type", '&"PanelContainer"')
    p(f"{name}/styles/panel", SR(sb_tex(f"{name}_sb", art, cm)))

# Progress pill under "Lv.N": dark normally, RED when an upgrade is ready.
p("Pill/base_type", '&"PanelContainer"')
p("Pill/styles/panel", SR(sb_flat("pill_sb", C(P["panel_inset"]), INK, (2, 2, 2, 2), 12, (12, 1, 12, 2))))
p("PillReady/base_type", '&"PanelContainer"')
p("PillReady/styles/panel", SR(sb_flat("pill_ready_sb", C(P["upgrade_ready"]), INK, (2, 2, 2, 3), 12, (12, 1, 12, 2))))
p("CurrencyPill/base_type", '&"PanelContainer"')
p("CurrencyPill/styles/panel", SR(sb_flat("cur_pill_sb", C(P["panel_inset"], 0.92), INK, (3, 3, 3, 3), 18, (8, 2, 14, 2))))
p("NavBar/base_type", '&"PanelContainer"')
p("NavBar/styles/panel", SR(sb_flat("navbar_sb", C(P["bg_void"]), INK, (0, 4, 0, 0), 0, (8, 0, 8, 6))))
p("HudPanel/base_type", '&"PanelContainer"')
p("HudPanel/styles/panel", SR(sb_flat("hud_sb", C(P["bg_void"], 0.88), C(P["copper"]), (2, 2, 2, 2), 12, (8, 6, 8, 6),
                                       shadow=(C(P["ink"], 0.6), 0, (0, 3)))))
p("HudPanelSelected/base_type", '&"PanelContainer"')
p("HudPanelSelected/styles/panel", SR(sb_flat("hud_sel_sb", C(P["bg_void"], 0.92), C(P["amber"]), (3, 3, 3, 3), 12, (8, 6, 8, 6),
                                               shadow=(C(P["ink"], 0.6), 0, (0, 3)))))
p("TooltipPanel/styles/panel", SR(sb_flat("tooltip_sb", C(P["panel_fill"], 0.97), C(P["copper"]), (2, 2, 2, 2), 8, (12, 8, 12, 8),
                                          shadow=(C(P["ink"], 0.7), 0, (0, 4)))))
label_type("TooltipLabel", 16, C(P["text"]), 0, "font_body", base=False)

# ------------------------------------------------------------------ bars
TROUGH = sb_flat("trough", C(P["panel_inset"]), INK, (2, 2, 2, 2), 7, None)


def bar(name, col, dark, base=True, trough=TROUGH, radius=6, h=None):
    if base:
        p(f"{name}/base_type", '&"ProgressBar"')
    fill = sb_flat(f"{name}_fill", C(col), C(dark), (0, 0, 0, 3), radius, expand=(-2, -2, -2, -2))
    p(f"{name}/styles/background", SR(trough))
    p(f"{name}/styles/fill", SR(fill))
    p(f"{name}/fonts/font", SR("font_display"))
    p(f"{name}/font_sizes/font_size", 14)
    p(f"{name}/colors/font_color", TXT)
    p(f"{name}/colors/font_outline_color", INK)
    p(f"{name}/constants/outline_size", 5)


bar("ProgressBar", P["copper"], P["copper_dark"], base=False)
bar("HpBarHero", P["heal"], P["heal_dark"])
bar("HpBarMonster", P["danger"], P["danger_dark"])
bar("XpBar", P["xp"], P["xp_dark"])
bar("CooldownBar", P["amber"], P["amber_dark"])
bar("ShieldBar", P["shield"], P["steel"], trough=sb_flat("trough_clear", C(P["ink"], 0)))
pill_trough = sb_flat("pill_trough", C(P["panel_inset"]), INK, (2, 2, 2, 2), 12)
pill_ready_trough = sb_flat("pill_ready_trough", C(P["upgrade_ready"]), INK, (2, 2, 2, 3), 12)
bar("PillProgress", P["copper"], P["copper_dark"], trough=pill_trough, radius=10)
bar("PillProgressReady", P["upgrade_ready"], P["upgrade_ready_dark"], trough=pill_ready_trough, radius=10)
p("NavProgress/base_type", '&"ProgressBar"')
p("NavProgress/styles/background", SR(sb_flat("navprog_bg", C(P["bg_void"]))))
p("NavProgress/styles/fill", SR(sb_flat("navprog_fill", C(P["amber"]))))

# ------------------------------------------------------------------ misc controls
p("HSeparator/styles/separator", SR("sep_line"))
subs.append(f'[sub_resource type="StyleBoxLine" id="sep_line"]\ncolor = {C(P["copper_dark"])}\nthickness = 2')
p("HSeparator/constants/separation", 14)
sb_flat("scroll_bg", C(P["ink"], 0.0), content=(0, 0, 0, 0))
sb_flat("scroll_grab", C(P["copper"]), INK, (1, 1, 1, 1), 4)
sb_flat("scroll_grab_hi", C(P["amber"]), INK, (1, 1, 1, 1), 4)
for sbar in ("VScrollBar", "HScrollBar"):
    p(f"{sbar}/styles/scroll", SR("scroll_bg"))
    p(f"{sbar}/styles/grabber", SR("scroll_grab"))
    p(f"{sbar}/styles/grabber_highlight", SR("scroll_grab_hi"))
    p(f"{sbar}/styles/grabber_pressed", SR("scroll_grab_hi"))
p("HSlider/styles/slider", SR(sb_flat("slider_track", C(P["panel_inset"]), INK, (2, 2, 2, 2), 6, (0, 4, 0, 4))))
p("HSlider/styles/grabber_area", SR(sb_flat("slider_fill", C(P["copper"]), INK, (2, 2, 2, 2), 6, (0, 4, 0, 4))))
p("HSlider/styles/grabber_area_highlight", SR(sb_flat("slider_fill_hi", C(P["amber"]), INK, (2, 2, 2, 2), 6, (0, 4, 0, 4))))
p("HSlider/icons/grabber", ER(tex("slider_grabber")))
p("HSlider/icons/grabber_highlight", ER(tex("slider_grabber")))
p("CheckButton/icons/checked", ER(tex("toggle_on")))
p("CheckButton/icons/unchecked", ER(tex("toggle_off")))
p("CheckBox/icons/checked", ER(tex("check_on")))
p("CheckBox/icons/unchecked", ER(tex("check_off")))
for cb in ("CheckButton", "CheckBox"):
    for st in ("normal", "hover", "pressed", "hover_pressed", "focus", "disabled"):
        p(f"{cb}/styles/{st}", SR(sb_empty(f"{cb}_{st}", (4, 4, 4, 4)) if st == "normal" else f"{cb}_normal"))
    p(f"{cb}/colors/font_color", TXT)
    p(f"{cb}/colors/font_hover_color", C(P["amber_light"]))
    p(f"{cb}/colors/font_pressed_color", TXT)
    p(f"{cb}/colors/font_outline_color", INK)
    p(f"{cb}/constants/outline_size", 5)
for st in ("normal", "hover", "pressed", "disabled"):
    p(f"OptionButton/styles/{st}", SR({"normal": "Button_normal", "hover": "Button_hover",
                                         "pressed": "Button_pressed", "disabled": "Button_disabled"}[st]))
p("OptionButton/styles/focus", SR("focus_ring"))
p("OptionButton/colors/font_color", TXT)
p("OptionButton/colors/font_outline_color", INK)
p("OptionButton/constants/outline_size", 5)
# A dropdown shows a value, not a call to action: smaller than the 22 px
# button text, so long values ("Monster Base Upgrades") fit a phone row.
p("OptionButton/fonts/font", SR("font_display"))
p("OptionButton/font_sizes/font_size", 16)
p("PopupMenu/styles/panel", SR("tooltip_sb"))
p("PopupMenu/styles/hover", SR(sb_flat("popup_hover", C(P["amber"], 0.22), C(P["amber"]), (0, 0, 0, 2), 6)))
p("PopupMenu/colors/font_color", TXT)
p("PopupMenu/colors/font_hover_color", C(P["amber_light"]))

# ------------------------------------------------------------------ screen variations
# Variations the Phase 3-5 screens (lobby, roster, character detail, skill
# tree, pre-round) need on top of the art set. The UX prototype's theme
# (ux_theme.tres) is not shipped; art names are canonical, and the UX names
# for looks the art set already has are renamed (UX -> art), never added:
#   CardPanel -> CharacterCard          CardSelected -> CharacterCardSelected
#   CardLocked -> CharacterCardLocked   PrimaryButton -> ButtonPrimary
#   MonsterButton -> ButtonMonster      MossButton -> ButtonHero
#   FilterButton -> FilterTab           LevelLabel -> CardLevel
#   PillPanel -> Pill                   HpBar -> HpBarHero
#   MonsterHpBar -> HpBarMonster        HudCard -> HudPanel
#   HudCardSelected -> HudPanelSelected TitleLabel -> HeaderLarge
#   HeaderLabel -> HeaderSmall          MutedLabel -> Caption
#   SmallLabel -> BodyDim
# test/test_theme_contract.gd keeps the UX names out of the theme.

# Skill-tree screen (gamedesign 1.8). A node is a square NodeTile (84 px, a
# capstone 92 px in a drawn stone arch): the locked look here, and
# SkillNodeButton recolours its own copy from its branch colour
# (UiPalette.branch_color) once the node is open or owned. The red "+" badge
# of a node whose next rank can be bought now, the node names under the tiles
# and the tier gutter's wood plaques ("Lv 5", padlocked while closed).
p("NodeTile/base_type", '&"PanelContainer"')
p("NodeTile/styles/panel", SR(sb_flat("node_tile_sb", C(P["locked_fill"]), C(P["locked_line"]), (4, 4, 4, 4), 14,
                                      (0, 0, 0, 0))))
p("BadgeReady/base_type", '&"PanelContainer"')
p("BadgeReady/styles/panel", SR(sb_flat("badge_ready_sb", C(P["upgrade_ready"]), INK, (3, 3, 3, 3), 12, (4, 4, 4, 4))))
for name, col in (("GutterPlaque", P["wood_dark"]), ("GutterPlaqueLocked", P["locked_fill"])):
    p(f"{name}/base_type", '&"PanelContainer"')
    p(f"{name}/styles/panel", SR(sb_flat(f"{name}_sb", C(col), INK, (3, 3, 3, 3), 8, (2, 4, 2, 4))))
label_type("NodeName", 13, TXT, 4, "font_body")
label_type("NodeNameLocked", 13, C(P["text_muted"]), 4, "font_body")
label_type("GutterCaption", 15, C(P["text_dim"]), 4, "font_body")
label_type("GutterCaptionLocked", 15, C(P["text_muted"]), 4, "font_body")
label_type("GutterNumber", 28, TXT, 6)
label_type("GutterNumberLocked", 28, C(P["text_muted"]), 6)
# The bottom sheet's "Now: ..." (white) and "Next: ..." (moss green) lines.
label_type("NowLabel", 19, TXT, 6)
label_type("NextLabel", 19, C(P["moss_light"]), 6)

# Rank pips inside a node tile (filled / empty / maxed) and the selection ring
# around the tile.
for name, col in (("PipOn", P["amber"]), ("PipOff", P["panel_inset"]), ("PipMax", P["rank_max"])):
    p(f"{name}/base_type", '&"PanelContainer"')
    p(f"{name}/styles/panel", SR(sb_flat(f"{name}_sb", C(col), INK, (2, 2, 2, 2), 7, (0, 0, 0, 0))))
p("SelectRing/base_type", '&"PanelContainer"')
p("SelectRing/styles/panel", SR(sb_flat("select_ring_sb", C(P["white"], 0), C(P["white"]), (4, 4, 4, 4), 18, (0, 0, 0, 0))))

# Branch name plaque (the tree view tints its copy in the branch colour),
# bottom sheet, chips.
p("BranchPlaque/base_type", '&"PanelContainer"')
p("BranchPlaque/styles/panel", SR(sb_flat("branch_plaque_sb", C(P["wood"]), INK, (3, 3, 3, 3), 10, (10, 4, 10, 4))))
p("SheetPanel/base_type", '&"PanelContainer"')
p("SheetPanel/styles/panel", SR(sb_flat("sheet_sb", C(P["panel_fill"]), C(P["copper"]), (4, 4, 4, 0), (22, 22, 0, 0),
                                        (22, 18, 22, 18))))
p("ChipPanel/base_type", '&"PanelContainer"')
p("ChipPanel/styles/panel", SR(sb_flat("chip_sb", C(P["bg_void"], 0.92), INK, (3, 3, 3, 3), 20, (10, 4, 14, 4))))

# The chosen side's frame on the pre-round stage: a border only.
for name, col in (("FrameHero", P["amber"]), ("FrameMonster", P["monster_light"])):
    p(f"{name}/base_type", '&"PanelContainer"')
    p(f"{name}/styles/panel", SR(sb_flat(f"{name}_sb", C(col, 0), C(col), (5, 5, 5, 5), 0, (0, 0, 0, 0))))

# Monster evolution progress (Stage I -> II -> III).
bar("EvoBar", P["amber"], P["amber_dark"])

# Detail tabs (Overview / Stats / Skill tree): a carved-wood tab, copper when on.
p("TabButton/base_type", '&"Button"')
TAB_CONTENT = (18, 8, 18, 6)
sb_flat("tab_off", C(P["wood_dark"]), INK, (4, 4, 4, 4), (16, 16, 0, 0), TAB_CONTENT)
sb_flat("tab_on", C(P["copper"]), INK, (4, 4, 4, 4), (16, 16, 0, 0), TAB_CONTENT)
for st, sid in (("normal", "tab_off"), ("hover", "tab_off"), ("disabled", "tab_off"), ("pressed", "tab_on"),
                ("hover_pressed", "tab_on"), ("focus", "empty")):
    p(f"TabButton/styles/{st}", SR(sid))
p("TabButton/font_sizes/font_size", 22)
p("TabButton/constants/outline_size", 6)
for st in ("font_color", "font_focus_color"):
    p(f"TabButton/colors/{st}", C(P["text_dim"]))
for st in ("font_hover_color", "font_pressed_color", "font_hover_pressed_color"):
    p(f"TabButton/colors/{st}", TXT)

# Text / icon-only button without a frame ("Change", "Skip", info glyphs).
p("FlatButton/base_type", '&"Button"')
for st in ("normal", "hover", "pressed", "hover_pressed", "disabled", "focus"):
    p(f"FlatButton/styles/{st}", SR("empty"))
p("FlatButton/colors/font_color", C(P["text_dim"]))
p("FlatButton/colors/font_focus_color", C(P["text_dim"]))
p("FlatButton/colors/font_hover_color", C(P["amber_light"]))
p("FlatButton/colors/font_pressed_color", C(P["amber"]))
p("FlatButton/colors/font_hover_pressed_color", C(P["amber_light"]))
p("FlatButton/colors/icon_hover_color", C(P["amber_light"]))
p("FlatButton/colors/icon_pressed_color", C(P["amber"]))

label_type("BigNumberLabel", 40, outline=11)          # cooldown seconds, reward totals
label_type("HintLabel", 16, C(P["text_muted"]), 4, "font_body")
label_type("AmberLabel", 22, C(P["amber_light"]), 6)  # live values ("50%"), "Next: ..."

# ------------------------------------------------------------------ write
if "theme" in TARGETS:
    out = [f'[gd_resource type="Theme" format=3 uid="{THEME_UID}"]', ""]
    for rid, path, typ in ext:
        out.append(f'[ext_resource type="{typ}"{import_uid(path)} path="{path}" id="{rid}"]')
    out.append("")
    for s in subs:
        out += [s, ""]
    out.append("[resource]")
    out += props
    with open(THEME_TRES, "w") as f:
        f.write("\n".join(out) + "\n")
    print("theme:", len(ext), "external resources,", len(subs), "sub-resources,", len(props), "properties")

# ------------------------------------------------------------------ UiPalette
# The runtime palette is a Resource (class_name UiPalette): ui_palette.gd
# declares one @export Color per token (default magenta, so a token without a
# value cannot hide) and palette.tres holds every value. Both come from GROUPS.
PALETTE_GD = os.path.join(THEME_DIR, "ui_palette.gd")
PALETTE_TRES = os.path.join(THEME_DIR, "palette.tres")
PALETTE_JSON = os.path.join(HERE, "palette.json")
PALETTE_UID = "uid://c0ntm7mk1813m"   # palette.tres keeps its uid across regenerations
BEGIN = "# BEGIN palette tokens: generated by tools/art/make_theme.py from tools/art/palette.py, edit there"
END = "# END palette tokens"


def f32(x):
    """Shortest decimal that reads back as the same 32-bit float: the way Godot
    writes Color components, so an editor re-save leaves palette.tres unchanged."""
    v = struct.unpack("f", struct.pack("f", x))[0]
    if v == int(v):
        return str(int(v))
    for digits in range(1, 10):
        txt = f"{v:.{digits}g}"
        if struct.unpack("f", struct.pack("f", float(txt)))[0] == v:
            return txt
    return repr(v)


def write_palette():
    with open(PALETTE_JSON, "w") as f:
        json.dump({t: [{"token": k, "hex": v, "use": n} for k, v, n in items] for t, items in GROUPS}, f, indent=1)
    block = [BEGIN]
    for title, items in GROUPS:
        block.append(f'@export_group("{title}")')
        for k, _v, note in items:
            block.append(f"@export var {k}: Color = Color.MAGENTA" + (f"  ## {note}" if note else ""))
    block.append(END)
    with open(PALETTE_GD) as f:
        src = f.read()
    a, b = src.index(BEGIN), src.index(END) + len(END)
    with open(PALETTE_GD, "w") as f:
        f.write(src[:a] + "\n".join(block) + src[b:])
    script_uid = ""
    if os.path.exists(PALETTE_GD + ".uid"):
        with open(PALETTE_GD + ".uid") as f:
            script_uid = f' uid="{f.read().strip()}"'
    res = [f'[gd_resource type="Resource" script_class="UiPalette" format=3 uid="{PALETTE_UID}"]', "",
           f'[ext_resource type="Script"{script_uid} path="res://Scenes/UI/Theme/ui_palette.gd" id="1_palette"]', "",
           "[resource]", 'script = ExtResource("1_palette")']
    for _title, items in GROUPS:
        for k, v, _note in items:
            res.append(f"{k} = Color({', '.join(f32(c) for c in hexrgb(v))}, 1)")
    with open(PALETTE_TRES, "w") as f:
        f.write("\n".join(res) + "\n")
    print("palette:", sum(len(items) for _, items in GROUPS), "tokens in", len(GROUPS), "groups")


if "palette" in TARGETS:
    write_palette()

# ------------------------------------------------------------------ shaders


def vec4(h, a):
    r, gg, b = hexrgb(h)
    return f"vec4({r:.3f}, {gg:.3f}, {b:.3f}, {a})"


def write_shaders():
    os.makedirs(os.path.join(UI, "Shaders"), exist_ok=True)
    with open(os.path.join(UI, "Shaders", "ability_cooldown.gdshader"), "w") as f:
        f.write(f"""shader_type canvas_item;
// Ability icon cooldown (HUD + skill previews). Put on the icon TextureRect.
// progress: 0 = just cast, 1 = ready. The not-yet-recovered sector (clockwise
// from 12 o'clock, shrinking) is desaturated and veiled; an amber edge marks
// the sweep. ready_flash (0..1, tweened 1 -> 0 on ready) whitens the icon.
// locked = 1 greys the whole icon (Ground Slam before Stage 2).
uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform float ready_flash : hint_range(0.0, 1.0) = 0.0;
uniform float locked : hint_range(0.0, 1.0) = 0.0;
uniform vec4 veil_color : source_color = {vec4(P["cooldown_veil"], 0.70)};
uniform vec4 edge_color : source_color = {vec4(P["amber"], 1.0)};
uniform float edge_width : hint_range(0.0, 0.2) = 0.035;

void fragment() {{
	vec4 c = COLOR;   // texture * modulate (Godot 4 canvas_item input)
	vec2 d = UV - vec2(0.5);
	float a = fract(atan(d.x, -d.y) / TAU + 1.0);   // 0 at 12 o'clock, clockwise
	float cooling = step(progress, a) * step(progress, 0.999);
	float grey = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 dim = mix(vec3(grey), veil_color.rgb, veil_color.a);
	float edge = cooling * (1.0 - step(edge_width, a - progress)) * step(0.18, length(d));
	vec3 rgb = mix(c.rgb, dim, max(cooling, locked * 0.8));
	rgb = mix(rgb, edge_color.rgb, edge);
	rgb = mix(rgb, vec3(1.0), ready_flash * 0.7);
	COLOR = vec4(rgb, c.a);
}}
""")

    with open(os.path.join(UI, "Shaders", "card_locked.gdshader"), "w") as f:
        f.write(f"""shader_type canvas_item;
// Locked character silhouette: every opaque pixel becomes the locked fill,
// bright source pixels keep a faint rim so the shape still reads.
uniform vec4 fill : source_color = {vec4(P["locked_fill"], 1.0)};
uniform vec4 rim : source_color = {vec4(P["locked_line"], 1.0)};

void fragment() {{
	vec4 c = COLOR;   // texture * modulate
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(fill.rgb, rim.rgb, smoothstep(0.35, 0.9, lum) * 0.55), c.a);
}}
""")
    print("shaders: ability_cooldown, card_locked")


if "shaders" in TARGETS:
    write_shaders()
