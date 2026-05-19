#!/usr/bin/env bash
# save-session.sh — snapshot the current session's transcript into the
# project's `keep/` directory.
#
# Invocation:
#   save-session.sh <transcript-path>
#
# Destination: "${CLAUDE_PROJECT_DIR:-$(pwd)}/keep/claude-session-<ts>.jsonl"
# plus a Markdown rendering via ~/.claude/jsonl-to-md.py.
#
# This script is the shared body of the PreCompact hook in
# ~/.claude/settings.json and the "save the session" workflow.
set -euo pipefail

if [ "$#" -lt 1 ] || [ -z "${1:-}" ]; then
    echo "save-session.sh: usage: $0 <transcript-path>" >&2
    exit 2
fi

transcript="$1"

if [ ! -f "$transcript" ]; then
    echo "save-session.sh: transcript '$transcript' not found" >&2
    exit 1
fi

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
keep="${project_dir}/keep"
mkdir -p "$keep"

ts=$(date +%Y%m%d-%H%M%S)
out="${keep}/claude-session-${ts}"

cp "$transcript" "${out}.jsonl"
python3 "${HOME}/.claude/jsonl-to-md.py" "${out}.jsonl" "${out}.md"

echo "saved: ${out}.jsonl and .md"
