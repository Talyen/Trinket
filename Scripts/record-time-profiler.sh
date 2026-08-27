#!/usr/bin/env bash
# Host Time Profiler capture for Simulator investigation.
#
# Never pass --device: Xcode 26.4–27.0 deadlocks the in-sim DTServiceHub
# handshake and ignores --time-limit, so record never ends.
#
# Default is --attach Trinket on the host. Simulator apps are ordinary host
# processes, so this samples one PID. --all-processes is opt-in because it
# kperf-samples the whole Mac and then symbolicates every process into a
# deferred .trace (a 5s capture was ~36 MiB and tens of seconds to save).
#
# Completion is event-driven: wait for xctrace to report that recording
# ended, then wait for the process to exit after save. SIGINT only if
# --time-limit is ignored (the known deadlock). There is no save-time guess.
set -euo pipefail

cd "$(dirname "$0")/.."

TIME_LIMIT="8s"
OUTPUT=""
PRINT_COMMAND=0
ATTACH="Trinket"
ALL_PROCESSES=0
# Slack after --time-limit for xctrace to print "ending recording".
# This detects an ignored time-limit; it is not a serialize budget.
RECORDING_END_SLACK_SECONDS=5

usage() {
  echo "Usage: $0 --output <path.trace> [--time-limit 8s] [--attach Trinket]" >&2
  echo "       $0 --output <path.trace> [--time-limit 8s] --all-processes" >&2
  echo "       $0 --print-command [same flags]" >&2
}

parse_seconds() {
  local raw="$1"
  if [[ "$raw" =~ ^([1-9][0-9]*)s$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  elif [[ "$raw" =~ ^([1-9][0-9]*)m$ ]]; then
    printf '%s\n' "$((BASH_REMATCH[1] * 60))"
  else
    echo "record-time-profiler: --time-limit must be like 8s or 1m (got: $raw)" >&2
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      OUTPUT="${2:-}"
      shift 2
      ;;
    --time-limit)
      TIME_LIMIT="${2:-}"
      shift 2
      ;;
    --attach)
      ATTACH="${2:-}"
      shift 2
      ;;
    --all-processes)
      ALL_PROCESSES=1
      shift
      ;;
    --print-command)
      PRINT_COMMAND=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "record-time-profiler: unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

parse_seconds "$TIME_LIMIT" >/dev/null

if [[ "$ALL_PROCESSES" -eq 1 && -n "$ATTACH" && "$ATTACH" != "Trinket" ]]; then
  echo "record-time-profiler: --all-processes cannot be combined with --attach" >&2
  exit 1
fi

cmd=(
  xcrun xctrace record
  --instrument "Time Profiler"
  --time-limit "$TIME_LIMIT"
  --no-prompt
)
if [[ "$ALL_PROCESSES" -eq 1 ]]; then
  cmd+=(--all-processes)
else
  cmd+=(--attach "$ATTACH")
fi
if [[ -n "$OUTPUT" ]]; then
  cmd+=(--output "$OUTPUT")
fi

if [[ "$PRINT_COMMAND" -eq 1 ]]; then
  printf '%s ' "${cmd[@]}"
  printf '\n'
  exit 0
fi

if [[ -z "$OUTPUT" ]]; then
  echo "record-time-profiler: --output is required" >&2
  usage
  exit 1
fi

if [[ "$ALL_PROCESSES" -eq 1 ]]; then
  echo "record-time-profiler: --all-processes samples the whole Mac; save is large and slow. Prefer --attach." >&2
fi

mkdir -p "$(dirname "$OUTPUT")"
log="$(mktemp)"
tail_pid=""
cleanup() {
  if [[ -n "$tail_pid" ]]; then
    kill "$tail_pid" 2>/dev/null || true
  fi
  rm -f "$log"
}
trap cleanup EXIT

: >"$log"
"${cmd[@]}" >>"$log" 2>&1 &
pid=$!
tail -n +1 -f "$log" &
tail_pid=$!

limit_seconds="$(parse_seconds "$TIME_LIMIT")"
recording_deadline=$((limit_seconds + RECORDING_END_SLACK_SECONDS))
SECONDS=0
recording_ended=0
while kill -0 "$pid" 2>/dev/null; do
  if grep -Eq 'Reached specified time limit|ending recording' "$log"; then
    recording_ended=1
    break
  fi
  if (( SECONDS >= recording_deadline )); then
    echo "record-time-profiler: xctrace ignored --time-limit (DTServiceHub-style hang). Do not pass --device." >&2
    kill -INT "$pid" 2>/dev/null || true
    wait "$pid" || true
    exit 1
  fi
  sleep 0.2
done

# Recording acknowledged its time limit (or the process already exited).
# Wait for serialize with no guessed budget — that duration is load-dependent.
wait "$pid"
status=$?
if [[ "$status" -ne 0 && "$recording_ended" -ne 1 ]]; then
  exit "$status"
fi
if [[ ! -d "$OUTPUT" ]]; then
  echo "record-time-profiler: xctrace exited without writing $OUTPUT" >&2
  exit 1
fi
echo "Time Profiler trace: $OUTPUT"
