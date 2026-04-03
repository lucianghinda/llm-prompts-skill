
# Secure LLM Prompt Builder

Generate a secure LLM prompt and surrounding integration code from scratch, following
the OWASP structured prompt pattern and the security controls defined in the
`llm-prompts:reviewer` skill. Every generated element is annotated with the check
ID it satisfies and a one-line explanation of why it exists.

**Companion to:** `llm-prompts:reviewer` (51-check auditor). Use that skill to
audit existing code; use this skill to build new integrations correctly from the start.

**Reference implementation:** `tests/fixtures/defended-app/` in this repo — every
code block this skill generates is modeled on those 4 files.

---
