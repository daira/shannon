---
name: Review shell scripts and heredoc bodies for quoting
description: Always review shell scripts for variable quoting issues before committing. Also: in single-quoted heredocs (`<<'EOF'`), do NOT backslash-escape backticks or dollar-signs — single quotes already prevent shell expansion, so the backslash becomes literal. Use bare characters inside `<<'EOF'` heredoc bodies; only escape inside `<<EOF` (no quotes) heredocs where interpolation DOES happen. Also: wrap exit-code-sensitive pipelines in `(set -o pipefail && ...)` so a trailing filter like `| head` doesn't mask an upstream command's non-zero exit. A check that exists to gate a later mutating command must be &&-wired to it with rc-meaningful output, or the mutation issued as a separate call after reading the check — `check; mutate` mutates regardless.
type: feedback
---

When creating or editing shell scripts that will be committed, always review them for quoting
issues before committing.

**Why:** Unquoted variables cause word-splitting and globbing bugs that are easy to miss.
These are especially dangerous in scripts that handle file paths or branch names.

**How to apply:** After writing a shell script, scan every use of `$VAR` and `$(...)` for
whether it needs double-quoting. Key rules:
- RHS of `VAR=` assignments don't need quoting (no word-splitting in assignments)
- Inside double-quoted strings, `$VAR` expands without word-splitting (safe)
- Everywhere else (arguments, `for` loops, `test`/`[` expressions), `"$VAR"` is needed
- `"$(command)"` is needed when used as an argument

## Heredoc bodies and the single-quote rule

When passing long strings via heredoc (common in
`git commit -m "$(cat <<'EOF'\n...\nEOF\n)"`), pay attention to the heredoc terminator form:

- `<<'EOF'` — **single-quoted**. No shell expansion happens in the body. Backticks, `$VAR`,
  and `$(cmd)` are ALL literal. Do NOT backslash-escape them; the backslash becomes part of
  the literal output.
- `<<EOF` — **unquoted**. Shell expansion DOES happen: backticks run command substitution,
  `$VAR` expands. You must backslash-escape any backtick / dollar-sign you want to appear
  literally.

Recurring mistake pattern: using `<<'EOF'` (single-quoted) but still writing `\`foo\``. The
agent's trained priors on backslash-escaping backticks (which is correct in unquoted heredocs,
in `bash -c "..."` args, and in double-quoted shell strings) can fire even inside `<<'EOF'`
where they shouldn't. The output contains literal `\`foo\`` (backslashes preserved), which is
ugly in rendered Markdown and `git log`.

**How to apply:** Before writing a heredoc body with backticks, identify the heredoc style:
- If `<<'EOF'` / `<<"EOF"`: write bare backticks.
- If `<<EOF`: escape backticks with `\``.

When in doubt, prefer `<<'EOF'` (single-quoted) — it's the safe default for prose that
contains code snippets, because you don't accidentally run command substitution.

## Apostrophes inside single-quoted shell arguments

A sibling gotcha that bites in practice: passing a multi-line JSON string as a single-quoted
argument to `jq -n '...'` (or to any command that takes a single-quoted shell argument). If a
JSON string literal inside contains an apostrophe — e.g., `"other agents' scratch"` — that
apostrophe closes the outer single-quoted shell argument. Everything after is parsed as bash,
including backticks (command substitution) and parentheses (subshells). The typical failure
mode is a confusing `syntax error near unexpected token \`(\`` at a paren that originally
belonged to natural prose.

Three fixes, in order of preference:

1. **Rephrase to avoid the apostrophe.** Often clean: *"other agents' scratch"* → *"scratch
   from other agents"*. Saxon-genitive apostrophes usually have a natural rephrasing that is
   no harder to read.
