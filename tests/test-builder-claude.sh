#!/usr/bin/env bash
# test-builder-claude.sh — Run prompt-builder skill via Claude CLI against scenario fixtures
# Usage: ./tests/test-builder-claude.sh [scenario_name]
#   scenario_name: "basic-chatbot" | "rag-assistant" | "tool-calling-agent" | all (default: all)
#
# Expected file format supports two line types (lines starting with # are comments):
#   CHECK_ID  SEVERITY  VERDICT
#     → grepped as: \[?CHECK_ID\]?.*VERDICT  (matches self-review section output)
#   @PATTERN|SEVERITY|PRESENT
#     → grepped as: literal PATTERN anywhere in output (case-insensitive, supports regex)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_FILE="$PROJECT_DIR/prompt-builder/SKILL.md"
SCENARIOS_DIR="$SCRIPT_DIR/fixtures/builder-scenarios"
OUTPUT_DIR="$SCRIPT_DIR/output"
EXPECTED_DIR="$SCRIPT_DIR/expected"

SCENARIO_TARGET="${1:-all}"
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

# ── Run one scenario ──────────────────────────────────────────────────────────
run_scenario() {
  local scenario="$1"
  local scenario_file="$SCENARIOS_DIR/${scenario}.txt"
  local expected_file="$EXPECTED_DIR/builder-${scenario}.expected"
  local output_file="$OUTPUT_DIR/builder-claude-${scenario}-${TIMESTAMP}.txt"

  echo -e "\n${CYAN}▶ Running builder scenario: $scenario${RESET}"

  if [[ ! -f "$scenario_file" ]]; then
    echo -e "${RED}  ERROR: Scenario file not found: $scenario_file${RESET}"
    return 1
  fi
  if [[ ! -f "$expected_file" ]]; then
    echo -e "${RED}  ERROR: Expected file not found: $expected_file${RESET}"
    return 1
  fi

  SCENARIO_PROMPT="$(cat "$scenario_file")"

  # Run the builder skill via claude in print mode (-p).
  # --tools: Read-only tools only — the builder generates inline code in the test, no file writes.
  # AskUserQuestion is excluded: scenario files already instruct Claude to skip STOP gates.
  echo "  Invoking claude CLI... (this may take 60-120 seconds)"
  claude -p \
    --system-prompt "$SKILL_CONTENT" \
    --dangerously-skip-permissions \
    --tools "Read,Grep,Glob" \
    --output-format text \
    "$SCENARIO_PROMPT" \
    > "$output_file" 2>&1

  echo "  Output saved to: $output_file"

  # Validate the output
  validate_output "$scenario" "$output_file" "$expected_file"
}

# ── Validate output against expected file ────────────────────────────────────
validate_output() {
  local scenario="$1"
  local output_file="$2"
  local expected_file="$3"
  local fixture_pass=0
  local fixture_fail=0
  local fixture_warn=0

  echo -e "\n  ${CYAN}Validating against expected markers...${RESET}"

  while IFS= read -r line; do
    # Skip comments and blank lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$line" ]] && continue

    if [[ "$line" =~ ^\@ ]]; then
      # ── Structural marker: @PATTERN|SEVERITY|PRESENT ──────────────────────
      # Pipe-separated to support multi-word patterns
      IFS='|' read -r raw_pattern severity presence <<< "$line"
      search_term="${raw_pattern:1}"  # strip leading @

      if grep -qiE "$search_term" "$output_file"; then
        echo -e "    ${GREEN}✓ PASS${RESET}  [$severity] pattern present: $search_term"
        ((fixture_pass++))
      else
        if [[ "$severity" == "CRITICAL" || "$severity" == "HIGH" ]]; then
          echo -e "    ${RED}✗ FAIL${RESET}  [$severity] pattern missing: $search_term"
          ((fixture_fail++))
          ((FAIL_COUNT++))
        else
          echo -e "    ${YELLOW}⚠ WARN${RESET}  [$severity] pattern missing (non-critical): $search_term"
          ((fixture_warn++))
          ((WARN_COUNT++))
        fi
      fi

    else
      # ── Self-review check: CHECK_ID  SEVERITY  VERDICT ───────────────────
      check_id=$(echo "$line" | awk '{print $1}')
      severity=$(echo "$line" | awk '{print $2}')
      expected_verdict=$(echo "$line" | awk '{print $3}')

      [[ -z "$check_id" || -z "$severity" || -z "$expected_verdict" ]] && continue

      # Matches: [O-7] ... PASS  or  O-7 ... PASS  (builder self-review format)
      if grep -qiE "\[?${check_id}\]?.*[[:space:]]${expected_verdict}([[:space:]]|[[:punct:]]|$)" "$output_file"; then
        echo -e "    ${GREEN}✓ PASS${RESET}  ${check_id} (${severity}): self-review shows ${expected_verdict}"
        ((fixture_pass++))
      else
        if [[ "$severity" == "CRITICAL" || "$severity" == "HIGH" ]]; then
          echo -e "    ${RED}✗ FAIL${RESET}  ${check_id} (${severity}): expected ${expected_verdict} in self-review — not found"
          ((fixture_fail++))
          ((FAIL_COUNT++))
        else
          echo -e "    ${YELLOW}⚠ WARN${RESET}  ${check_id} (${severity}): expected ${expected_verdict} — not found (non-critical)"
          ((fixture_warn++))
          ((WARN_COUNT++))
        fi
      fi
    fi

  done < "$expected_file"

  PASS_COUNT=$((PASS_COUNT + fixture_pass))

  echo ""
  if [[ "$fixture_fail" -eq 0 ]]; then
    echo -e "  ${GREEN}RESULT: PASS${RESET} — $fixture_pass checks confirmed, $fixture_warn warnings"
  else
    echo -e "  ${RED}RESULT: FAIL${RESET} — $fixture_fail checks MISSING, $fixture_pass passed, $fixture_warn warnings"
  fi
}

# ── Main ─────────────────────────────────────────────────────────────────────
echo -e "${CYAN}═══════════════════════════════════════════════════════${RESET}"
echo -e "${CYAN}  Claude CLI — Prompt Builder Skill Tests${RESET}"
echo -e "${CYAN}  Skill: $SKILL_FILE${RESET}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${RESET}"

ALL_SCENARIOS=("basic-chatbot" "rag-assistant" "tool-calling-agent")

if [[ "$SCENARIO_TARGET" == "all" ]]; then
  for s in "${ALL_SCENARIOS[@]}"; do
    run_scenario "$s"
  done
else
  run_scenario "$SCENARIO_TARGET"
fi

echo -e "\n${CYAN}═══════════════════════════════════════════════════════${RESET}"
echo -e "${CYAN}  SUMMARY (Builder — Claude)${RESET}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${RESET}"
echo -e "  ${GREEN}PASSED:${RESET}   $PASS_COUNT checks"
echo -e "  ${RED}FAILED:${RESET}   $FAIL_COUNT critical/high checks"
echo -e "  ${YELLOW}WARNINGS:${RESET} $WARN_COUNT medium/low checks"
echo ""

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo -e "${RED}OVERALL: FAIL — $FAIL_COUNT critical/high expected markers were not found${RESET}"
  exit 1
else
  echo -e "${GREEN}OVERALL: PASS${RESET}"
  exit 0
fi
