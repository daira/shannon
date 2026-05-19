#!/usr/bin/env bash
# check-memory-synthesis.sh — PreToolUse hook for Write/Edit on memory files.
#
# Reads PreToolUse JSON on stdin; emits `hookSpecificOutput.additionalContext`
# with a path-aware synthesis-check reminder when the write target is under
# any `.claude/memory/` directory (the global `~/.claude/memory/` or a
# project-specific `~/.claude/projects/<slug>/memory/`).
#
# Four path cases are recognised:
#
#   `MEMORY.md` →
#     No output (the index file is not a body memory; the synthesis
#     question does not apply to index entries).
#
#   `user_*.md` →
#     Path-aware reminder — the synthesis half applies ("is this
#     addition really at home in this user profile, or does it belong
#     in a feedback memory?") but the sanitization half is dropped,
#     since named attribution is the point of user profile memories.
#
#   `~/.claude/projects/*/memory/*.md` →
#     project-scoped-memory variant — synthesis check PLUS a "should
#     this be global?" reminder, since a lesson with cross-project
#     applicability belongs under `~/.claude/memory/` instead; no
#     sanitization reminder since this is a project-scoped memory.
#
#   any other `*.md` →
#     default reminder (synthesis + sanitization).
#
# `MEMORY.md` exclusion lives in the script rather than in the hook entry's
# `if` field because Claude Code's permission-rule syntax supports prefix
# matches but not negation. Expressing "all memory paths EXCEPT
# `MEMORY.md`" in `if` would require enumerating the file-name prefixes
# that DO match, which is brittle.
#
# Always exits 0 so the write proceeds either way; the hook injects a
# reminder, it does not gate. The malformed-input case (bad JSON on stdin)
# is load-bearing — the script must still exit 0 with no output rather
# than blocking the tool, since a blocking failure would silently break
# memory writes for the user.
#
# Invocation (from a `PreToolUse` entry in `settings.json`):
#   {"type": "command", "command": "exec ~/.claude/check-memory-synthesis.sh"}

set -uo pipefail  # NOT -e: absorb tool errors and always exit 0

file_path=$(jq -r '.tool_input.file_path // ""' 2>/dev/null) || file_path=""

case "$file_path" in
    *.claude/memory/MEMORY.md|*.claude/projects/*/memory/MEMORY.md|*/memory-seed/MEMORY.md)
        # Index file — no reminder.
        ;;
    *.claude/memory/user_*.md|*.claude/projects/*/memory/user_*.md|*/memory-seed/user_*.md)
        # User profile memory — synthesis half only, sanitization dropped.
        jq -n '{
            hookSpecificOutput: {
                hookEventName: "PreToolUse",
                additionalContext: "Synthesis check before this user-profile-memory edit: is this addition really at home in this `user_*.md`, or does it belong in a feedback memory? See `feedback_rich_memory_summaries.md` for the synthesis rule. Named attribution is the point of user profile memories, so the sanitization rule in `feedback_external_reports.md` does not apply here."
            }
        }' 2>/dev/null
        ;;
    *.claude/projects/*/memory/*.md)
        # Project-scoped memory body — synthesis check PLUS project-vs-global
        # check. This case must come BEFORE the generic memory-body case so
        # that project memories pick up the cross-project applicability
        # question. A common failure is writing a generally-applicable
        # lesson to a project memory path and only catching it on review (or
        # later, in another project where the lesson is no longer visible).
        jq -n '{
            hookSpecificOutput: {
                hookEventName: "PreToolUse",
                additionalContext: "Synthesis check before this project-scoped-memory write or edit:\n  1. Project-scope check: is this content genuinely *project-specific*? If the lesson would apply across other projects or codebases, it belongs in `~/.claude/memory/` (global) instead. Check whether a closely-related global memory already exists before deciding.\n  2. Synthesis check: scan this project'\''s MEMORY.md for any existing memory this content (whether a new file or an addition) could fit better in, per `feedback_rich_memory_summaries.md` §3. Cite the closest existing memories you checked, or explicitly note that none fit, before proceeding."
            }
        }' 2>/dev/null
        ;;
    *.claude/memory/*.md|*/memory-seed/*.md)
        # Regular memory body — full reminder. Includes Shannon-side seed
        # sources (`<shannon-checkout>/memory-seed/<name>.md`), so when a
        # maintainer's Claude instance edits the seed source directly, it
        # gets the same synthesis-check coverage as when a user's Claude
        # edits the symlinked or copied install at `~/.claude/memory/<name>.md`.
        jq -n '{
            hookSpecificOutput: {
                hookEventName: "PreToolUse",
                additionalContext: "Synthesis check before this memory-file write or edit: scan MEMORY.md for any existing memory that this content (whether a whole new file or an addition to this one) could fit better in, per `feedback_rich_memory_summaries.md` §3. The question is the same for Write (is there a better host memory than a new file?) and for Edit (is the addition really at home in *this* memory, or does it belong elsewhere?). Cite the closest existing memories you checked, or explicitly note that none fit, before proceeding. For global memories under `~/.claude/memory/`, also confirm sanitization per `feedback_external_reports.md` — strip user / project / path identifiers."
            }
        }' 2>/dev/null
        ;;
esac

exit 0
