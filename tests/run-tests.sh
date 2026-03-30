#!/usr/bin/env bash
# run-tests.sh — Run all prompt-injection-review skill tests (Claude + Codex)
# Usage: ./tests/run-tests.sh [--claude-only | --codex-only] [fixture_name]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RUN_CLAUDE=true
RUN_CODEX=true
FIXTURE="${2:-all}"

case "${1:-}" in
  --claude-only) RUN_CODEX=false ;;
  --codex-only)  RUN_CLAUDE=false ;;
  --help|-h)
    echo "Usage: $0 [--claude-only | --codex-only] [fixture_name]"
    echo "  fixture_name: vulnerable-app | defended-app | all (default: all)"
    echo ""
    echo "Builder tests always run via Claude only (separate from reviewer tests):"
    echo "  builder scenario names: basic-chatbot | rag-assistant | tool-calling-agent | all"
    exit 0
    ;;
  "")
    FIXTURE="${1:-all}"
    ;;
  *)
    FIXTURE="${1}"
    ;;
esac

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

OVERALL_PASS=true

echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════════╗"
echo "║   Prompt Injection Review Skill — Test Suite          ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo -e "${RESET}"

if $RUN_CLAUDE; then
  echo -e "${CYAN}── Claude CLI Tests: prompt-injection-review ────────────${RESET}"
  bash "$SCRIPT_DIR/test-claude.sh" "$FIXTURE" || OVERALL_PASS=false

  echo -e "\n${CYAN}── Claude CLI Tests: prompt-builder ─────────────────────${RESET}"
  bash "$SCRIPT_DIR/test-builder-claude.sh" all || OVERALL_PASS=false
fi

if $RUN_CODEX; then
  echo -e "\n${CYAN}── Codex CLI Tests: prompt-injection-review ─────────────${RESET}"
  bash "$SCRIPT_DIR/test-codex.sh" "$FIXTURE" || OVERALL_PASS=false
fi

echo ""
if $OVERALL_PASS; then
  echo -e "${GREEN}╔═══════════════════════════════════════╗${RESET}"
  echo -e "${GREEN}║  ALL TESTS PASSED                     ║${RESET}"
  echo -e "${GREEN}╚═══════════════════════════════════════╝${RESET}"
  exit 0
else
  echo -e "${RED}╔═══════════════════════════════════════╗${RESET}"
  echo -e "${RED}║  SOME TESTS FAILED                    ║${RESET}"
  echo -e "${RED}╚═══════════════════════════════════════╝${RESET}"
  exit 1
fi
