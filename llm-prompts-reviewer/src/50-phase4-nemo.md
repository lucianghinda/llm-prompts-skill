
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
