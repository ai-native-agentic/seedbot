#!/usr/bin/env bash
set -euo pipefail

VERBOSE=0
for arg in "$@"; do
  case "$arg" in
    --verbose|-v) VERBOSE=1 ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ERROR_LOG="$ROOT_DIR/logs/errors.log"
LOCK_DIR="$ROOT_DIR/memory/.lock"

mkdir -p "$ROOT_DIR/memory" "$ROOT_DIR/inputs.d" "$ROOT_DIR/functions" "$ROOT_DIR/workspace" "$ROOT_DIR/logs"

# Error handler for untrapped errors
error_handler() {
  local line_no="$1"
  local error_code="$2"
  local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  printf '[%s] Error on line %d: exit code %d\n' "$timestamp" "$line_no" "$error_code" >> "$ERROR_LOG"
  printf 'assistant> Error occurred at line %d (code %d). Check %s for details.\n' "$line_no" "$error_code" "$ERROR_LOG" >&2
}

trap 'error_handler ${LINENO} $?' ERR

# Cleanup trap for exit
exit_trap() {
  local exit_code=$?
  if (( exit_code != 0 )); then
    printf '[%s] Exiting with code %d\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$exit_code" >> "$ERROR_LOG"
  fi
  cleanup
  exit "$exit_code"
}
trap exit_trap EXIT

_lock()   { while ! mkdir "$LOCK_DIR" 2>/dev/null; do sleep 0.1; done; }
_unlock() { rmdir "$LOCK_DIR" 2>/dev/null; true; }

run_with_timeout() { # $1=timeout_secs, rest=command...
  local timeout_secs="$1" cmd="$2" rc
  shift 2
  local label="$(basename "$cmd")${*:+ $*}"
  if ! timeout --signal=TERM --kill-after=5 "${timeout_secs}s" "$cmd" "$@"; then
    rc=$?
    case "$rc" in
      124|143)
        printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$label timed out after ${timeout_secs}s" >> "$ERROR_LOG"
        return 124
        ;;
      *)
        printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$label failed with code $rc" >> "$ERROR_LOG"
        return "$rc"
        ;;
    esac
  fi
  return 0
}

load_memory() { # $1=source_name, $2=message
  if [[ -x "$ROOT_DIR/memory/load.sh" ]]; then
    run_with_timeout 10 "$ROOT_DIR/memory/load.sh" "$1" "$2" || {
      [[ -f "$ROOT_DIR/memory/context.md" ]] && tail -n 500 "$ROOT_DIR/memory/context.md"
    }
  elif [[ -f "$ROOT_DIR/memory/context.md" ]]; then
    tail -n 500 "$ROOT_DIR/memory/context.md"
  fi
}

process_response() { # $1=source_name, $2=user_query, $3=codex_response
  _lock
  printf 'Response to request "%s" from [%s]:\n %s\n' "$2" "$1" "$3" >> "$ROOT_DIR/memory/context.md"
  if [[ -x "$ROOT_DIR/memory/save.sh" ]]; then
    run_with_timeout 300 "$ROOT_DIR/memory/save.sh" "$1" "$2" "$3" 2>>"$ERROR_LOG"
  fi
  _unlock
}

run_codex() { # $1=user_message, $2=memory_text
  local agent_file="$ROOT_DIR/workspace/agent_$BASHPID.md"
  local rc=0
  printf '# Agent %s\n- request: %s\n' "$1" > "$agent_file" || {
    printf '[%s] Failed to create agent file\n' "$(date '+%Y-%m-%d %H:%M:%S')" >> "$ERROR_LOG"
    return 1
  }

  local payload="SYSTEM_PROMPT:\n$(cat "$ROOT_DIR/system.md")\n\nMEMORY_CONTEXT:\n$2\n\nAGENT_FILE:\n$agent_file\n\nUSER_INSTRUCTION:\n$1\n"
  if (( VERBOSE )); then
    printf '%b\n' "$payload" | codex exec --sandbox danger-full-access --yolo --skip-git-repo-check - 2> >(tee -a "$ERROR_LOG" >&2) || rc=$?
  else
    printf '%b\n' "$payload" | codex exec --sandbox danger-full-access --yolo --skip-git-repo-check - 2>>"$ERROR_LOG" || rc=$?
  fi

  if (( rc != 0 )); then
    printf '[%s] codex failed with exit code %d\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$rc" >> "$ERROR_LOG"
    printf 'assistant> Error: codex failed (exit %d), check %s\n' "$rc" "$ERROR_LOG"
  fi

  rm -f "$agent_file" || true
  return "$rc"
}

handle_message() { # $1=source_name, $2=message
  local memory_text response rc=0
  memory_text="$(load_memory "$1" "$2" || true)"
  printf 'Received message from [%s]: %s\n' "$1" "$2" >> "$ROOT_DIR/memory/context.md"
  printf '\nassistant> Receive message from [%s], processing...\n' "$1"
  response="$(run_codex "$2" "$memory_text")" || rc=$?
  printf '%s\n' "$response"
  printf '================end of response=================\n'
  process_response "$1" "$2" "$response" || {
    printf '[%s] Failed to process response from [%s]\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$ERROR_LOG"
  }
  return "$rc"
}

cleanup() {
  rmdir "$LOCK_DIR" 2>/dev/null || true
  rm -f "$ROOT_DIR"/workspace/agent_*.md 2>/dev/null || true
  kill 0 2>/dev/null || true
  wait 2>/dev/null || true
}

# Signal handlers
handle_int() {
  printf '\nassistant> Interrupted (Ctrl+C). Cleaning up...\n'
  exit 130
}

handle_term() {
  printf '\nassistant> Received TERM signal. Cleaning up...\n'
  exit 143
}

trap handle_int INT
trap handle_term TERM

printf 'assistant> type a message, or Ctrl-C to quit.\n'

while true; do
  for plugin in "$ROOT_DIR/inputs.d"/*; do
    [[ -f "$plugin" && -x "$plugin" ]] || continue
    msg="$(run_with_timeout 30 "$plugin" 2>>"$ERROR_LOG")" || continue
    [[ -z "$msg" ]] && continue
    handle_message "$(basename "$plugin")" "$msg" &
  done

  if IFS= read -r -t 1 line && [[ -n "$line" ]]; then
    handle_message "terminal" "$line" &
  fi
done
