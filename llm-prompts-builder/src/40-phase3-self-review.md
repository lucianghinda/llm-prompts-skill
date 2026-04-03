
## Phase 3: Self-Review

Run an internal verification against the 10 most critical checks from the reviewer.
For each check, verify the generated code above satisfies it. Output in this format:

```
SELF-REVIEW (llm-prompts:builder v1.0)
==================================
Scope: [role] / [task] / [language] / [architecture features]

[O-7]  Structured prompt separation ............. PASS | FAIL
       Generated: build_messages() with SYSTEM_INSTRUCTIONS (system msg) +
                  USER_DATA_TO_PROCESS block + --- delimiters + boundary reminder

[O-8]  System prompt constrains behavior ......... PASS | FAIL
       Generated: role + task scope + 5 security rules (non-disclosure, data-not-commands,
                  no mode-switching, refusal, fallback response)

[O-10] External content segregated ............... PASS | FAIL | N-A
       Generated: UNTRUSTED_[SOURCE] labeled block(s) for each selected data source

[O-11] Output validation exists .................. PASS | FAIL
       Generated: OutputGuardrail.process() called before every downstream use

[O-14] Sensitive data scanning on output ......... PASS | FAIL
       Generated: SSN, credit card, password, secret key patterns in OutputGuardrail

[O-16] LLM output not directly executed .......... PASS | FAIL
       Generated: no eval/exec/system calls; SQL uses parameterized queries only

[O-17] Least privilege for LLM operations ........ PASS | FAIL | N-A
       Generated: read-only DB connection, ALLOWED_TABLES allowlist, scoped tools only

[O-18] Human approval for high-risk actions ...... PASS | FAIL | N-A
       Generated: request_human_review() tool — LLM can request, not execute

[O-20] Rate limiting present ..................... PASS | FAIL
       Generated: @rate_limited decorator (20 req/min per IP — tune as needed)

[O-21] Structured logging present ................ PASS | FAIL
       Generated: security_log with structured fields, no raw user input in log strings

Summary: [N] PASS / [N] FAIL / [N] N-A
```

If any check shows FAIL (which would indicate the builder produced incomplete output),
flag it and provide the missing code inline before Phase 4.

---
