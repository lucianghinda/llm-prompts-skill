
### 2D: Integration Wiring (always generated)

Satisfies: **O-20** (rate limiting), **O-21** (structured logging), **O-19** (privilege separation)

Wire the pipeline: rate limit → input validation → prompt construction → LLM call → output validation.

```python
# WHY: [O-20] Rate limiting: per-IP/per-user to slow Best-of-N jailbreak attacks.
#      Without it, an attacker can iterate thousands of prompt variations automatically.
@rate_limited  # 20 req/min per IP — tune to your use case

def handle_llm_request(user_input: str) -> dict:
    # WHY: [O-21] Log all LLM interactions for security analysis.
    #      Use structured fields — never embed raw user input in log message strings
    #      (that itself is an injection vector into log parsers).
    security_log.info("llm_request ip=%s length=%d", request.remote_addr, len(user_input))

    # WHY: [O-1, O-2, O-3, O-4, O-5] Input guardrail FIRST — before touching the LLM
    guardrail = InputGuardrail()
    result = guardrail.check(user_input)
    if result.is_injection:
        security_log.warning(
            "injection_detected type=%s ip=%s", result.attack_type, request.remote_addr
        )
        return {"error": "I cannot process that request."}, 400

    # WHY: [O-7, O-10] Structured prompt — never concatenate user input directly
    messages = build_messages(user_input)

    raw_output = call_llm(messages)  # Your LLM API call here

    # WHY: [O-11, O-13, O-14, O-15] Output guardrail BEFORE returning to caller
    output_guard = OutputGuardrail()
    safe_output = output_guard.process(raw_output)
    if safe_output is None:
        security_log.warning("output_blocked ip=%s", request.remote_addr)
        return {"error": "Response could not be generated safely."}, 500

    security_log.info("llm_response ip=%s output_length=%d", request.remote_addr, len(safe_output))
    return {"response": safe_output}
```

**Ruby:**
```ruby
# frozen_string_literal: true

require "logger"

# WHY: [O-21] Structured logging — dedicated security logger, never interpolate raw
#      user input into the log message string (that is itself a log-injection vector).
SECURITY_LOG = Logger.new($stdout).tap { |l| l.progname = "security" }

# WHY: [O-20] Rate limiting: per-IP/per-user to slow Best-of-N jailbreak attacks.
#      Without it, an attacker can iterate thousands of prompt variations automatically.
RATE_LIMIT_WINDOW = 60        # seconds
RATE_LIMIT_MAX    = 20        # requests per window
@rate_limit_store = Hash.new { |h, k| h[k] = [] }  # ip => [timestamps]

def rate_limited?(ip)
  now = Time.now.to_f
  @rate_limit_store[ip].reject! { |t| t < now - RATE_LIMIT_WINDOW }
  return true if @rate_limit_store[ip].size >= RATE_LIMIT_MAX
  @rate_limit_store[ip] << now
  false
end

def handle_llm_request(user_input, ip:)
  # WHY: [O-20] Check rate limit before any processing
  return { error: "Rate limit exceeded." } if rate_limited?(ip)

  # WHY: [O-21] Log request with structured fields — length, not content
  SECURITY_LOG.info("llm_request ip=#{ip} length=#{user_input.length}")

  # WHY: [O-1, O-2, O-3, O-4, O-5] Input guardrail FIRST — before touching the LLM
  guardrail = InputGuardrail.new
  result = guardrail.check(user_input)
  if result.is_injection
    SECURITY_LOG.warn("injection_detected type=#{result.attack_type} ip=#{ip}")
    return { error: "I cannot process that request." }
  end

  # WHY: [O-7, O-10] Structured prompt — never concatenate user input directly
  messages = build_messages(user_input)

  raw_output = call_llm(messages)  # Your LLM API call here

  # WHY: [O-11, O-13, O-14, O-15] Output guardrail BEFORE returning to caller
  safe_output = OutputGuardrail.new.process(raw_output)
  if safe_output.nil?
    SECURITY_LOG.warn("output_blocked ip=#{ip}")
    return { error: "Response could not be generated safely." }
  end

  SECURITY_LOG.info("llm_response ip=#{ip} output_length=#{safe_output.length}")
  { response: safe_output }
end
```

---
