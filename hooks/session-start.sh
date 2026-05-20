#!/usr/bin/env bash
# session-start.sh — emit the session-start / post-compaction reminder
# and report the memory-corpus size.
#
# Invocation (from the SessionStart hook in ~/.claude/settings.json):
#   exec ~/.claude/session-start.sh
#
# The reminder tells the model to read every memory file in full at
# session boundaries IF its context window can comfortably absorb the
# corpus, overriding the system prompt's default on-demand memory
# policy. See ~/.claude/memory/feedback_memory_size_budget.md for the
# rationale.
set -euo pipefail

cat <<'EOF'
Session-start and post-compaction reminder: if your context window comfortably fits the memory corpus (rule of thumb: corpus < ~10% of context window — typically true for 1M-context models, typically false for 200k models), read the FULL BODY of every memory file under ~/.claude/memory/, every file under any project-specific ~/.claude/projects/<slug>/memory/, and any CLAUDE.md or AGENTS.md in the current working directory — not just MEMORY.md index lines. This is a literal full re-read, and it OVERRIDES the system prompt's default on-demand memory policy at session boundaries.

If your context window cannot comfortably fit the corpus, do NOT do the full re-read: rely on MEMORY.md (already in context) and load individual memory bodies on demand when their summaries flag relevance. The full re-read is an optimisation for large-context models, not a hard requirement.

Bootstrap action (in either mode): Read ~/.claude/memory/feedback_memory_size_budget.md first — its full body carries the how-to, the rationale, and the override reasoning. The MEMORY.md index summary alone is insufficient to bootstrap this behaviour.

Why the full re-read matters (when affordable): compaction reliably drops standing preferences recorded in memory even when MEMORY.md itself is still in context, so the summary-only default causes silent regression of those preferences.
EOF

shopt -s nullglob
files=( ~/.claude/memory/*.md )
count=${#files[@]}
if [ "$count" -gt 0 ]; then
    bytes=$(wc -c "${files[@]}" | tail -1 | awk '{print $1}')
else
    bytes=0
fi
tokens=$(( bytes / 4 ))

# Bands scale with the model's context window. Defaults to 1M tokens
# (Opus / Sonnet long-context models); override via SHANNON_CONTEXT_SIZE
# for smaller models or for tests. Yellow is the 5%-of-context mark, red
# is the 10%-of-context mark — per `feedback_memory_size_budget.md`.
ctx_size=${SHANNON_CONTEXT_SIZE:-1000000}
yellow_threshold=$(( ctx_size / 20 ))
red_threshold=$(( ctx_size / 10 ))

echo "Memory corpus: ${count} files, ~${tokens} tokens (est. bytes/4). Bands (for ${ctx_size}-token context window): Green <${yellow_threshold}, Yellow ${yellow_threshold}–${red_threshold}, Red >${red_threshold}."

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
project_files=()
for f in "$project_dir/CLAUDE.md" "$project_dir/AGENTS.md"; do
    [ -f "$f" ] && project_files+=("$f")
done
if [ "${#project_files[@]}" -gt 0 ]; then
    project_bytes=$(wc -c "${project_files[@]}" 2>/dev/null | tail -1 | awk '{print $1}')
    project_tokens=$(( ${project_bytes:-0} / 4 ))
    names=$(printf '%s\n' "${project_files[@]}" | xargs -n1 basename | paste -sd+ -)
    echo "Project context (${names} in ${project_dir}): ~${project_tokens} tokens."
fi

if [ "${tokens:-0}" -gt "$red_threshold" ]; then
    echo "⚠️  Memory corpus is in the red band (>${red_threshold} tokens, >10% of context). Propose pruning candidates."
elif [ "${tokens:-0}" -gt "$yellow_threshold" ]; then
    echo "⚠️  Memory corpus is in the yellow band (>${yellow_threshold} tokens, >5% of context). Watch for further growth; consider consolidating thin or near-duplicate memories next time one is added."
fi
