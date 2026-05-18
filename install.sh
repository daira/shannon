#!/usr/bin/env bash
#
# Shannon installer — copies the Claude Code memory-and-trigger toolkit into
# ~/.claude/.
#
# Idempotent (re-running is safe) and non-destructive (existing files /
# settings are preserved; this script merges rather than overwrites).
#
# STATUS: stub. The full installer is pending. This stub prints the planned
# actions so contributors can dry-run the intent before implementation lands.

set -euo pipefail

cat <<'EOF'
Shannon installer (stub — not yet implemented).

Planned actions:
  1. Merge hooks/settings.json.snippet into ~/.claude/settings.json
     (preserving existing hooks; warn on conflict).
  2. Copy hooks/*.sh to ~/.claude/ (skipping any with the same name to
     preserve existing scripts; offer --force to overwrite).
  3. Copy memory-seed/*.md to ~/.claude/memory/ (skipping any that already
     exist; never overwrite user memories).
  4. Install claude-md/CLAUDE.md.example to ~/.claude/CLAUDE.md if missing,
     or prompt for project-specific install path.

Re-run with --dry-run (planned) to see exactly what would change.

For now, see README.md for what the full installer will set up, and copy
files into place by hand if you want to try Shannon before the installer
lands.
EOF
