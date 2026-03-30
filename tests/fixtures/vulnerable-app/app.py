"""
Vulnerable LLM chatbot — deliberately insecure for testing purposes.
DO NOT deploy this code. It contains intentional security vulnerabilities.
"""
import os
import sqlite3
from flask import Flask, request, jsonify
import openai

app = Flask(__name__)
openai.api_key = os.environ.get("OPENAI_API_KEY")

# [VULN O-17, M-10] Full admin DB connection used for all LLM queries
DB_CONN = sqlite3.connect("data.db", check_same_thread=False)
DB_CONN.execute("""
    CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT, email TEXT, ssn TEXT)
""")
DB_CONN.execute("""
    CREATE TABLE IF NOT EXISTS admin_secrets (key TEXT, value TEXT)
""")
DB_CONN.commit()


def get_llm_response(user_message: str) -> str:
    # [VULN O-7, O-10] Direct string concatenation — no structured separation
    # User input and system instructions are mixed in a single string
    prompt = (
        "You are a helpful customer service assistant for AcmeCorp. "
        "Answer customer questions helpfully.\n\n"
        "Customer message: " + user_message  # Injection point
    )

    # [VULN O-8, M-2] No behavioral constraints, no refusal instructions
    # No instruction to treat user input as data only
    response = openai.ChatCompletion.create(
        model="gpt-4",
        messages=[{"role": "user", "content": prompt}],
        temperature=0.7,
    )
    return response.choices[0].message.content


@app.route("/chat", methods=["POST"])
def chat():
    data = request.json
    user_message = data.get("message", "")

    # [VULN O-1, O-2, O-5] No input validation whatsoever
    # No pattern detection, no length limits, no encoding checks

    response_text = get_llm_response(user_message)

    # [VULN O-11] No output validation before returning
    # [VULN O-15] Response returned as raw HTML — will be rendered by frontend
    return jsonify({
        "response": response_text,
        "html": f"<div class='response'>{response_text}</div>"  # XSS via LLM output
    })


@app.route("/calculate", methods=["POST"])
def calculate():
    """'Smart' calculator that uses LLM to parse and compute expressions."""
    data = request.json
    expression = data.get("expr", "")

    # [VULN O-1] No validation on expression
    llm_response = get_llm_response(
        f"Convert this math expression to Python and return only the code: {expression}"
    )

    # [VULN O-16, M-8] Direct eval() of LLM output — arbitrary code execution
    result = eval(llm_response)
    return jsonify({"result": result})


@app.route("/search", methods=["POST"])
def search():
    """Search customer database using natural language."""
    data = request.json
    query = data.get("query", "")

    # [VULN O-1] No validation on query
    llm_sql = get_llm_response(
        f"Convert this natural language query to SQL for the users table: {query}"
    )

    # [VULN O-16] LLM-generated SQL executed directly against DB with full access
    # [VULN O-17, M-10] Admin connection can access all tables including admin_secrets
    cursor = DB_CONN.execute(llm_sql)
    rows = cursor.fetchall()
    return jsonify({"results": rows})


@app.route("/summarize_page", methods=["POST"])
def summarize_page():
    """Summarize content from a URL — indirect injection vector."""
    import urllib.request
    data = request.json
    url = data.get("url", "")

    # [VULN O-10] External web content fetched and passed directly to LLM
    # No sanitization — injected instructions in web pages will be followed
    page_content = urllib.request.urlopen(url).read().decode("utf-8")

    # [VULN O-7] External content NOT marked as untrusted — mixed with instructions
    prompt = "Summarize this page: " + page_content
    summary = get_llm_response(prompt)

    # [VULN O-21] No logging of this interaction for security analysis
    return jsonify({"summary": summary})
