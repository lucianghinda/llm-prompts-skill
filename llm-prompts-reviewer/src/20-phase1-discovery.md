
## Phase 1: Discovery

Map the LLM attack surface before checking defenses. Find and catalog all of the following.

### 1.1 LLM Integration Points
Search for:
- LLM client initialization (`openai`, `anthropic`, `langchain`, `llama_index`, `transformers`,
  `litellm`, `ruby-llm`, `google-generativeai`, `cohere`, etc.)
- API calls to LLM endpoints (`/chat/completions`, `/messages`, `/generate`, `/complete`)
- Prompt construction functions (string concatenation, template rendering, f-strings building prompts)
- Tool/function definitions exposed to the LLM (tool schemas, function calling configs)

### 1.2 System Prompts
Search for:
- System message definitions (`role: "system"`, `system_prompt`, `SystemMessage`, `SYSTEM_PROMPT`)
- Prompt templates (Jinja, ERB, f-string, string interpolation building system instructions)
- Configuration files defining model behavior or instructions

### 1.3 External Data Flows Into Prompts
Search for — each is a distinct injection vector:
- User input inserted into prompts (primary direct injection surface)
- Database content used in prompts (RAG chunks, search results)
- File content read and passed to LLM (documents, uploads, attachments, PDFs)
- Web content fetched and passed to LLM (URLs, scraped pages, API responses)
- Email or message content processed by LLM
- Code, comments, commit messages, or issue bodies analyzed by LLM
- Image or document metadata processed by multimodal models

### 1.4 LLM Output Consumption
Search for — each is a distinct output injection surface:
- LLM output rendered as HTML or Markdown (XSS, img tag exfiltration vectors)
- LLM output executed as code (`eval`, `exec`, `system`, shell commands, database queries)
- LLM output used in further API calls or tool invocations
- LLM output stored and later re-consumed (memory, conversation history, RAG re-indexing)

### 1.5 Agent Architecture (if applicable)
Search for:
- Tool/function calling patterns (what tools the LLM can invoke and with what scope)
- Multi-step reasoning loops (ReAct, chain-of-thought with actions, agentic workflows)
- Agent memory or context persistence (vector stores, session history, external memory)
- Agent-to-agent communication or sub-agent delegation

**Discovery Output Format:**

```
DISCOVERY INVENTORY
===================
[D1] <file>:<line> — <description> — Type: <integration|prompt|input-flow|output-flow|agent>
[D2] <file>:<line> — ...
```

**STOP.** Share the discovery inventory with the user via AskUserQuestion. Ask if there are
integration points they know about that were not found. Confirm before proceeding to Phase 2.

---
