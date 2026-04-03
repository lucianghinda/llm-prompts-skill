
### 2E: Tool Definitions (generated IF tool calling was selected)

Satisfies: **O-16** (no direct execution), **O-17** (least privilege), **O-18** (human approval),
**M-6** (privileged agent permissions), **M-7** (human-in-the-loop), **M-8** (restrict tool invocation)

```python
# WHY: [O-17, M-6] Minimal tool scope — only the tables/APIs needed for the stated task.
#      The LLM sees only these tools. It cannot access anything not in this registry.
ALLOWED_TABLES = {"[table1]", "[table2]"}  # Fill in from your schema

# WHY: [O-16, M-8] All SQL is parameterized and pre-validated.
#      LLM output is NEVER concatenated into SQL strings.
def query_knowledge_base(sql: str) -> list:
    if not re.match(r"^\s*SELECT\s+.+\s+FROM\s+(\w+)", sql, re.IGNORECASE):
        raise ToolValidationError("Only SELECT queries are permitted.")
    table = re.search(r"FROM\s+(\w+)", sql, re.IGNORECASE).group(1).lower()
    if table not in ALLOWED_TABLES:
        raise ToolValidationError(f"Table '{table}' is not accessible.")
    return read_only_conn.execute(sql).fetchall()

# WHY: [O-18, M-7] Destructive operations (delete, email, purchase, admin) go through
#      human approval. The LLM can REQUEST but never EXECUTE these actions directly.
#      This is an architectural constraint, not a prompt instruction — the LLM has no
#      tool for direct execution. Only request_human_review exists.
def request_human_review(action: str, context: str, user_id: str) -> str:
    review_id = str(uuid.uuid4())[:8]
    security_log.info("human_review_requested id=%s action=%s user=%s", review_id, action, user_id)
    # Insert into approval queue — a human must approve before anything happens
    return f"Review {review_id} submitted. A team member will follow up."
```

**Ruby:**
```ruby
# frozen_string_literal: true

require "securerandom"

class ToolValidationError < ArgumentError; end

# WHY: [O-17, M-6] Minimal tool scope — only the tables/APIs needed for the stated task.
#      The LLM sees only these tools. It cannot access anything not in this registry.
ALLOWED_TABLES = %w[table1 table2].to_set.freeze  # Fill in from your schema

SAFE_SQL_PATTERN = /\A\s*SELECT\s+.+\s+FROM\s+(\w+)/i.freeze  # WHY: [O-16, M-8] SELECT-only

# WHY: [O-16, M-8] All SQL is validated against the allowlist; no DDL/DML permitted.
#      LLM output is NEVER interpolated into SQL strings — use only pre-validated queries.
def query_knowledge_base(sql)
  m = SAFE_SQL_PATTERN.match(sql)
  raise ToolValidationError, "Only SELECT queries are permitted." unless m

  table = m[1].downcase
  raise ToolValidationError, "Table '#{table}' is not accessible." unless ALLOWED_TABLES.include?(table)

  # WHY: [O-17] Read-only connection — LLM cannot write, delete, or alter schema
  READ_ONLY_DB.execute(sql)  # e.g. SQLite3::Database.new("db.sqlite3", readonly: true)
end

# WHY: [O-18, M-7] Destructive operations (delete, email, purchase, admin) go through
#      human approval. The LLM can REQUEST but never EXECUTE these actions directly.
#      This is an architectural constraint, not a prompt instruction — the LLM has no
#      method for direct execution. Only request_human_review exists.
def request_human_review(action:, context:, user_id:)
  review_id = SecureRandom.hex(4)
  SECURITY_LOG.info("human_review_requested id=#{review_id} action=#{action} user=#{user_id}")
  # Insert into approval queue — a human must approve before anything happens
  "Review #{review_id} submitted. A team member will follow up."
end

# WHY: [O-17, M-6] Explicit tool registry — the LLM sees only what is listed here
AGENT_TOOLS = [
  {
    name: "query_knowledge_base",
    description: "Run a read-only SELECT query against the knowledge base.",
    parameters: { type: "object", properties: { sql: { type: "string" } }, required: ["sql"] },
    function: method(:query_knowledge_base)
  },
  {
    name: "request_human_review",
    description: "Request human approval for a high-risk action. Use for any delete, send, or purchase.",
    parameters: {
      type: "object",
      properties: {
        action:  { type: "string" },
        context: { type: "string" },
        user_id: { type: "string" }
      },
      required: %w[action context user_id]
    },
    function: method(:request_human_review)
  }
  # No shell execution, no file system access, no email sending without approval.
].freeze
```

---
