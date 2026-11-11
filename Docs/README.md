# Better Hunt - Docs

The design spec is the root [`README.md`](../README.md). This folder used to
hold a copy of it from the v0.1 prototype; that copy went stale and was
replaced by this page so there is one spec only. (The old text is in the git
history of this file.)

## Where to read what

| You want | Read |
|---|---|
| What the game is, every number, every screen, every tool | [`../README.md`](../README.md) |
| How the code is built, the house rules, checklists for new content | [`INSTRUCTOR.md`](INSTRUCTOR.md) |
| What is done, what is next, open decisions, the changelog with numbers | [`../PROGRESS.md`](../PROGRESS.md) |

## Getting started

- **Engine**: Godot 4.7 (the tools default to `/Applications/Godot.app`; set
  `GODOT=/path/to/godot` to override).
- **Run the game**: open the project in the editor and press Play. The main
  scene is `Scenes/UI/Screens/MenuRoot.tscn` (the lobby); a match is
  `Scenes/World/World.tscn`.
- **Check a change** (each tool works on a temp copy, never on the project
  directory or the real save):

```bash
tools/lint.sh                 # every script, scene and resource loads; wiring; UI colours
tools/run_tests.sh            # the headless suite
tools/sim_trace.sh > t.txt    # determinism trace (BASELINE=<file> to compare)
MONSTER=all tools/sim.sh 48 heroes 6     # balance per monster
tools/bench.sh 5 2 900 300    # performance in the stress config
```

- **Regenerate generated files** (never edit them by hand):
  `python3 tools/art/build.py` (UI kit and icons),
  `python3 tools/art/make_theme.py palette theme shaders`,
  `tools/build_rigs.sh`, `tools/build_skill_trees.sh`, `tools/bake_nav.sh`.
- **In a match**: tap a hero or press 1-4 / Tab to follow it, pinch (or a trackpad magnify gesture)
  to zoom, F3 for the debug overlay (debug builds).

---

**[← Back to Project Root](../README.md)**