2. **Use a single-quoted heredoc fed to `jq -f`** when the JSON is multi-line and the prose
   genuinely needs apostrophes:
   ```bash
   jq -n -f <(cat <<'EOF'
   { hookSpecificOutput: { additionalContext: "text with apostrophes" } }
   EOF
   )
   ```
   The single-quoted `'EOF'` prevents shell expansion, so apostrophes (and `$`, backticks)
   inside the body are literal.
3. **Escape with `'\''`** for short cases. `'\''` is the standard shell idiom for embedding a
   single quote inside a single-quoted string: close the quote, escape the literal quote,
   re-open the quote.

**When to audit**: any time an `additionalContext` / commit-message / multi-line natural-prose
string passed to `jq -n '...'` or `bash -c '...'` grows past a one-liner. Scan the literal for
apostrophes before running. The pipe-test recipe (per the `/update-config` skill) catches this
in seconds — the script fails to parse and surfaces as `syntax error near unexpected token …`
at the next bash-significant character.

**Real instance** that motivated this section: a `PreToolUse` hook script's
`additionalContext` text contained the possessive form *"other agents' scratch"*; the
apostrophe closed the `jq -n '...'` single-quoted argument, and the next paren in the prose
was interpreted as a bash subshell open, producing the misleading syntax error above. Every
subsequent Bash command failed the hook until the apostrophe was rephrased out.

## Comparing two text artifacts (freshness checks): newline-robust and injection-safe

For a fetch-before-patch freshness gate (does the live copy still match my saved copy?), a
plain `diff a b` signals a **false positive on a trailing-newline-only difference** (GitHub
and many editors add/strip a final newline). Gate instead on command-substitution equality:

```bash
if [[ "$(cat -- posted.md)" = "$(cat -- live.md)" ]]; then echo unchanged; else diff -- posted.md live.md; fi
```

- **Newline-robust:** `$(…)` strips *trailing* newlines from both sides, so the
  trailing-newline noise vanishes; internal edits still register.
- **Injection-safe:** `$(cat f)` captures stdout as a *string* that is never re-parsed as
  shell — content like `$(rm -rf ~)`, backticks, `;`, `&&` is inert data. Double-quoting the
  result stops word-splitting/globbing. (The only way content becomes code is `eval`, which we
  never do.)
- **Quote the RHS in `[[ … ]]`** — an *unquoted* RHS makes `=` do glob/pattern matching, a
  real bug. Prefer `[[ ]]` (bash/zsh) over single-bracket `[ ]`, whose 3-arg parsing can slip
  on an operand that looks like an operator (`=`, `(`, `!`, `-n`); POSIX fallback is the
  `x`-prefix `[ "x$a" = "x$b" ]`.
- Caveats: command substitution strips NUL bytes (irrelevant for text bodies, would matter for
  binary); use `cat -- "$file"` when the path is a variable ([[feedback_shell_double_dash]]).
- **Gate on the equality; show `diff` only on a real difference** — then the diff's harmless
  trailing-newline line only appears beside genuine edits. This is the freshness-diff step of
  [[feedback_fetch_before_patch_user_artifacts]].

## Pipelines and exit codes (`set -o pipefail`)

A pipeline's exit status is that of its **last** command only, so a failure in an earlier
stage is silently masked by a trailing filter. Classic trap: `some-check | head` (or `| tail`,
`| grep`) reports the filter's success even when `some-check` failed — and an `echo "exit=$?"`
after the pipe reads the filter's status, not the check's. This hides real failures in verify
/ build / lint steps.

**How to apply:** when a piped command's exit status matters, run the pipeline under
`pipefail` so `$?` reflects the first failing stage. Wrap it in a subshell so the option
doesn't leak into the surrounding shell:

```bash
(set -o pipefail && some-check | head)
echo "exit=$?"   # reflects some-check, not head
```

Alternatives: capture the exit without piping (`some-check; rc=$?`), or read
`${PIPESTATUS[0]}` (bash) right after the pipeline.

