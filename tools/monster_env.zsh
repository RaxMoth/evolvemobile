# Sourced by tools/sim.sh, tools/sim_trace.sh and tools/bench.sh: turns the
# MONSTER environment variable into the MONSTERS array the tool loops over.
#
#   MONSTER unset  -> MONSTERS=("")   no monster= argument: the roster default
#                                     plays, so old command lines replay the same matches
#   MONSTER=<id>   -> MONSTERS=(<id>) checked against the roster
#   MONSTER=all    -> every roster monster id, in roster order
#
# resolve_monsters <copy> runs tools/list_monsters.gd on <copy>, an imported
# temp copy with its own user:// (override.cfg), only when MONSTER is set
# (through run_godot, tools/tool_env.zsh: source that first; the log goes to
# $TMP).
# An id the roster lacks fails (return 1) instead of quietly playing the
# default monster, which GameManager.select_monster would fall back to.
resolve_monsters() {
  MONSTERS=("")
  [ -z "$MONSTER" ] && return 0
  run_godot "$TMP/list_monsters.log" --headless --path "$1" -s res://tools/list_monsters.gd
  local ids=(${=$(sed -n 's/^MONSTER_IDS //p' "$TMP/list_monsters.log")})
  if [ "$MONSTER" = all ]; then
    MONSTERS=($ids)
  elif (( ${ids[(Ie)$MONSTER]} )); then
    MONSTERS=("$MONSTER")
  else
    MONSTERS=()
  fi
  if (( ${#MONSTERS} == 0 )); then
    echo "MONSTER=$MONSTER: not a roster monster (roster: ${ids:-none listed}; or all)" >&2
    return 1
  fi
}
