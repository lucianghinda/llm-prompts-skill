
### 2B: Input Validation (always generated)

Satisfies: **O-1** (validation exists), **O-2** (pattern detection), **O-3** (fuzzy/typoglycemia),
**O-4** (encoding detection), **O-5** (length limits), **M-1** (guardrails layer), **N-15** (configurable action)

Generate a class/module equivalent to `tests/fixtures/defended-app/guardrails.py`'s
`InputGuardrail`. Include in this order:

1. **Length limit check** — enforced before any pattern matching (O-5). Set a sensible
   default (e.g., 2000 chars) and note the user should tune it.

2. **Encoding decode** — attempt Base64 decode of suspicious tokens, collapse letter
   spacing ("i g n o r e" → "ignore") before pattern matching (O-4). Check BOTH the
   original and decoded text.

3. **Injection pattern regex** — compiled list covering: direct injection phrases
   ("ignore previous instructions", "system override", "forget your instructions"),
   jailbreaks ("DAN", "developer mode", "act as if you're not bound"),
   extraction probes ("reveal your prompt", "what were your instructions"),
   HTML/XSS (`<script`, `javascript:`, `<img src=`),
   SSTI (`{{`, `{%`) (O-2).

4. **Typoglycemia check** — for sensitive words (ignore, bypass, override, reveal,
   delete, system, forget): flag inputs where first+last letter match and middle is
   scrambled (O-3).

5. **Configurable action** — constructor accepts `action: "block" | "sanitize"`.
   In "block" mode return an error. In "sanitize" mode strip the offending pattern
   and continue. Default to "block" (N-15).

**Python skeleton (fill in patterns from the template above):**
```python
# WHY: [O-1, M-1] This class IS the input guardrail — without it, O-1 = FAIL.
#      Every prompt call must pass through this before reaching the LLM.
class InputGuardrail:
    MAX_INPUT_LENGTH = 2000  # WHY: [O-5] Limits adversarial suffix attack surface

    INJECTION_PATTERNS = [
        # WHY: [O-2] Covers the most common direct injection and jailbreak phrases.
        #      Keep this list versioned and updated — stale patterns miss new attacks. [N-16]
        (r"ignore\s+(all\s+)?previous\s+instructions?", "direct_injection"),
        (r"you\s+are\s+now\s+(in\s+)?(developer|dan|god|jailbreak)\s+mode", "jailbreak"),
        (r"system\s+override", "direct_injection"),
        (r"reveal\s+(your\s+)?(system\s+)?prompt", "extraction"),
        (r"forget\s+(all\s+)?your\s+(previous\s+)?instructions?", "direct_injection"),
        (r"act\s+as\s+if\s+you('re|\s+are)\s+not\s+bound", "jailbreak"),
        (r"repeat\s+the\s+text\s+above", "extraction"),
        (r"what\s+(were|are)\s+your\s+(exact\s+)?instructions?", "extraction"),
        (r"(DAN|do\s+anything\s+now)", "jailbreak"),
        (r"<script", "xss"),
        (r"javascript\s*:", "xss"),
        (r"<img\s+src\s*=", "xss"),
        (r"\{\{.*\}\}", "ssti"),  # Jinja/template injection
        (r"\{%.*%\}", "ssti"),
    ]

    SENSITIVE_WORDS = ["ignore", "bypass", "override", "reveal", "delete", "system", "forget"]

    def __init__(self, action: str = "block"):
        self.action = action  # WHY: [N-15] Configurable — block or sanitize on detection

    def check(self, text: str):
        # WHY: [O-5] Reject before any expensive processing
        if len(text) > self.MAX_INPUT_LENGTH:
            return InjectionCheckResult(is_injection=True, attack_type="length_limit")

        decoded = self._decode_obfuscation(text)  # WHY: [O-4] Decode first, then check both

        for check_text in [text, decoded]:
            # WHY: [O-2] Check against all known injection patterns
            for pattern, attack_type in self._compiled:
                if pattern.search(check_text):
                    return InjectionCheckResult(is_injection=True, attack_type=attack_type)

            # WHY: [O-3] Typoglycemia: "ignroe previous instructions" bypasses exact matching
            for word in re.findall(r'\b\w+\b', check_text.lower()):
                for target in self.SENSITIVE_WORDS:
                    if self._is_typoglycemia(word, target):
                        return InjectionCheckResult(is_injection=True, attack_type="typoglycemia")

        return InjectionCheckResult(is_injection=False)
```

