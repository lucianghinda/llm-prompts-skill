"""
Vulnerable tool definitions exposed to LLM agent.
DO NOT deploy. Intentional security vulnerabilities for testing.
"""
import os
import subprocess


# [VULN M-8, M-6] Tools callable with any parameters — no validation, no scoping
# The LLM can call these with attacker-controlled arguments

def run_shell_command(command: str) -> str:
    """Execute a shell command and return its output."""
    # [VULN O-16, M-8] No allowlist, no sandboxing — arbitrary shell execution
    result = subprocess.run(command, shell=True, capture_output=True, text=True)
    return result.stdout + result.stderr


def read_file(path: str) -> str:
    """Read any file on the filesystem."""
    # [VULN M-6, O-17] No path restrictions — can read /etc/passwd, private keys, etc.
    with open(path, "r") as f:
        return f.read()


def send_email(to: str, subject: str, body: str) -> str:
    """Send an email to any address."""
    # [VULN O-18] Destructive action (email) with no human-in-the-loop approval
    # An injected prompt can exfiltrate data via email
    import smtplib
    print(f"[EMAIL] To: {to}, Subject: {subject}, Body: {body}")
    return "Email sent"


def query_database(sql: str) -> list:
    """Execute any SQL query against the production database."""
    import sqlite3
    # [VULN O-16, M-8] No query validation — DROP TABLE, DELETE, etc. all work
    conn = sqlite3.connect("data.db")
    cursor = conn.execute(sql)
    conn.commit()
    return cursor.fetchall()


# Tool registry passed directly to the LLM — all tools, full access
AGENT_TOOLS = [
    {
        "name": "run_shell_command",
        "description": "Run any shell command",
        "parameters": {
            "type": "object",
            "properties": {
                "command": {"type": "string", "description": "Shell command to execute"}
            },
            "required": ["command"]
        },
        "function": run_shell_command
    },
    {
        "name": "read_file",
        "description": "Read any file",
        "parameters": {
            "type": "object",
            "properties": {
                "path": {"type": "string", "description": "File path to read"}
            },
            "required": ["path"]
        },
        "function": read_file
    },
    {
        "name": "send_email",
        "description": "Send an email",
        "parameters": {
            "type": "object",
            "properties": {
                "to": {"type": "string"},
                "subject": {"type": "string"},
                "body": {"type": "string"}
            },
            "required": ["to", "subject", "body"]
        },
        "function": send_email
    },
    {
        "name": "query_database",
        "description": "Query the database",
        "parameters": {
            "type": "object",
            "properties": {
                "sql": {"type": "string", "description": "SQL query to execute"}
            },
            "required": ["sql"]
        },
        "function": query_database
    }
]
