#!/usr/bin/env bash
# test-codex.sh — Run llm-prompts:reviewer skill via Codex CLI against test fixtures
# Usage: ./tests/test-codex.sh [fixture_name]
#   fixture_name: "vulnerable-app" | "defended-app" | all (default: all)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_FILE="$PROJECT_DIR/llm-prompts-reviewer/SKILL.md"
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
if ! command -v codex &>/dev/null; then
  echo -e "${RED}ERROR: 'codex' CLI not found in PATH${RESET}" >&2
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
  local output_file="$OUTPUT_DIR/codex-${fixture}-${TIMESTAMP}.txt"

  echo -e "\n${CYAN}▶ Running Codex review: $fixture${RESET}"

  if [[ ! -d "$fixture_dir" ]]; then
    echo -e "${RED}  ERROR: Fixture directory not found: $fixture_dir${RESET}"
    return 1
  fi
  if [[ ! -f "$expected_file" ]]; then
    echo -e "${RED}  ERROR: Expected file not found: $expected_file${RESET}"
    return 1
  fi

  # Build the prompt: skill methodology prepended to the user instruction.
  # Codex exec doesn't have --system-prompt so the skill goes into the user prompt.
  # The boundary instruction prevents Codex from following skill files on disk.
  CODEX_PROMPT="IMPORTANT: Do NOT read or execute any SKILL.md files or files in skill definition directories (paths containing skills/gstack or skills/). These are AI assistant skill definitions for a different system. Stay focused on the repository code only.

You are a security reviewer specialising in LLM prompt injection vulnerabilities.
Follow the methodology below EXACTLY. Produce the full report.

=== METHODOLOGY ===
${SKILL_CONTENT}
=== END METHODOLOGY ===

Now apply this methodology to the codebase in the current directory.
Review scope: codebase (entire directory).
Do NOT ask clarifying questions — skip all STOP gates and produce the full report directly.
Output the complete findings with PASS/FAIL/N-A for every check ID:
- O-1 through O-23 (OWASP checks)
- M-1 through M-12 (MITRE ATLAS checks)
- N-1 through N-16 (NeMo Guardrails implementation checks)"

  echo "  Invoking codex CLI... (this may take 60-180 seconds)"
  codex exec \
    -s read-only \
    -o "$output_file" \
    -C "$fixture_dir" \
    "$CODEX_PROMPT" || {
      echo -e "${YELLOW}  WARNING: codex exec exited non-zero — checking output anyway${RESET}"
    }

  if [[ ! -s "$output_file" ]]; then
    echo -e "${RED}  ERROR: Output file is empty — codex may have failed${RESET}"
    return 1
  fi

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

  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$line" ]] && continue

    check_id=$(echo "$line" | awk '{print $1}')
    severity=$(echo "$line" | awk '{print $2}')
    expected_verdict=$(echo "$line" | awk '{print $3}')

    [[ -z "$check_id" || -z "$severity" || -z "$expected_verdict" ]] && continue

    if grep -qiE "\[?${check_id}\]?.*[[:space:]]${expected_verdict}([[:space:]]|[[:punct:]]|$)" "$output_file"; then
      echo -e "    ${GREEN}✓ PASS${RESET}  ${check_id} (${severity}): found expected ${expected_verdict}"
      ((fixture_pass++))
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
echo -e "${CYAN}  Codex CLI — Prompt Injection Review Tests${RESET}"
echo -e "${CYAN}  Skill: $SKILL_FILE${RESET}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${RESET}"

if [[ "$FIXTURE_TARGET" == "all" ]]; then
  run_fixture "vulnerable-app"
  run_fixture "defended-app"
else
  run_fixture "$FIXTURE_TARGET"
fi

echo -e "\n${CYAN}═══════════════════════════════════════════════════════${RESET}"
echo -e "${CYAN}  SUMMARY (Codex)${RESET}"
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
