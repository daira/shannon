---
name: Review shell scripts and heredoc bodies for quoting
description: Always review shell scripts for variable quoting issues before committing. Also: in single-quoted heredocs (`<<'EOF'`), do NOT backslash-escape backticks or dollar-signs — single quotes already prevent shell expansion, so the backslash becomes literal. Use bare characters inside `<<'EOF'` heredoc bodies; only escape inside `<<EOF` (no quotes) heredocs where interpolation DOES happen.
type: feedback
---

When creating or editing shell scripts that will be committed, always review them for quoting issues before committing.

**Why:** Unquoted variables cause word-splitting and globbing bugs that are easy to miss. These are especially dangerous in scripts that handle file paths or branch names.

**How to apply:** After writing a shell script, scan every use of `$VAR` and `$(...)` for whether it needs double-quoting. Key rules:
- RHS of `VAR=` assignments don't need quoting (no word-splitting in assignments)
- Inside double-quoted strings, `$VAR` expands without word-splitting (safe)
- Everywhere else (arguments, `for` loops, `test`/`[` expressions), `"$VAR"` is needed
- `"$(command)"` is needed when used as an argument

## Heredoc bodies and the single-quote rule

When passing long strings via heredoc (common in `git commit -m "$(cat <<'EOF'\n...\nEOF\n)"`), pay attention to the heredoc terminator form:

- `<<'EOF'` — **single-quoted**. No shell expansion happens in the body. Backticks, `$VAR`, and `$(cmd)` are ALL literal. Do NOT backslash-escape them; the backslash becomes part of the literal output.
- `<<EOF` — **unquoted**. Shell expansion DOES happen: backticks run command substitution, `$VAR` expands. You must backslash-escape any backtick / dollar-sign you want to appear literally.

Recurring mistake pattern: using `<<'EOF'` (single-quoted) but still writing `\`foo\``. The agent's trained priors on backslash-escaping backticks (which is correct in unquoted heredocs, in `bash -c "..."` args, and in double-quoted shell strings) can fire even inside `<<'EOF'` where they shouldn't. The output contains literal `\`foo\`` (backslashes preserved), which is ugly in rendered Markdown and `git log`.

**How to apply:** Before writing a heredoc body with backticks, identify the heredoc style:
- If `<<'EOF'` / `<<"EOF"`: write bare backticks.
- If `<<EOF`: escape backticks with `\``.

When in doubt, prefer `<<'EOF'` (single-quoted) — it's the safe default for prose that contains code snippets, because you don't accidentally run command substitution.

## Apostrophes inside single-quoted shell arguments

A sibling gotcha that bites in practice: passing a multi-line JSON string as a single-quoted argument to `jq -n '...'` (or to any command that takes a single-quoted shell argument). If a JSON string literal inside contains an apostrophe — e.g., `"other agents' scratch"` — that apostrophe closes the outer single-quoted shell argument. Everything after is parsed as bash, including backticks (command substitution) and parentheses (subshells). The typical failure mode is a confusing `syntax error near unexpected token \`(\`` at a paren that originally belonged to natural prose.

Three fixes, in order of preference:

1. **Rephrase to avoid the apostrophe.** Often clean: *"other agents' scratch"* → *"scratch from other agents"*. Saxon-genitive apostrophes usually have a natural rephrasing that is no harder to read.
2. **Use a single-quoted heredoc fed to `jq -f`** when the JSON is multi-line and the prose genuinely needs apostrophes:
   ```bash
   jq -n -f <(cat <<'EOF'
   { hookSpecificOutput: { additionalContext: "text with apostrophes" } }
   EOF
   )
   ```
   The single-quoted `'EOF'` prevents shell expansion, so apostrophes (and `$`, backticks) inside the body are literal.
3. **Escape with `'\''`** for short cases. `'\''` is the standard shell idiom for embedding a single quote inside a single-quoted string: close the quote, escape the literal quote, re-open the quote.

**When to audit**: any time an `additionalContext` / commit-message / multi-line natural-prose string passed to `jq -n '...'` or `bash -c '...'` grows past a one-liner. Scan the literal for apostrophes before running. The pipe-test recipe (per the `/update-config` skill) catches this in seconds — the script fails to parse and surfaces as `syntax error near unexpected token …` at the next bash-significant character.

**Real instance** that motivated this section: a `PreToolUse` hook script's `additionalContext` text contained the possessive form *"other agents' scratch"*; the apostrophe closed the `jq -n '...'` single-quoted argument, and the next paren in the prose was interpreted as a bash subshell open, producing the misleading syntax error above. Every subsequent Bash command failed the hook until the apostrophe was rephrased out.