**When to audit:** any pipeline whose first stage is a check / verify / build / lint whose
success you then test or report — `verify | head`, `build 2>&1 | tail`, etc. If you pipe to a
filter only to shorten output but still care whether the command succeeded, reach for
`pipefail`.

## `;`-chaining swallows errors; the standing form is `(set -o pipefail && … && …)`

A user directive (2026-08-07, stated twice in consecutive turns): in agent-issued Bash calls,
`;` between steps lets an earlier step fail invisibly — the tool result shows only the last
command's status, and a failed probe's empty output reads as a clean result. Two rules:

1. **Chain with `&&`, not `;`, in every multi-step Bash call** — including "display-only"
   probe batches (`ls X; other-tool view Y`). If steps are genuinely independent and both must
   run regardless, issue separate tool calls rather than `;`-gluing them.
2. **Wrap every multi-step or piped call as `(set -o pipefail && cmd1 && cmd2 | filter)`** —
   the subshell + pipefail + `&&` form, consistently, not only for builds. This is the
   build-logging memory's canonical pattern promoted to the default for all shell work.

**Caveat — SIGPIPE under pipefail (exit 141):** with `pipefail` on, a deliberately-truncating
filter (`| head`, `| head -N`) kills the upstream writer with SIGPIPE once it stops reading,
so the pipeline reports exit 141 (128+13) although nothing went wrong — and in an `&&` chain
the remaining steps are then silently skipped. Prefer producer-side truncation so no pipe is
cut (`git log -n 8`, `grep -m 20`, `--stat` limits); `tail -N` is also safe (it reads the
whole stream). Treat 141 as benign only when the pipeline visibly ends in an intentional
truncator; any other nonzero is real.

**A check that gates a mutation must be wired to it.** When a command sequence contains a
verification step whose purpose is to decide whether a later MUTATING step may run (a
freshness diff before a PATCH, a dry-run before an apply), `;` between them makes the check
decorative: the mutation runs regardless of what the check found, and piping the check into
`head` additionally destroys its exit code. Real instance (2026-08-15): a fetch-before-patch
freshness diff batched as `… | diff base - | head -8; gh pr edit …` — the user had edited the
PR body concurrently and had to reject the command by hand; nothing in the command could have
stopped the clobber. Either `&&`-wire the gate with rc-meaningful output (no truncating pipe
on the check), or issue the mutation as a separate command after reading the check's output.
See also `feedback_fetch_before_patch_user_artifacts.md` §5 for the PATCH-specific form.

**Heredoc trap — the line after the terminator is sequential.** In
`a && b && python3 - <<'EOF'` followed by the heredoc body, `EOF`, and then further commands
on their own lines, those further commands are NOT part of the `&&` chain — they run
unconditionally, like a `;`. Real instance: a fetch-verify-compose chain aborted correctly at
the verify step, but a `gh api PATCH -f body="$(cat composed-file)"` on the line after the
heredoc still ran, and since the compose never produced the file, the `$(cat …)` was empty and
the PATCH blanked a PR description (recovered from the pre-patch fetch). Put the continuation
on the SAME line as the heredoc-feeding command (`python3 - <<'EOF' && next-cmd …`, body
afterwards), and prefer `--input <file>` over `-f body="$(cat file)"` so a missing file is a
hard error instead of an empty payload.

**Corollary — emptiness needs a failure-distinguisher:** when a conclusion rests on a command
producing *no* output (a "no dangling references" grep sweep, a "no stale names" audit), a
broken command and a clean result look identical. Handle the no-match exit explicitly (grep rc
1 = clean, rc > 1 = error → abort) and/or run a positive control (the same machinery must FIND
a known-present name) before reporting "clean". Real instance: a deleted-declarations
reference sweep inside a `while … done` loop chained with `;` — the CLEAN verdict initially
rested on silence that a wrong ref name or bad pattern file would also have produced; it was
re-run with rc handling plus a known-present control before being relied on.
