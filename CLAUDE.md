# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A collection of Claude Code **skills** for reviewing and building LLM integrations with prompt injection defenses. There is no application to run — the deliverable is the skill SKILL.md files in `llm-prompts-reviewer/` and `llm-prompts-builder/`.

- **`llm-prompts-reviewer/SKILL.md`** — the `llm-prompts:reviewer` skill: a 51-check security auditor (OWASP LLM01:2025, MITRE ATLAS, NeMo Guardrails patterns)
- **`llm-prompts-builder/SKILL.md`** — the `llm-prompts:builder` skill: generates secure LLM prompt scaffolding from requirements

## Running tests

Tests invoke the actual Claude or Codex CLI against Python fixture apps and validate that the skills produce correct PASS/FAIL verdicts.

```bash
# All tests (Claude + Codex)
./tests/run-tests.sh

# Claude reviewer only
./tests/run-tests.sh --claude-only

# Single fixture
./tests/run-tests.sh --claude-only vulnerable-app
./tests/run-tests.sh --claude-only defended-app

# Builder skill tests (Claude only)
./tests/test-builder-claude.sh basic-chatbot
./tests/test-builder-claude.sh rag-assistant
./tests/test-builder-claude.sh tool-calling-agent

# Codex reviewer only
./tests/run-tests.sh --codex-only
```

**Prerequisites:** `claude` CLI (and optionally `codex` CLI) must be in `$PATH`. Tests take 60–180 seconds each because they invoke real LLM calls.

## Test architecture

Each test run passes the full SKILL.md content as a `--system-prompt` to `claude -p` (print mode), points it at a fixture directory, and captures the text output. The validate step greps the output for lines matching:

```
\[?CHECK_ID\]?.*<VERDICT>
```

Expected verdicts are defined in `tests/expected/*.expected` files — one line per check:
```
O-1  CRITICAL  FAIL   # no input validation
O-11 CRITICAL  PASS
```

Builder tests additionally support `@PATTERN|SEVERITY|PRESENT` lines that grep for arbitrary regex in the output.

## Fixture apps

- **`tests/fixtures/vulnerable-app/`** — intentionally insecure Python Flask app (no guardrails, raw string concatenation into prompts)
- **`tests/fixtures/defended-app/`** — reference secure implementation: `app.py`, `guardrails.py`, `rag.py`, `tools.py`

The defended-app is also the **canonical reference implementation** cited in the builder skill — every code template the builder generates is modeled on it.

## Editing skills

**Never edit SKILL.md directly.** Each skill is assembled from smaller source files. To edit a skill:

1. Edit the relevant file(s) in `llm-prompts-*/src/`
2. Run `./build.sh` to regenerate SKILL.md
3. Commit both the `src/` changes and the regenerated SKILL.md

Run `./build.sh --check` to verify SKILL.md is up to date with src/. A GitHub Actions workflow runs this check on every push and PR — it will fail if SKILL.md is stale.

### Source file layout

Each skill directory has a `src/` subdirectory with numbered parts:

```
llm-prompts-builder/src/
  00-frontmatter.md               YAML frontmatter
  01-intro.md                     Title + intro
  10-phase0-requirements.md       Phase 0: Gather Requirements
  20-phase1-system-prompt.md      Phase 1: System Prompt generation
  30-phase2-intro.md              Phase 2 heading
  31-phase2a-prompt-construction.md  2A: Prompt construction templates
  32-phase2b-input-validation.md     2B: InputGuardrail (Python + Ruby)
  33-phase2c-output-validation.md    2C: OutputGuardrail (Python + Ruby)
  34-phase2d-integration-wiring.md   2D: Rate limiting + logging
  35-phase2e-tool-definitions.md     2E: Tool definitions
  36-phase2f-rag-pipeline.md         2F: RAG pipeline templates
  40-phase3-self-review.md        Phase 3: Self-Review
  50-phase4-deliver.md            Phase 4: Deliver + next steps
  60-reference.md                 OWASP quick reference

llm-prompts-reviewer/src/
  00-frontmatter.md               YAML frontmatter
  01-intro.md                     Title + severity levels
  10-step0-scope.md               Step 0: Determine scope
  20-phase1-discovery.md          Phase 1: Discovery
  30-phase2-owasp.md              Phase 2: OWASP checks O-1–O-23
  40-phase3-mitre.md              Phase 3: MITRE ATLAS M-1–M-12
  50-phase4-nemo.md               Phase 4: NeMo N-1–N-16
  60-phase5-report.md             Phase 5: Report generation
  70-reference-index.md           Quick index of all 51 checks
  80-appendix-a-templates.md      Appendix A: Prompt templates
```

Numeric prefixes control assembly order. The tens-based spacing (10, 20, 30…) leaves room to insert new sections without renaming everything.

## Skills structure

Each SKILL.md starts with YAML frontmatter (name, description, allowed-tools) and contains the full methodology that Claude follows as a system prompt. The skills use a multi-phase, STOP-gated approach:

- **Reviewer**: Phase 1 Discovery → Phase 2 OWASP → Phase 3 MITRE ATLAS → Phase 4 NeMo → Phase 5 Report
- **Builder**: Phase 0 Requirements → Phase 1 System Prompt → Phase 2 Code Scaffolding → Phase 3 Self-Review → Phase 4 Deliver

When modifying skills, the key constraint is that check IDs (O-1 through O-23, M-1 through M-12, N-1 through N-16) must remain stable — the test expected files depend on them.

## Adding/updating expected files

Expected files live in `tests/expected/`. The format for reviewer tests is:
```
CHECK_ID  SEVERITY  VERDICT   # optional comment
```
SEVERITY must be `CRITICAL`, `HIGH`, `MEDIUM`, or `LOW`. Only CRITICAL/HIGH failures count as test failures; MEDIUM/LOW are warnings.

Builder expected files support both the check-ID format above and `@regex|SEVERITY|PRESENT` for structural assertions (e.g., `@USER_DATA_TO_PROCESS|HIGH|PRESENT`).
