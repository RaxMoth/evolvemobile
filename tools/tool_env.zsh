# Sourced first by every tools/*.sh that runs Godot: the binary, the temp copy
# and one clean-up for every way a tool can end.
#
#   GODOT                    the binary (default: the macOS app); one that is
#                            not there exits 2 here, before any work
#   tool_tmp                 TMP = a new temp dir, deleted at the end
#   tool_clean <path>...     delete these at the end too (the copies' user:// dirs)
#   run_godot <log> <args>   "$GODOT" <args> > <log> 2>&1; returns Godot's exit code,
#                            or 124 when the run outlived TOOL_TIME_LIMIT_S
#   ( tool_worker; ... ) &   a worker subshell that runs Godot with run_godot;
#                            the tool then adds it: TOOL_PIDS+=($!)
#   tool_time_limit <s>      this tool's default limit of one Godot run
#   rc_note <exit code>      "" for 0, else ", Godot exit <n>" / ", timed out ..."
#
# TOOL_TIME_LIMIT_S (seconds, 0 = none; default 1800, a tool may raise its own
# default with tool_time_limit, the environment wins) bounds every Godot run
# on the wall clock: a GDScript loop that never ends holds the main thread, so
# no frame-driven cap (a match's time cap) can end it. A watchdog stops the
# run (TERM, KILL 5 s later), stderr gets "TIMEOUT: ..." and run_godot returns
# 124. The default is far above the longest normal run (a full match takes
# 15-60 s, the lint a few minutes).
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
TOOL_TIME_LIMIT_ENV="${TOOL_TIME_LIMIT_S-}"
TOOL_TIME_LIMIT_S="${TOOL_TIME_LIMIT_S:-1800}"
if [[ ! "$TOOL_TIME_LIMIT_S" =~ '^[0-9]+$' ]]; then
  echo "TOOL_TIME_LIMIT_S=$TOOL_TIME_LIMIT_S: the seconds one Godot run may take (0 = no limit)" >&2
  exit 2
fi

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

tool_time_limit() {
  if [ -z "$TOOL_TIME_LIMIT_ENV" ]; then TOOL_TIME_LIMIT_S=$1; fi
}

run_godot() {
  local log="$1"
  shift
  rm -f "$log.timeout"
  "$GODOT" "$@" > "$log" 2>&1 &
  local pid=$! watch=0 rc=0
  TOOL_PIDS+=($pid)
  if (( TOOL_TIME_LIMIT_S > 0 )); then
    tool_watch $pid "$log" &
    watch=$!
    TOOL_PIDS+=($watch)
  fi
  wait $pid || rc=$?
  if (( watch )); then
    kill $watch 2> /dev/null
    wait $watch 2> /dev/null
    TOOL_PIDS=(${TOOL_PIDS:#$watch})
  fi
  TOOL_PIDS=(${TOOL_PIDS:#$pid})
  if [ -e "$log.timeout" ]; then
    echo "TIMEOUT: Godot still ran after $TOOL_TIME_LIMIT_S s (TOOL_TIME_LIMIT_S) and was stopped: ${log:t}" >&2
    return 124
  fi
  return $rc
}

# The watchdog of one run (a subshell): once TOOL_TIME_LIMIT_S has passed it
# marks <log>.timeout and stops Godot, TERM first, KILL 5 s later. run_godot
# stops it (TERM) as soon as Godot ends; it then stops its own sleep, so no
# process outlives the run.
tool_watch() {
  local pid=$1 log="$2" nap=""
  trap '[ -n "$nap" ] && kill $nap 2> /dev/null; exit 0' TERM
  sleep $TOOL_TIME_LIMIT_S &
  nap=$!
  wait $nap
  : > "$log.timeout"
  kill $pid 2> /dev/null
  sleep 5 &
  nap=$!
  wait $nap
  kill -KILL $pid 2> /dev/null
}

rc_note() {
  case "$1" in
    0) ;;
    124) print -rn -- ", timed out after $TOOL_TIME_LIMIT_S s" ;;
    "") print -rn -- ", no exit code" ;;
    *) print -rn -- ", Godot exit $1" ;;
  esac
}

# A worker owns only its own Godot: the tool's EXIT trap stops the worker
# (TERM), the worker stops its Godot and ends.
tool_worker() {
  TOOL_PIDS=()
  TOOL_CLEAN=()
  trap 'kill $TOOL_PIDS 2> /dev/null; exit 143' TERM
}
