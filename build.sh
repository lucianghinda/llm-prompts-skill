#!/usr/bin/env bash
# build.sh — Assemble SKILL.md from src/ parts for each skill directory.
#
# Usage:
#   ./build.sh           — rebuild all SKILL.md files
#   ./build.sh --check   — verify SKILL.md files match src/ parts (exit 1 if stale)
#
# Each skill directory with a src/ subdirectory is assembled.
# Files in src/ are concatenated in lexicographic order — the numeric prefix
# (00-, 01-, 10-, ...) controls assembly order.
#
# To edit a skill:
#   1. Edit the relevant file(s) in src/
#   2. Run ./build.sh
#   3. Commit both src/ changes and the regenerated SKILL.md

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_MODE=false

GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

if [[ "${1:-}" == "--check" ]]; then
  CHECK_MODE=true
fi

build_skill() {
  local skill_dir="$1"
  local src_dir="$skill_dir/src"
  local target="$skill_dir/SKILL.md"
  local skill_name
  skill_name="$(basename "$skill_dir")"

  if [[ ! -d "$src_dir" ]]; then
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  trap "rm -f '$tmp'" RETURN

  # Concatenate all .md files in sorted (lexicographic) order
  for part in "$src_dir"/*.md; do
    cat "$part" >> "$tmp"
  done

  if "$CHECK_MODE"; then
    if ! diff -q "$target" "$tmp" > /dev/null 2>&1; then
      echo -e "${RED}MISMATCH${RESET}: $skill_name/SKILL.md does not match its src/ parts." >&2
      echo -e "  Do not edit SKILL.md directly — edit files in $skill_name/src/ and run ./build.sh." >&2
      return 1
    fi
    echo -e "${GREEN}OK${RESET}: $skill_name/SKILL.md is up to date"
  else
    cp "$tmp" "$target"
    echo -e "${GREEN}Built${RESET}: $skill_name/SKILL.md ($(wc -l < "$target" | tr -d ' ') lines from $(ls -1 "$src_dir"/*.md | wc -l | tr -d ' ') parts)"
  fi
}

EXIT_CODE=0
for skill_dir in "$PROJECT_DIR"/llm-prompts-*/; do
  build_skill "$skill_dir" || EXIT_CODE=1
done

exit "$EXIT_CODE"
