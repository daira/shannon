#!/usr/bin/env bash
# check-tmp-path.sh — PreToolUse hook for Bash commands touching /tmp/.
#
# Reads PreToolUse JSON on stdin; emits `hookSpecificOutput.additionalContext`
# with a reminder when a Bash command references `/tmp/` for anything other
# than Claude Code's own scratch directory (`/tmp/claude-*`).
#
# Background: files the agent creates that don't belong in version control
# should go under the project's `work/` (temporary files: build output, PR /
# commit message drafts, intermediate diffs) or `keep/` (durable working
# drafts), not under `/tmp/`. The scratch dir is named `work/`, not `tmp/`,
# on purpose: `tmp` reads as disposable and invites reflexive `rm -rf`.
# See `feedback_repo_scratch_dirs.md` and `feedback_filesystem_scope.md`
# for the underlying rules. `/tmp/` is shared with other processes (and other
# Claude sessions); using it risks cross-pollination, accidental cleanup, and
# false-positive matches from other agents' debris.
#
# Exception: `/tmp/claude-*` paths are Claude Code's own scratch (used for
# persisted tool-result files, etc.) and the agent legitimately reads from
# them. The hook exempts those from the reminder.
#
# Always exits 0 (non-blocking). The hook injects a reminder; it does not
# gate the command. The malformed-input case (bad JSON on stdin) is
# load-bearing — the script must exit 0 with no output rather than blocking
# the tool, since a blocking failure would silently break every Bash command.
#
# Invocation (from a `PreToolUse` entry in `settings.json` with
# `matcher: "Bash"`):
#   {"type": "command", "command": "exec ~/.claude/check-tmp-path.sh"}
#
# See also: the reminder text below duplicates the explanation in the
# memory file `feedback_repo_scratch_dirs.md` (rationale paragraph: "When
# asking, explain why the convention is a good idea ..."). Edits to
# the rationale here must be propagated there, and vice versa.

set -uo pipefail  # NOT -e: absorb tool errors and always exit 0

cmd=$(jq -r '.tool_input.command // ""' 2>/dev/null) || cmd=""

case "$cmd" in
    *"/tmp/claude-"*)
        # Claude Code's own scratch directory — exempt.
        ;;
    *"/tmp/"*|*" /tmp "*|*"=/tmp/"*|*"=/tmp "*)
        jq -n '{
            hookSpecificOutput: {
                hookEventName: "PreToolUse",
                additionalContext: "Reminder: files the agent creates that don'\''t belong in version control go under the project work/ directory (temporary files such as build output, PR/commit message drafts, intermediate diffs, etc.) or keep/ directory (durable working drafts to retain across sessions), not under /tmp/. See `feedback_repo_scratch_dirs.md` and `feedback_filesystem_scope.md`. **NEVER `rm -rf work/` or `rm -rf keep/` — or any project directory. They usually pre-exist your `mkdir -p` and hold the user'\''s OWN files; the name does not make the dir yours. To clean up scratch you created, `rm -f` ONLY the specific files you created, by exact path (e.g. `rm -f work/mything.log`), never the dir.** The scratch dir is named work/ (not tmp/) on purpose: `tmp` reads as disposable and invites reflexive deletion. **If <project>/work/ does not yet exist, `mkdir -p <project>/work/` first — do NOT fall back to /tmp/ just because the local work/ is missing.** Before creating files there, verify that work/ and keep/ are gitignored — `git check-ignore work/ keep/`. If they are not gitignored, ASK the user whether to (a) add work/ and keep/ to the user-global ~/.gitignore, (b) add them to the project .gitignore, or (c) use a different scratch location. Do not silently add to either gitignore. When asking, give the user the rationale for the convention: /tmp/ is shared across processes and Claude sessions, so files there can collide with scratch from other agents, get accidentally cleaned up by the OS, and surface as false-positive matches in broad searches. <project>/work/ keeps scratch project-scoped, isolated from other sessions, easier to recover after a wrong call, and gitignored so scratch never accidentally commits — while <project>/keep/ holds durable working drafts that the user wants to retain across sessions. Recipe (once gitignore is confirmed): `mkdir -p <project>/work/ && mktemp -p <project>/work/ <prefix>.XXXXXX`. If a session-isolated /tmp/ location is genuinely needed (rare), use `mktemp -d /tmp/claude-session-XXXXXX` so other Claude sessions cannot collide. This reminder is informational; the command will run regardless."
            }
        }' 2>/dev/null
        ;;
esac

exit 0
