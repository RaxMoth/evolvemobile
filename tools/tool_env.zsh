# Sourced first by every tools/*.sh that runs Godot: the binary, the temp copy
# and one clean-up for every way a tool can end.
#
#   GODOT                    the binary (default: the macOS app); one that is
#                            not there exits 2 here, before any work
#   tool_tmp                 TMP = a new temp dir, deleted at the end
#   tool_clean <path>...     delete these at the end too (the copies' user:// dirs)
#   run_godot <log> <args>   "$GODOT" <args> > <log> 2>&1; returns Godot's exit code
#   ( tool_worker; ... ) &   a worker subshell that runs Godot with run_godot;
#                            the tool then adds it: TOOL_PIDS+=($!)
#
# A kill must not leak the copies, their user:// dirs or running matches. zsh
# skips the EXIT trap when TERM ends a script, and holds every trap until a
# foreground child returns. So TERM, INT and HUP become a normal exit (143,
# 130, 129), run_godot starts Godot in the background and waits for it (a
# wait returns at once on a signal), and the EXIT trap stops every Godot and
# worker still running before it deletes what tool_tmp and tool_clean
# registered. A worker stops its own Godot when the tool stops it. SIGKILL
# cannot be caught.

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
if ! command -v "$GODOT" > /dev/null; then
  echo "GODOT=$GODOT: no such program (set GODOT=/path/to/godot)" >&2
  exit 2
fi
TOOL_PIDS=()
TOOL_CLEAN=()

tool_cleanup() {
  local pid
  for pid in $TOOL_PIDS; do kill $pid 2> /dev/null || true; done
  for pid in $TOOL_PIDS; do wait $pid 2> /dev/null || true; done
  if (( ${#TOOL_CLEAN} )); then rm -rf -- "${TOOL_CLEAN[@]}"; fi
}
trap tool_cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

tool_tmp() {
  TMP="$(mktemp -d)"
  TOOL_CLEAN+=("$TMP")
}

tool_clean() {
  TOOL_CLEAN+=("$@")
}

run_godot() {
  local log="$1"
  shift
  "$GODOT" "$@" > "$log" 2>&1 &
  local pid=$!
  TOOL_PIDS+=($pid)
  local rc=0
  wait $pid || rc=$?
  TOOL_PIDS=(${TOOL_PIDS:#$pid})
  return $rc
}

# A worker owns only its own Godot: the tool's EXIT trap stops the worker
# (TERM), the worker stops its Godot and ends.
tool_worker() {
  TOOL_PIDS=()
  TOOL_CLEAN=()
  trap 'kill $TOOL_PIDS 2> /dev/null; exit 143' TERM
}
