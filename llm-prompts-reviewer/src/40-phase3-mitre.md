
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
