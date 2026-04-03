
## Phase 5: Report Generation

Compile all findings into the following structured report:

```
PROMPT INJECTION SECURITY REVIEW
=================================
Scope:    <codebase | branch:<name> | commit:<sha> | files:<list>>
Date:     <date>
Reviewer: Claude (llm-prompts:reviewer skill v1.0)

EXECUTIVE SUMMARY
-----------------
Total checks: <N>  (N-A excluded from totals)
CRITICAL: <N fail> fail / <N pass> pass
HIGH:     <N fail> fail / <N pass> pass
MEDIUM:   <N fail> fail / <N pass> pass
LOW:      <N fail> fail / <N pass> pass

TOP RISKS  (CRITICAL and HIGH failures, ordered by exploitability)
------------------------------------------------------------------
1. [<check-id>] <title>
   Risk:         <one-sentence description of what an attacker can do>
   Location:     <file>:<line> or <component>
   Remediation:  <concrete next step>

2. ...

ATTACK SURFACE MAP
------------------
<ASCII diagram showing the actual data flow from Phase 1:>

  User Input ──[O-1? input validation]──► Prompt Construction
                                                │
              External Data ──[O-10? segregated]──┘
                                                │
                                               ▼
                                    [O-7? structured?] ──► LLM Model
                                                              │
                                              ◄──[O-11? output validation]──┘
                                              │
                                             ▼
                          Downstream Use (render / execute / store)

  ✓ = defense present   ✗ = defense absent/weak   ? = partially implemented

FULL FINDINGS
-------------

## Phase 2: OWASP Review

2.1 Input Defenses
  [O-1]  Input validation exists .................. PASS | FAIL | N-A
  [O-2]  Pattern detection for known attacks ....... PASS | FAIL | N-A
  [O-3]  Fuzzy/typoglycemia defense ............... PASS | FAIL | N-A
  [O-4]  Encoding detection ....................... PASS | FAIL | N-A
  [O-5]  Input length limits ...................... PASS | FAIL | N-A
  [O-6]  Multimodal input sanitization ............ PASS | FAIL | N-A

2.2 Prompt Architecture
  [O-7]  Structured prompt separation ............. PASS | FAIL | N-A
  [O-8]  System prompt constrains behavior ......... PASS | FAIL | N-A
  [O-9]  System prompt extraction defense .......... PASS | FAIL | N-A
  [O-10] External content segregated ............... PASS | FAIL | N-A

2.3 Output Defenses
  [O-11] Output validation exists ................. PASS | FAIL | N-A
  [O-12] Output format defined and enforced ........ PASS | FAIL | N-A
  [O-13] System prompt leakage detection ........... PASS | FAIL | N-A
  [O-14] Sensitive data exposure detection ......... PASS | FAIL | N-A
  [O-15] HTML/Markdown sanitization on render ...... PASS | FAIL | N-A
  [O-16] LLM output not directly executed .......... PASS | FAIL | N-A

2.4 Access Control
  [O-17] Least privilege for LLM operations ........ PASS | FAIL | N-A
  [O-18] Human approval for high-risk actions ...... PASS | FAIL | N-A
  [O-19] Privilege separation from user context .... PASS | FAIL | N-A

2.5 Monitoring
  [O-20] Rate limiting on LLM interactions ......... PASS | FAIL | N-A
  [O-21] Logging of LLM interactions .............. PASS | FAIL | N-A
  [O-22] Alerting on suspicious patterns ........... PASS | FAIL | N-A
  [O-23] Adversarial testing performed ............. PASS | FAIL | N-A

## Phase 3: MITRE ATLAS Verification

  [M-1]  AML.M0020 GenAI Guardrails .............. PASS | FAIL | N-A
  [M-2]  AML.M0021 GenAI Guidelines .............. PASS | FAIL | N-A
  [M-3]  AML.M0015 Adversarial Input Detection .... PASS | FAIL | N-A
  [M-4]  AML.M0024 AI Telemetry Logging ........... PASS | FAIL | N-A
  [M-5]  AML.M0002 Passive Output Obfuscation ..... PASS | FAIL | N-A
  [M-6]  AML.M0026 Privileged Agent Permissions ... PASS | FAIL | N-A
  [M-7]  AML.M0029 Human In-the-Loop ............. PASS | FAIL | N-A
  [M-8]  AML.M0030 Restrict Tool Invocation ........ PASS | FAIL | N-A
  [M-9]  AML.M0031 Memory Hardening .............. PASS | FAIL | N-A
  [M-10] AML.M0005 Control Access to Data ......... PASS | FAIL | N-A
  [M-11] AML.M0025 Dataset Provenance ............. PASS | FAIL | N-A
  [M-12] AML.M0022 Model Alignment ............... PASS | FAIL | N-A

## Phase 4: Implementation Checks (NeMo Guardrails Patterns)

  Input Rails
  [N-1]  Jailbreak detection (heuristic) .......... PASS | FAIL | N-A
  [N-2]  Jailbreak detection (classifier) ......... PASS | FAIL | N-A
  [N-3]  Output injection detection (YARA/pattern) . PASS | FAIL | N-A
  [N-4]  Content safety filtering ................. PASS | FAIL | N-A
  [N-5]  PII detection on input ................... PASS | FAIL | N-A
  [N-6]  Topic/scope control ...................... PASS | FAIL | N-A

  Output Rails
  [N-7]  Self-check on output ..................... PASS | FAIL | N-A
  [N-8]  Hallucination / fact-checking ............ PASS | FAIL | N-A
  [N-9]  PII detection on output .................. PASS | FAIL | N-A
  [N-10] Code/injection detection on output ........ PASS | FAIL | N-A

  Retrieval Rails
  [N-11] Content validation before indexing ........ PASS | FAIL | N-A
  [N-12] Retrieval result filtering ............... PASS | FAIL | N-A
  [N-13] Source attribution and provenance ......... PASS | FAIL | N-A

  Defense Configuration
  [N-14] Three-layer defense present .............. PASS | FAIL | N-A
  [N-15] Configurable actions on detection ......... PASS | FAIL | N-A
  [N-16] Pattern lists maintained/versioned ........ PASS | FAIL | N-A

RECOMMENDATIONS  (prioritized by impact)
-----------------------------------------
1. <Highest-impact fix with concrete implementation guidance>
   References: <O-X, M-X, N-X>

2. ...

OUT OF SCOPE / NOT REVIEWED
----------------------------
- <Items explicitly excluded and why>
```

---
