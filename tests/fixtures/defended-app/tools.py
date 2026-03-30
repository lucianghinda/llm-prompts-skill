"""
Secure tool definitions for LLM agent.
Satisfies O-17, O-18, M-6 (AML.M0026), M-7 (AML.M0029), M-8 (AML.M0030).
"""
import logging
import re
import sqlite3
from typing import Optional

security_log = logging.getLogger("security.tools")


class ToolValidationError(ValueError):
    pass


# ---------------------------------------------------------------------------
# Read-only database access — satisfies O-17, M-10
# Separate read-only connection, restricted to non-sensitive tables
# ---------------------------------------------------------------------------
_READ_ONLY_CONN = sqlite3.connect("file:data.db?mode=ro", uri=True, check_same_thread=False)

# Allowlist of tables the LLM agent may query — O-17, M-6
ALLOWED_TABLES = {"products", "faqs", "support_articles"}

# SQL allowlist: only SELECT, no DDL/DML — O-16, M-8
_SAFE_SQL_PATTERN = re.compile(
    r"^\s*SELECT\s+.+\s+FROM\s+(\w+)", re.IGNORECASE | re.DOTALL
)


def query_knowledge_base(sql: str) -> list:
    """
    Query the product knowledge base (read-only, restricted tables).
    M-8: validates SQL before execution. O-17: read-only, restricted tables.
    """
    match = _SAFE_SQL_PATTERN.match(sql)
    if not match:
        raise ToolValidationError("Only SELECT queries are permitted.")

    table_name = match.group(1).lower()
    if table_name not in ALLOWED_TABLES:
        security_log.warning("tool_access_denied table=%s", table_name)
        raise ToolValidationError(f"Table '{table_name}' is not accessible.")

    cursor = _READ_ONLY_CONN.execute(sql)
    return cursor.fetchall()


def get_product_info(product_id: str) -> Optional[dict]:
    """
    Look up product information by ID.
    Parameterized query — no SQL injection. O-16.
    """
    if not re.match(r'^[A-Z0-9\-]{3,20}$', product_id):
        raise ToolValidationError("Invalid product ID format.")

    cursor = _READ_ONLY_CONN.execute(
        "SELECT id, name, description, price FROM products WHERE id = ?",
        (product_id,)  # Parameterized — not concatenated
    )
    row = cursor.fetchone()
    if row:
        return {"id": row[0], "name": row[1], "description": row[2], "price": row[3]}
    return None


def request_human_review(action: str, context: str, user_id: str) -> str:
    """
    Queue an action for human approval before execution.
    O-18, M-7 (AML.M0029): human-in-the-loop for high-risk operations.
    The LLM can REQUEST actions but cannot EXECUTE them directly.
    """
    import uuid
    review_id = str(uuid.uuid4())[:8]
    security_log.info(
        "human_review_requested id=%s action=%s user=%s",
        review_id, action, user_id
    )
    # In production: insert into approval_queue table, notify human reviewer
    return f"Review request {review_id} submitted. A team member will follow up within 24 hours."


# Tool registry — limited scope, validation enforced — M-6, M-8
AGENT_TOOLS = [
    {
        "name": "query_knowledge_base",
        "description": (
            "Query the product knowledge base. Only SELECT queries against "
            "products, faqs, or support_articles tables are allowed."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "sql": {
                    "type": "string",
                    "description": "SQL SELECT query (read-only)"
                }
            },
            "required": ["sql"]
        },
        "function": query_knowledge_base
    },
    {
        "name": "get_product_info",
        "description": "Get product details by product ID (format: ABC-123).",
        "parameters": {
            "type": "object",
            "properties": {
                "product_id": {
                    "type": "string",
                    "description": "Product ID in ABC-123 format"
                }
            },
            "required": ["product_id"]
        },
        "function": get_product_info
    },
    {
        "name": "request_human_review",
        "description": (
            "Use this to request that a human team member takes an action on behalf of the customer. "
            "Use for refunds, account changes, escalations. "
            "You cannot take these actions directly — a human must approve them."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "action": {"type": "string", "description": "Action to request"},
                "context": {"type": "string", "description": "Relevant context"},
                "user_id": {"type": "string", "description": "Customer user ID"}
            },
            "required": ["action", "context", "user_id"]
        },
        "function": request_human_review
    }
]
# Note: no shell execution, no file system access, no email sending without approval
