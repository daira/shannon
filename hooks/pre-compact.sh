#!/usr/bin/env bash
# pre-compact.sh — ask the compaction summary to name the memories to read afterwards.
#
# Invocation: the PreCompact hook in ~/.claude/settings.json runs it after save-session.sh, in the
# same command, so that the transcript snapshot is complete before this prints anything:
#   ... && ~/.claude/save-session.sh "$transcript" --include-thinking && exec ~/.claude/pre-compact.sh
#
# After a compaction, session-start.sh asks for the core memories to be read in full, and for
# the memories that the summary recommends. This hook asks for that recommendation, chosen for
# the next step, since the core memories alone do not cover it. Each recommended memory costs
# context, so the hook text says to leave out the memories that only a later step needs.
set -euo pipefail

cat <<'EOF'
Compaction reminder: end the summary with a line "Memories to read after compaction:", naming the memories that the next step will need, beyond the core ones, which are always read. Name the project's memories, and the feedback memories whose rules that step will exercise. Leave out the memories that only a later step needs; each is read when its step comes.
EOF