**Ruby:**
```ruby
# frozen_string_literal: true

# WHY: [O-1, M-1] This class IS the input guardrail — without it, O-1 = FAIL.
#      Every prompt call must pass through this before reaching the LLM.

InjectionCheckResult = Data.define(:is_injection, :attack_type)
# Ruby < 3.2 fallback: InjectionCheckResult = Struct.new(:is_injection, :attack_type, keyword_init: true)

class InputGuardrail
  MAX_INPUT_LENGTH = 2000  # WHY: [O-5] Limits adversarial suffix attack surface

  INJECTION_PATTERNS = [
    # WHY: [O-2] Covers the most common direct injection and jailbreak phrases.
    #      Keep this list versioned and updated — stale patterns miss new attacks. [N-16]
    [/ignore\s+(?:all\s+)?previous\s+instructions?/i,           "direct_injection"],
    [/you\s+are\s+now\s+(?:in\s+)?(?:developer|dan|god|jailbreak)\s+mode/i, "jailbreak"],
    [/system\s+override/i,                                       "direct_injection"],
    [/reveal\s+(?:your\s+)?(?:system\s+)?prompt/i,              "extraction"],
    [/forget\s+(?:all\s+)?your\s+(?:previous\s+)?instructions?/i, "direct_injection"],
    [/act\s+as\s+if\s+you(?:'re|\s+are)\s+not\s+bound/i,       "jailbreak"],
    [/repeat\s+the\s+text\s+above/i,                            "extraction"],
    [/what\s+(?:were|are)\s+your\s+(?:exact\s+)?instructions?/i, "extraction"],
    [/\b(?:DAN|do\s+anything\s+now)\b/i,                        "jailbreak"],
    [/<script/i,                                                  "xss"],
    [/javascript\s*:/i,                                           "xss"],
    [/<img\s+src\s*=/i,                                          "xss"],
    [/\{\{.*\}\}/m,                                              "ssti"],
    [/\{%.*%\}/m,                                                "ssti"],
  ].freeze

  SENSITIVE_WORDS = %w[ignore bypass override reveal delete system forget].freeze

  def initialize(action: "block")
    @action = action  # WHY: [N-15] Configurable — block or sanitize on detection
    @compiled = INJECTION_PATTERNS  # already Regexp objects — no compile step needed
  end

  def check(text)
    # WHY: [O-5] Reject before any expensive processing
    return InjectionCheckResult.new(is_injection: true, attack_type: "length_limit") if text.length > MAX_INPUT_LENGTH

    decoded = decode_obfuscation(text)  # WHY: [O-4] Decode first, then check both

    [text, decoded].each do |check_text|
      # WHY: [O-2] Check against all known injection patterns
      @compiled.each do |pattern, attack_type|
        return InjectionCheckResult.new(is_injection: true, attack_type:) if pattern.match?(check_text)
      end

      # WHY: [O-3] Typoglycemia: "ignroe previous instructions" bypasses exact matching
      check_text.downcase.scan(/\b\w+\b/).each do |word|
        SENSITIVE_WORDS.each do |target|
          return InjectionCheckResult.new(is_injection: true, attack_type: "typoglycemia") if typoglycemia?(word, target)
        end
      end
    end

    InjectionCheckResult.new(is_injection: false, attack_type: nil)
  end

  private

  def decode_obfuscation(text)
    # WHY: [O-4] Base64 decode suspicious tokens + collapse letter spacing
    decoded = text.gsub(/\b([A-Za-z0-9+\/]{20,}={0,2})\b/) do |token|
      Base64.decode64(token) rescue token
    end
    decoded.gsub(/\b([a-z])\s+(?=[a-z]\s)/, '\1')  # collapse "i g n o r e" → "ignore"
  end

  def typoglycemia?(word, target)
    # WHY: [O-3] Same length, same first+last letter, same sorted middle chars
    return false unless word.length == target.length && word.length > 3
    return false unless word[0] == target[0] && word[-1] == target[-1]
    word[1..-2].chars.sort == target[1..-2].chars.sort
  end
end
```

---
