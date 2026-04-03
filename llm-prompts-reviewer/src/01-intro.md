
# Prompt Injection Security Review

Review a codebase, branch, commit, or set of files for LLM prompt injection vulnerabilities.
Produces a structured report based on three authoritative sources (in priority order):

1. **OWASP LLM01:2025** and the OWASP Prompt Injection Prevention Cheat Sheet (primary)
2. **MITRE ATLAS** mitigation controls (AML.M0002–M0031) — adds compliance IDs
3. **NeMo Guardrails** implementation patterns — what production defenses look like in code

## Severity Levels

| Level    | Meaning |
|----------|---------|
| CRITICAL | Exploitable now, no mitigation present. Attacker can extract data, execute commands, or bypass controls. |
| HIGH     | Attack surface exists with only partial mitigation. A skilled attacker can likely bypass. |
| MEDIUM   | Defense-in-depth gap. Primary defense may hold, but no fallback if it fails. |
| LOW      | Hardening opportunity. Not directly exploitable but reduces security margin. |

---
