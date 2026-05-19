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

count=$(ls ~/.claude/memory/*.md 2>/dev/null | wc -l)
bytes=$(wc -c ~/.claude/memory/*.md 2>/dev/null | tail -1 | awk '{print $1}')
tokens=$(( ${bytes:-0} / 4 ))

echo "Memory corpus: ${count} files, ~${tokens} tokens (est. bytes/4). On a 1M-context model: Green <50k, Yellow 50k-100k, Red >100k."

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

if [ "${tokens:-0}" -gt 100000 ]; then
    echo '⚠️  Memory corpus >100k tokens. Even on a 1M-context model this is large; propose pruning candidates.'
elif [ "${tokens:-0}" -gt 50000 ]; then
    echo '⚠️  Memory corpus >50k tokens (yellow on 1M). Watch for further growth; consider consolidating thin or near-duplicate memories next time one is added.'
fi
