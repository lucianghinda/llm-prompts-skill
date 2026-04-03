
## Step 0: Determine Review Scope

If not clear from context, ask the user which mode to use:

| Mode         | What to analyze            | How to gather code |
|--------------|---------------------------|--------------------|
| **Codebase** | Entire repository          | Glob + Grep for LLM integration points |
| **Branch**   | Changes on current branch vs base | `git diff $(git merge-base HEAD main)...HEAD` |
| **Commit**   | A specific commit          | `git diff <commit>^..<commit>` |
| **Files**    | Specific files/directories | Read the named files directly |

For Branch/Commit modes, also read surrounding context of changed files (not just the diff
lines) since injection vulnerabilities often depend on how the broader function handles
untrusted input.

**STOP.** If the scope is ambiguous, confirm with the user via AskUserQuestion before proceeding.

---
