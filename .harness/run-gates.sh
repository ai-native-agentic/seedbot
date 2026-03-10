#!/usr/bin/env bash
# .harness/run-gates.sh — Run all enabled QA gates for seedbot
#
# Minimal harness for Bash project. Only Gate A (syntax check) is enabled.
# All other gates are disabled since seedbot is a simple <100 LOC script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

run_gate() {
    local name="$1"
    local label="$2"
    local cmd="$3"
    printf "  %-18s ... " "$label"
    if (cd "$PROJECT_ROOT" && eval "$cmd") 2>&1; then
        printf "${GREEN}PASS${NC}\n"
        PASS=$((PASS + 1))
    else
        printf "${RED}FAIL${NC}\n"
        FAIL=$((FAIL + 1))
    fi
}

echo ""
echo "=== seedbot QA Gates ==="
echo ""

# Gate A: Bash syntax check
if command -v shellcheck &>/dev/null; then
    run_gate "gate_a" "shellcheck"     "shellcheck main.sh"
else
    # Fallback: bash -n syntax check
    run_gate "gate_a" "bash -n syntax" "bash -n main.sh"
fi

echo ""
echo "=== Results ==="
echo -e "  ${GREEN}PASS: $PASS${NC}  ${RED}FAIL: $FAIL${NC}"
echo ""

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
