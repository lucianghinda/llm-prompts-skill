#!/usr/bin/env bash
# test-claude.sh — Run prompt-injection-review skill via Claude CLI against test fixtures
# Usage: ./tests/test-claude.sh [fixture_name]
#   fixture_name: "vulnerable-app" | "defended-app" | all (default: all)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_FILE="$PROJECT_DIR/skill/SKILL.md"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
OUTPUT_DIR="$SCRIPT_DIR/output"
EXPECTED_DIR="$SCRIPT_DIR/expected"

FIXTURE_TARGET="${1:-all}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# ── Colours ─────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

mkdir -p "$OUTPUT_DIR"

# ── Prerequisites ────────────────────────────────────────────────────────────
if ! command -v claude &>/dev/null; then
  echo -e "${RED}ERROR: 'claude' CLI not found in PATH${RESET}" >&2
  exit 1
fi

if [[ ! -f "$SKILL_FILE" ]]; then
  echo -e "${RED}ERROR: Skill file not found at $SKILL_FILE${RESET}" >&2
  exit 1
fi

SKILL_CONTENT="$(cat "$SKILL_FILE")"

# ── Run one fixture ──────────────────────────────────────────────────────────
run_fixture() {
  local fixture="$1"
  local fixture_dir="$FIXTURES_DIR/$fixture"
  local expected_file="$EXPECTED_DIR/${fixture}.expected"
  local output_file="$OUTPUT_DIR/claude-${fixture}-${TIMESTAMP}.txt"

  echo -e "\n${CYAN}▶ Running Claude review: $fixture${RESET}"

  if [[ ! -d "$fixture_dir" ]]; then
    echo -e "${RED}  ERROR: Fixture directory not found: $fixture_dir${RESET}"
    return 1
  fi
  if [[ ! -f "$expected_file" ]]; then
    echo -e "${RED}  ERROR: Expected file not found: $expected_file${RESET}"
    return 1
  fi

  # Run claude in print mode (-p) with the skill as system prompt
  # --dangerously-skip-permissions: needed for non-interactive file access
  # --tools: only read-only tools needed for the review
  echo "  Invoking claude CLI... (this may take 60-120 seconds)"
  claude -p \
    --system-prompt "$SKILL_CONTENT" \
    --dangerously-skip-permissions \
    --tools "Read,Grep,Glob,Bash" \
    --add-dir "$fixture_dir" \
    --output-format text \
    "You are running a prompt injection security review.
Review scope: codebase (the entire directory you have access to).
Do NOT use AskUserQuestion — skip all STOP gates and produce the full report directly.
Work through all 5 phases (Discovery, OWASP, MITRE, NeMo, Report) and output the
complete findings with PASS/FAIL/N-A for every check ID (O-1 through O-23, M-1 through M-12, N-1 through N-16)." \
    > "$output_file" 2>&1

  echo "  Output saved to: $output_file"

  # Validate the output
  validate_output "$fixture" "$output_file" "$expected_file"
}

# ── Validate output against expected file ────────────────────────────────────
validate_output() {
  local fixture="$1"
  local output_file="$2"
  local expected_file="$3"
  local fixture_pass=0
  local fixture_fail=0
  local fixture_warn=0

  echo -e "\n  ${CYAN}Validating against expected findings...${RESET}"

  # Parse expected file: skip comments and empty lines
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$line" ]] && continue

    # Parse: CHECK_ID SEVERITY VERDICT [# comment]
    check_id=$(echo "$line" | awk '{print $1}')
    severity=$(echo "$line" | awk '{print $2}')
    expected_verdict=$(echo "$line" | awk '{print $3}')

    [[ -z "$check_id" || -z "$severity" || -z "$expected_verdict" ]] && continue

    # Search the output for this check ID with its expected verdict
    # Looks for patterns like: [O-1] ... FAIL  or  O-1 ... FAIL
    if grep -qiE "\[?${check_id}\]?[[:space:][:punct:]]*[A-Za-z ]*${expected_verdict}" "$output_file"; then
      if [[ "$severity" == "CRITICAL" || "$severity" == "HIGH" ]]; then
        echo -e "    ${GREEN}✓ PASS${RESET}  ${check_id} (${severity}): found expected ${expected_verdict}"
        ((fixture_pass++))
      else
        echo -e "    ${GREEN}✓ PASS${RESET}  ${check_id} (${severity}): found expected ${expected_verdict}"
        ((fixture_pass++))
      fi
    else
      if [[ "$severity" == "CRITICAL" || "$severity" == "HIGH" ]]; then
        echo -e "    ${RED}✗ FAIL${RESET}  ${check_id} (${severity}): expected ${expected_verdict} — not found in output"
        ((fixture_fail++))
        ((FAIL_COUNT++))
      else
        echo -e "    ${YELLOW}⚠ WARN${RESET}  ${check_id} (${severity}): expected ${expected_verdict} — not found (non-critical)"
        ((fixture_warn++))
        ((WARN_COUNT++))
      fi
    fi
  done < "$expected_file"

  PASS_COUNT=$((PASS_COUNT + fixture_pass))

  echo ""
  if [[ "$fixture_fail" -eq 0 ]]; then
    echo -e "  ${GREEN}RESULT: PASS${RESET} — $fixture_pass critical/high checks confirmed, $fixture_warn warnings"
  else
    echo -e "  ${RED}RESULT: FAIL${RESET} — $fixture_fail critical/high checks MISSING, $fixture_pass passed, $fixture_warn warnings"
  fi
}

# ── Main ─────────────────────────────────────────────────────────────────────
echo -e "${CYAN}═══════════════════════════════════════════════════════${RESET}"
echo -e "${CYAN}  Claude CLI — Prompt Injection Review Tests${RESET}"
echo -e "${CYAN}  Skill: $SKILL_FILE${RESET}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${RESET}"

if [[ "$FIXTURE_TARGET" == "all" ]]; then
  run_fixture "vulnerable-app"
  run_fixture "defended-app"
else
  run_fixture "$FIXTURE_TARGET"
fi

echo -e "\n${CYAN}═══════════════════════════════════════════════════════${RESET}"
echo -e "${CYAN}  SUMMARY (Claude)${RESET}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${RESET}"
echo -e "  ${GREEN}PASSED:${RESET}   $PASS_COUNT critical/high checks"
echo -e "  ${RED}FAILED:${RESET}   $FAIL_COUNT critical/high checks"
echo -e "  ${YELLOW}WARNINGS:${RESET} $WARN_COUNT medium/low checks"
echo ""

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo -e "${RED}OVERALL: FAIL — $FAIL_COUNT critical/high expected findings were not detected${RESET}"
  exit 1
else
  echo -e "${GREEN}OVERALL: PASS${RESET}"
  exit 0
fi
