
## Phase 0: Gather Requirements

Ask the user the following in a single `AskUserQuestion`. Collect all answers before
proceeding — do not ask one question at a time.

```
To build your secure LLM integration, please answer these questions:

1. ROLE: What does the LLM act as?
   (e.g., "customer service assistant for AcmeCorp", "code review bot", "document summarizer")

2. TASK: What specific task does it perform?
   (e.g., "answer questions about our product catalog", "summarize uploaded PDFs",
    "triage GitHub issues")

3. DATA SOURCES — which of these flow into your prompts? (check all that apply)
   [ ] User text input (chat messages, form fields)
   [ ] Database / RAG content (search results, knowledge base chunks)
   [ ] File uploads (PDFs, Word docs, spreadsheets)
   [ ] Web content (fetched URLs, scraped pages)
   [ ] Email or message content
   [ ] Code, commits, or issue bodies
   [ ] Images or other multimodal input

4. OUTPUT USAGE — how is the LLM output consumed? (check all that apply)
   [ ] Displayed to user as plain text
   [ ] Rendered as HTML or Markdown
   [ ] Used in further API calls or tool invocations
   [ ] Stored in database or memory for later use
   [ ] Executed as code (eval, shell, SQL)
   [ ] Triggers real-world actions (send email, purchase, delete)

5. LANGUAGE: Python / JavaScript (TypeScript) / Ruby / Go / Other (specify)

6. ARCHITECTURE — does your integration include any of these?
   [ ] RAG pipeline (vector store, semantic search, document retrieval)
   [ ] Tool / function calling (LLM can invoke functions)
   [ ] Agent loop (ReAct, chain-of-thought with actions, multi-step reasoning)
   [ ] Multi-turn conversation (persistent session history)
```

**STOP.** Wait for the user's answers. Confirm your understanding before proceeding to Phase 1.
Write back a 3-line summary: "Role: X / Task: Y / Data: [list] / Output: [list] / Language: Z / Architecture: [list]"
Ask: "Does this look right? Any corrections before I generate the prompt?"

---
