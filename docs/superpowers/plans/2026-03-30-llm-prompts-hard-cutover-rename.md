# llm-prompts Hard Cutover Rename Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the collection and both skills to `llm-prompts` names with a hard cutover.

**Architecture:** This is a metadata and path refactor. We update canonical skill IDs, folder paths, test references, and local linking config in one atomic pass so there is no mixed-name state. Validation combines positive existence checks and zero-old-token checks outside allowed exclusions.

**Tech Stack:** Markdown skill specs, Bash test scripts, text fixtures.

---

### Task 1: Rename Skill IDs And Directories

**Files:**
- Modify: `prompt-injection-review/SKILL.md`
- Modify: `prompt-builder/SKILL.md`
- Rename: `prompt-injection-review/` -> `llm-prompts-reviewer/`
- Rename: `prompt-builder/` -> `llm-prompts-builder/`

- [ ] **Step 1: Write expected-name checks (failing first)**

Run: `grep -n "^name:" llm-prompts-reviewer/SKILL.md llm-prompts-builder/SKILL.md`
Expected: FAIL before rename because paths do not exist yet.

- [ ] **Step 2: Update frontmatter names**

Set exact values:
- `name: llm-prompts:reviewer`
- `name: llm-prompts:builder`

- [ ] **Step 3: Rename directories**

Run:
- `mv prompt-injection-review llm-prompts-reviewer`
- `mv prompt-builder llm-prompts-builder`

- [ ] **Step 4: Re-run expected-name checks**

Run: `grep -n "^name:" llm-prompts-reviewer/SKILL.md llm-prompts-builder/SKILL.md`
Expected: PASS with exact canonical names.

### Task 2: Update References In Tests, Fixtures, And Config

**Files:**
- Modify: `.claude/settings.local.json`
- Modify: `tests/run-tests.sh`
- Modify: `tests/test-claude.sh`
- Modify: `tests/test-codex.sh`
- Modify: `tests/test-builder-claude.sh`
- Modify: `tests/fixtures/builder-scenarios/basic-chatbot.txt`
- Modify: `tests/fixtures/builder-scenarios/rag-assistant.txt`
- Modify: `tests/fixtures/builder-scenarios/tool-calling-agent.txt`
- Modify: `tests/expected/builder-basic-chatbot.expected`
- Modify: `tests/expected/builder-rag-assistant.expected`
- Modify: `tests/expected/builder-tool-calling-agent.expected`

- [ ] **Step 1: Update script path variables to new folder names**

Replace old skill folder paths with:
- `llm-prompts-reviewer/SKILL.md`
- `llm-prompts-builder/SKILL.md`

- [ ] **Step 2: Update human-readable labels and prompt text**

Replace textual mentions:
- `prompt-injection-review` -> `llm-prompts:reviewer`
- `prompt-builder` -> `llm-prompts:builder`

- [ ] **Step 3: Update local symlink target in settings**

Update only skill folder and skill link names in line 6 path command to `llm-prompts-builder` while keeping existing absolute repo path root unchanged.

### Task 3: Verify Hard Cutover

**Files:**
- Verify: whole repo excluding `.git/**` and `resources/Guardrails/**`

- [ ] **Step 1: Negative checks for old names**

Run greps for:
- `prompt-injection-review`
- `prompt-builder`
- `llm-prompt-injection-reviewer`

Expected: no matches in active project-owned files outside explicit exclusions.

- [ ] **Step 2: Positive checks for new canonical names**

Run checks for:
- `llm-prompts:reviewer`
- `llm-prompts:builder`
- new folder existence and old folder absence.

- [ ] **Step 3: Run tests**

Run: `tests/run-tests.sh`
Expected: pass, or clearly isolated non-rename failures with explanation.

- [ ] **Step 4: Commit rename changes**

Run:
- `git add <changed files>`
- `git commit -m "refactor: hard-cutover skills to llm-prompts namespace"`
