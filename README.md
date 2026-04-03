# Skills to review LLM prompts

Claude Code skills for auditing and building LLM integrations against prompt injection attacks.

## Skills

Two companion skills are provided:

| Skill | File | Purpose |
|-------|------|---------|
| `llm-prompts:reviewer` | `llm-prompts-reviewer/SKILL.md` | Audit existing code for prompt injection vulnerabilities |
| `llm-prompts:builder` | `llm-prompts-builder/SKILL.md` | Generate secure LLM integration scaffolding from scratch |

Both skills are designed to be used with **Claude Code** (`claude` CLI). They can also be used with any AI coding assistant that supports custom system prompts.

---

## Quick Start

### Audit existing code

```bash
# From your project directory:
claude --system-prompt "$(cat /path/to/llm-prompts-reviewer/SKILL.md)" \
  "Review this codebase for prompt injection vulnerabilities."
```

Or if you have the skill installed in Claude Code's skill directory, trigger it with:

```
review this code for prompt injection
```

### Build a new secure LLM integration

```bash
claude --system-prompt "$(cat /path/to/llm-prompts-builder/SKILL.md)" \
  "Build a secure LLM prompt for a customer service chatbot."
```

---

## What the reviewer checks

The `llm-prompts:reviewer` skill runs **51 checks** across three authoritative sources:

**OWASP LLM01:2025 (O-1 – O-23)**
- Input validation, injection pattern detection, typoglycemia/encoding defenses
- Structured prompt separation (the StruQ pattern)
- Output validation, system prompt leakage detection, HTML/Markdown sanitization
- Access control, least privilege, human-in-the-loop gates
- Rate limiting, logging, alerting

**MITRE ATLAS Mitigations (M-1 – M-12)**
- AML.M0020 GenAI Guardrails, AML.M0021 GenAI Guidelines, AML.M0029 Human-in-the-Loop
- AML.M0030 Restrict Tool Invocation, AML.M0031 Memory Hardening, and more

**NeMo Guardrails Implementation Patterns (N-1 – N-16)**
- Jailbreak detection (heuristic + classifier), PII detection, content safety
- Retrieval rail validation (RAG document scanning, retrieval filtering, source provenance)
- Defense configuration (three-layer defense, actionable detection, pattern versioning)

Each finding is rated CRITICAL / HIGH / MEDIUM / LOW and maps to concrete remediation guidance.

### Sample report output

```
PROMPT INJECTION SECURITY REVIEW
=================================
Scope:    codebase
CRITICAL: 3 fail / 2 pass
HIGH:     5 fail / 4 pass

TOP RISKS
---------
1. [O-7] No structured prompt separation
   Risk: User input is concatenated directly into the prompt — attacker can override system instructions
   Location: app.py:42
   Remediation: Wrap user input in a USER_DATA_TO_PROCESS block with --- delimiters...
```

---

## What the builder generates

The `llm-prompts:builder` skill takes your requirements (role, task, data sources, output usage, language, architecture) and generates:

- A **system prompt** with all five OWASP security elements
- **`guardrails.py`** — `InputGuardrail` (length limits, encoding detection, injection patterns, typoglycemia) and `OutputGuardrail` (leakage, PII, HTML injection detection)
- **`integration.py`** — rate limiting, structured logging, main request handler
- **`tools.py`** — if tool calling was selected (parameterized queries, allowlisted tables, human-approval gate)
- **`rag.py`** — if RAG was selected (pre-indexing validation, retrieval filtering, source attribution)

Every generated code block is annotated with the check ID it satisfies (`# WHY: [O-7]`).

The builder self-verifies its output against the 10 most critical checks before delivering.

---

## Supported languages

The structured prompt pattern (O-7) and code templates are provided for:
- Python
- JavaScript / TypeScript
- Ruby
- Go

---

## Reference implementation

`tests/fixtures/defended-app/` is a complete reference implementation of a secure LLM chatbot in Python (Flask + OpenAI). It demonstrates every defense the skills check for and is the canonical model for code the builder generates.

The companion `tests/fixtures/vulnerable-app/` is an intentionally insecure version — useful for understanding what each vulnerability looks like in practice.

---

## Testing the skills

The test suite runs both skills against fixture apps using the real Claude (and optionally Codex) CLI and validates that the output contains the expected PASS/FAIL verdicts.

```bash
# All tests
./tests/run-tests.sh

# Claude only (reviewer + builder)
./tests/run-tests.sh --claude-only

# Single reviewer fixture
./tests/run-tests.sh --claude-only vulnerable-app
./tests/run-tests.sh --claude-only defended-app

# Single builder scenario
./tests/test-builder-claude.sh basic-chatbot
./tests/test-builder-claude.sh rag-assistant
./tests/test-builder-claude.sh tool-calling-agent

# Codex reviewer only
./tests/run-tests.sh --codex-only
```

**Prerequisites:** `claude` CLI in `$PATH`. Each test invokes a real LLM and takes 60–180 seconds.

### How tests work

Each test passes the full SKILL.md as `--system-prompt` to `claude -p`, runs it against a fixture directory, and validates the text output by grepping for expected verdicts:

```
# tests/expected/vulnerable-app.expected
O-1   CRITICAL  FAIL   # no input validation
O-7   CRITICAL  FAIL   # direct string concatenation
O-11  CRITICAL  FAIL   # no output validation
O-8   HIGH      FAIL   # system prompt missing security rules
```

A test fails only when a CRITICAL or HIGH expected verdict is not found. MEDIUM/LOW mismatches are reported as warnings.

---

## Security framework references

- [OWASP Top 10 for LLMs 2025 — LLM01: Prompt Injection](https://owasp.org/www-project-top-10-for-large-language-model-applications/)
- [OWASP Prompt Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Prompt_Injection_Prevention_Cheat_Sheet.html)
- [MITRE ATLAS — Adversarial Threat Landscape for AI Systems](https://atlas.mitre.org/)
- [NVIDIA NeMo Guardrails](https://github.com/NVIDIA/NeMo-Guardrails)
