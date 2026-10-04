---
name: Review shell scripts and heredoc bodies for quoting
description: Review shell scripts for quoting before committing: run shellcheck, then check each expansion. Where one language is nested in another (a script in a heredoc of another script, Makefile recipes, GitHub Actions `${{ }}` expressions, m4, `bash -c` strings), list the layers that the code passes through and check its quoting at each. In a quoted heredoc (`<<'EOF'`), write backticks and `$` bare; a backslash becomes literal. Chain steps with `&&`, run a pipeline whose status matters as `(set -o pipefail && …)`, wire a check that gates a mutation to it with `&&` (`check; mutate` mutates regardless), and give a conclusion drawn from empty output a positive control.
type: feedback
---

When creating or editing shell scripts that will be committed, review them for quoting first.
Unquoted variables cause word-splitting and globbing bugs that are easy to miss, especially in
scripts that handle file paths or branch names.

**How to apply:** run `shellcheck <script>` where it is installed and fix what it reports, then scan
every use of `$VAR` and `$(...)` for whether it needs double-quoting, since shellcheck does not see
every context. Key rules:
- RHS of `VAR=` assignments don't need quoting (no word-splitting in assignments)
- Inside double-quoted strings, `$VAR` expands without word-splitting (safe)
- Everywhere else (arguments, `for` loops, `test`/`[` expressions), `"$VAR"` is needed
- `"$(command)"` is needed when used as an argument

## Nested languages: every layer has its own quoting

Be particularly careful wherever code in one language is embedded in another. Each layer has its
own quoting and expansion rules, so a character that is inert in one layer can be live in the next.
A script that looks right at the layer you are reading can be wrong at the layer that runs it.
For example:

- **A script in a heredoc of another script.** `<<'EOF'` passes the body through untouched;
  `<<EOF` expands `$`, backticks, and backslashes first (see the next section).
- **Recipes in a Makefile.** make expands `$` before the shell sees the line, so a shell variable
  is written `$$var`. Each recipe line runs in its own shell unless lines are joined with `\` or
  `.ONESHELL` is set.
- **GitHub Actions workflows.** A `${{ … }}` expression is substituted into the script's text
  before the shell runs it, so an expression that carries untrusted input, such as a pull
  request's title or a branch name, becomes shell code. Pass the value through `env:` and refer to
  it as `"$VAR"`; workflow linters flag this as template injection.
- **m4,** as in autoconf scripts. Its quotes are `` ` `` and `'`, `$1` to `$9` are macro
  arguments, and `#` starts a comment, so shell code in a macro body can change meaning.
- **Command strings run by another program:** `bash -c '…'`, `ssh host '…'`, `find … -exec sh -c`,
  `xargs`, and a Python, awk, or jq program inside a shell string.

**How to apply:** before writing the inner code, list the layers that it passes through, outermost
first, and what each interprets. Then check `$`, backticks, both kinds of quote, backslashes, `#`,
and newlines against every layer. Where possible, remove a layer instead: a separate script file, a
quoted heredoc, `env:` in a workflow, or `-f file` for awk and jq.

## Heredocs: quoted or not

A quoted heredoc (`<<'EOF'` or `<<"EOF"`) passes its body through literally, so backticks, `$VAR`,
and `$(cmd)` are written bare: a backslash before them appears in the output. An unquoted one
(`<<EOF`) expands them first, so escape any that should appear literally. The habit of escaping
backticks, right in an unquoted heredoc or a double-quoted string, tends to fire inside `<<'EOF'`
too, and leaves `\`foo\`` in a commit message or rendered Markdown. Prefer `<<'EOF'` for prose that
contains code, which then cannot run a command substitution by accident.

## Apostrophes inside single-quoted arguments

An apostrophe inside a single-quoted shell argument closes it: for example, a JSON string passed as
`jq -n '…'` that contains `"other agents' scratch"`. Everything after it is parsed as shell, and the
error points at a later token, typically `syntax error near unexpected token '('`. A hook script
with this bug fails on every tool call until it is fixed. Fixes, in order of preference:

1. **Rephrase to avoid the apostrophe:** "scratch from other agents".
2. **Feed the text through a quoted heredoc** when it is multi-line and needs the apostrophe:
   ```bash
   jq -n -f <(cat <<'EOF'
   { hookSpecificOutput: { additionalContext: "text with apostrophes" } }
   EOF
   )
   ```
3. **Write `'\''`** for short cases: close the quote, add an escaped quote, and reopen it.

Check such a string for apostrophes whenever it grows past one line.

## Comparing two texts: newline-robust and injection-safe

To check whether a live copy still matches a saved one, compare them with command substitution.
A plain `diff` also reports a difference in the final newline alone, which GitHub and many editors
add or strip:

```bash
if [[ "$(cat -- saved.md)" = "$(cat -- live.md)" ]]; then echo unchanged; else diff -- saved.md live.md; fi
```

`$(…)` strips only trailing newlines, and its result is data that is never parsed as shell, so
content such as `$(rm -rf ~)` is inert. Quote the right-hand side of `[[ … = … ]]`, which otherwise
matches as a glob pattern; in POSIX `[ ]`, write `[ "x$a" = "x$b" ]`. Show the `diff` only when the
comparison fails. Command substitution drops NUL bytes, so this is for text, not binary files.

## Exit statuses: `&&` and `pipefail`

A pipeline's status is its last command's, so `check | head` reports success when `check` failed,
and `echo "rc=$?"` after it reads `head`'s status. And `;` between commands lets every failure but
the last pass silently, so a failed probe's empty output reads as a clean result. In a multi-step
command:

1. **Chain the steps with `&&`.** If they are independent and must all run, issue them as separate
   tool calls rather than joining them with `;`.
2. **Run a pipeline whose first stage's status matters as `(set -o pipefail && cmd | filter)`.**
   The subshell keeps the option from leaking. `${PIPESTATUS[0]}` is the bash alternative.
3. **Truncate at the producer.** Under `pipefail`, a truncating `| head` kills its producer with
   SIGPIPE, so the pipeline exits 141 and the rest of an `&&` chain is skipped. Use
   `git log -n 8`, `grep -m 20`, or `tail`, which reads the whole stream.

Three consequences:

- **A check that gates a mutation must be wired to it,** with `&&` and an exit status that means
  something, or the mutation must be issued as a separate command after reading the check. With
  `check; mutate`, or a check piped into `head`, the mutation runs whatever the check found. A
  freshness diff batched that way once let a concurrently edited PR description be overwritten.
- **A command on the line after a heredoc's terminator runs unconditionally,** outside the `&&`
  chain of the command that the heredoc feeds. Put the continuation on that command's line
  (`python3 - <<'EOF' && next …`, with the body below). Prefer `--input file` to
  `-f body="$(cat file)"`, so that a missing file is an error rather than an empty payload; an empty
  payload once blanked a PR description.
- **A conclusion drawn from empty output needs a control.** When a conclusion rests on a command
  printing nothing, as in a search for stale names, a broken command looks the same as a clean
  result. Handle the no-match status explicitly (for `grep`, 1 is no match and more than 1 is an
  error), and check that the same command finds something known to be present.
