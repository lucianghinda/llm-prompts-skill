# llm-prompts Identity Refresh Design

## Goal

Perform a hard-cutover rename of this repository's skill collection and skill IDs so the project is consistently branded as `llm-prompts`, with skill names `llm-prompts:reviewer` and `llm-prompts:builder`.

## Decisions

1. Migration style is hard cutover only.
2. New skill IDs are short forms:
   - `llm-prompts:reviewer`
   - `llm-prompts:builder`
3. Repo identity is refreshed in project-owned files from `llm-prompt-injection-reviewer` to `llm-prompts` when the string is used as project identity.
4. Vendored or third-party content under `resources/Guardrails/**` is out of scope for rename changes.

## Scope

### In scope

- Rename the two skill directories to match the new collection identity.
- Update frontmatter `name:` fields in both `SKILL.md` files.
- Update all cross-references to old skill names in project-owned files.
- Update test scripts, fixtures, and expected output labels that reference old names.
- Update project path/name string references in local project config where they represent repo identity.

### Out of scope

- Backward compatibility aliases from old names.
- Runtime compatibility shims.
- Editing vendored upstream materials in `resources/Guardrails/**`.

## Canonical Replacement Table

All implementation changes must use this mapping exactly.

1. Skill IDs (frontmatter `name:`)
   - `prompt-injection-review` -> `llm-prompts:reviewer`
   - `prompt-builder` -> `llm-prompts:builder`

2. Slash-command references in prose and examples
   - `/prompt-injection-review` -> `/llm-prompts:reviewer`
   - `/prompt-builder` -> `/llm-prompts:builder`

3. Path-level skill folder references
   - `prompt-injection-review/` -> `llm-prompts-reviewer/`
   - `prompt-builder/` -> `llm-prompts-builder/`

4. Human-readable labels
   - `prompt-injection-review skill` -> `llm-prompts:reviewer skill`
   - `prompt-builder skill` -> `llm-prompts:builder skill`

## Validation Exclusions

For completion checks, these locations are excluded from old-name-zero requirements:

1. Git internals and history metadata (`.git/**`).
2. Vendored upstream content (`resources/Guardrails/**`).
3. Migration/spec documentation that intentionally references legacy names for traceability:
   - `docs/superpowers/specs/2026-03-30-llm-prompts-rename-design.md`

Everything else in repository-managed project files is considered active and must satisfy cutover rules.

## Architecture And Data Flow

The rename is metadata and path driven. There is no runtime architecture change, but the flow that must remain valid is:

1. Test scripts resolve skill file paths.
2. Skill files expose the canonical skill IDs in frontmatter (`name:`).
3. Fixtures and expected outputs describe the same names used by scripts and docs.
4. Local settings referencing project paths stay aligned with current repository identity.

To avoid breakage, apply changes in this order:

1. Update `name:` fields in skill frontmatter.
2. Update textual references in skill docs, tests, and fixtures.
3. Rename directories and update path variables in scripts.
4. Run repository-wide verification for stale names and path errors.

## File-Level Design

### Skill definitions

- Rename `prompt-injection-review/SKILL.md` to `llm-prompts-reviewer/SKILL.md`
  - `name: llm-prompts:reviewer`
  - Update references to old reviewer name and command text.

- Rename `prompt-builder/SKILL.md` to `llm-prompts-builder/SKILL.md`
  - `name: llm-prompts:builder`
  - Update references to old builder/reviewer names and command text.

### Tests and fixtures

- Update scripts:
  - `tests/test-claude.sh`
  - `tests/test-codex.sh`
  - `tests/test-builder-claude.sh`
  - `tests/run-tests.sh`

- Update fixture copy and expected markers in:
  - `tests/fixtures/builder-scenarios/*.txt`
  - `tests/expected/*.expected`

### Project config and identity strings

- Update `.claude/settings.local.json` only when the local repo directory has been renamed.
- If local directory rename is not yet complete, skip absolute-path replacement in this file to avoid breaking local tooling.
- Rule: never modify working absolute paths solely for branding; only update when filesystem path changed.

## Error Handling

Failure classes and mitigations:

1. Broken path references after directory rename
   - Mitigation: update all script path variables and run script dry checks.
2. Stale old-name references in docs/tests
   - Mitigation: global grep for old identifiers and fix all project-owned matches.
3. False positives from `.git` history
   - Mitigation: exclude git internals from completion criteria.

## Testing Strategy

1. Static validation:
   - Grep for old names:
     - `prompt-injection-review`
     - `prompt-builder`
     - `llm-prompt-injection-reviewer`
  - Confirm matches only exist in `Validation Exclusions`.

2. Positive validation:
   - Confirm `name:` values are exactly:
     - `llm-prompts:reviewer`
     - `llm-prompts:builder`
   - Confirm new directories exist:
     - `llm-prompts-reviewer/`
     - `llm-prompts-builder/`
   - Confirm old directories do not exist:
     - `prompt-injection-review/`
     - `prompt-builder/`
   - Confirm script path variables point to new `SKILL.md` locations.

3. Behavioral validation:
   - Run `tests/run-tests.sh`.
   - If needed, run each script individually to isolate path/name regressions.

4. Hard-cutover gate:
   - Cutover is FAILED if any old canonical token/path remains outside `Validation Exclusions`.
   - Cutover is PASSED only if both negative and positive validations pass.

## Success Criteria

1. Skills declare canonical names:
   - `llm-prompts:reviewer`
   - `llm-prompts:builder`
2. No active project-owned file references old skill names.
3. No active project-owned file references old repo identity string for this collection.
4. Test scripts execute without path/name errors.

## Implementation Gate

The rename is considered shippable only when all of the following are true:

1. Old-name grep checks return zero matches outside `Validation Exclusions`.
2. New-name positive checks pass for frontmatter, directory layout, and script paths.
3. Test run completes without failures caused by stale names or stale paths.

## Risks

1. Local tooling outside this repository may still call old names.
2. Hard cutover can break external automation immediately.

Given the explicit hard-cutover requirement, these risks are accepted and will not be mitigated via aliases.
