#!/usr/bin/env bats
# Tests for install.sh.
#
# See ../docs/testing.md for the per-case table this suite implements.
#
# Every test installs into a fresh CLAUDE_DIR under $BATS_TEST_TMPDIR, which the
# installer honours as the destination override, so the maintainer's real
# ~/.claude is never touched. Spot checks use one hook script and one seed
# memory; the installer treats every file of a kind the same way.

set -euo pipefail

setup() {
    SHANNON_DIR=$(cd "$BATS_TEST_DIRNAME/.." && pwd)
    SCRIPT="$SHANNON_DIR/install.sh"
    export CLAUDE_DIR="$BATS_TEST_TMPDIR/claude"
    HOOK=check-tmp-path.sh
    SEED=feedback_memory_size_budget.md
}

@test "parses without syntax errors" {
    run bash -n "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "--help prints the usage and exits 0" {
    run "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: ./install.sh"* ]]
}

@test "an unknown option exits 2 with the usage" {
    run "$SCRIPT" --bogus
    [ "$status" -eq 2 ]
    [[ "$output" == *"unknown option: --bogus"* ]]
    [[ "$output" == *"Usage: ./install.sh"* ]]
}

@test "copy install into an empty directory places copies and the settings snippet" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -f "$CLAUDE_DIR/$HOOK" ]
    [ ! -L "$CLAUDE_DIR/$HOOK" ]
    cmp -s "$SHANNON_DIR/hooks/$HOOK" "$CLAUDE_DIR/$HOOK"
    [ -f "$CLAUDE_DIR/jsonl-to-md.py" ]
    cmp -s "$SHANNON_DIR/memory-seed/$SEED" "$CLAUDE_DIR/memory/$SEED"
    cmp -s "$SHANNON_DIR/claude-md/CLAUDE.example.md" "$CLAUDE_DIR/CLAUDE.md"
    cmp -s "$SHANNON_DIR/hooks/settings.json.snippet" "$CLAUDE_DIR/settings.json"
    [[ "$output" == *"installed (copy): $CLAUDE_DIR/$HOOK"* ]]
    [[ "$output" == *"Shannon install complete."* ]]
    [[ "$output" == *"Copy-mode notes"* ]]
}

@test "link install places symlinks into the checkout" {
    run "$SCRIPT" --link
    [ "$status" -eq 0 ]
    [ -L "$CLAUDE_DIR/$HOOK" ]
    [ "$(readlink "$CLAUDE_DIR/$HOOK")" = "$SHANNON_DIR/hooks/$HOOK" ]
    [ "$(readlink "$CLAUDE_DIR/memory/$SEED")" = "$SHANNON_DIR/memory-seed/$SEED" ]
    [ "$(readlink "$CLAUDE_DIR/CLAUDE.md")" = "$SHANNON_DIR/claude-md/CLAUDE.example.md" ]
    [[ "$output" == *"installed (link): $CLAUDE_DIR/$HOOK -> $SHANNON_DIR/hooks/$HOOK"* ]]
    [[ "$output" == *"Link-mode notes"* ]]
}

@test "a second run skips existing files and re-merges the settings" {
    "$SCRIPT" >/dev/null
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"skip (exists): $CLAUDE_DIR/$HOOK"* ]]
    [[ "$output" == *"skip (exists): $CLAUDE_DIR/memory/$SEED"* ]]
    [[ "$output" == *"skip (exists): $CLAUDE_DIR/CLAUDE.md"* ]]
    [[ "$output" != *"installed ("* ]]
    [[ "$output" == *"update (shannon-managed): PreToolUse/Bash"* ]]
    [[ "$output" == *"ok (already set): env/GIT_EDITOR"* ]]
    [[ "$output" == *"merged: $CLAUDE_DIR/settings.json (backup at $CLAUDE_DIR/settings.json.bak."* ]]
    cmp -s "$SHANNON_DIR/hooks/settings.json.snippet" "$CLAUDE_DIR"/settings.json.bak.*
}

@test "--dry-run creates nothing" {
    run "$SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [ ! -e "$CLAUDE_DIR" ]
    [[ "$output" == *"[dry-run] mkdir -p $CLAUDE_DIR $CLAUDE_DIR/memory"* ]]
    [[ "$output" == *"[dry-run] cp $SHANNON_DIR/hooks/$HOOK $CLAUDE_DIR/$HOOK"* ]]
    [[ "$output" == *"[dry-run] cp $SHANNON_DIR/hooks/settings.json.snippet $CLAUDE_DIR/settings.json"* ]]
}

@test "a broken symlink is skipped with a warning, without --force" {
    mkdir -p "$CLAUDE_DIR"
    ln -s "$BATS_TEST_TMPDIR/nowhere" "$CLAUDE_DIR/$HOOK"
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"skip (BROKEN symlink): $CLAUDE_DIR/$HOOK -> $BATS_TEST_TMPDIR/nowhere"* ]]
    [[ "$output" == *"re-run with --force to repair"* ]]
    [ -L "$CLAUDE_DIR/$HOOK" ]
    [ ! -e "$CLAUDE_DIR/$HOOK" ]
}

@test "--force --link repairs a broken symlink" {
    mkdir -p "$CLAUDE_DIR"
    ln -s "$BATS_TEST_TMPDIR/nowhere" "$CLAUDE_DIR/$HOOK"
    run "$SCRIPT" --link --force
    [ "$status" -eq 0 ]
    [ "$(readlink "$CLAUDE_DIR/$HOOK")" = "$SHANNON_DIR/hooks/$HOOK" ]
    [[ "$output" == *"installed (link): $CLAUDE_DIR/$HOOK -> $SHANNON_DIR/hooks/$HOOK"* ]]
}

@test "--force replaces a mis-pointed symlink and leaves its old target alone" {
    mkdir -p "$CLAUDE_DIR"
    printf 'other\n' > "$BATS_TEST_TMPDIR/other"
    ln -s "$BATS_TEST_TMPDIR/other" "$CLAUDE_DIR/$HOOK"
    run "$SCRIPT" --link --force
    [ "$status" -eq 0 ]
    [ "$(readlink "$CLAUDE_DIR/$HOOK")" = "$SHANNON_DIR/hooks/$HOOK" ]
    [ "$(cat "$BATS_TEST_TMPDIR/other")" = "other" ]
}

@test "--force backs up a regular file before replacing it" {
    mkdir -p "$CLAUDE_DIR/memory"
    printf 'my edits\n' > "$CLAUDE_DIR/memory/$SEED"
    run "$SCRIPT" --force
    [ "$status" -eq 0 ]
    [[ "$output" == *"backed up: $CLAUDE_DIR/memory/$SEED -> $CLAUDE_DIR/memory/$SEED.bak."* ]]
    local backups=("$CLAUDE_DIR/memory/$SEED".bak.*)
    [ "${#backups[@]}" -eq 1 ]
    [ "$(cat "${backups[0]}")" = "my edits" ]
    cmp -s "$SHANNON_DIR/memory-seed/$SEED" "$CLAUDE_DIR/memory/$SEED"
}

@test "--force --dry-run reports the backup and the replacement without doing them" {
    mkdir -p "$CLAUDE_DIR/memory"
    printf 'my edits\n' > "$CLAUDE_DIR/memory/$SEED"
    run "$SCRIPT" --force --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"[dry-run] mv $CLAUDE_DIR/memory/$SEED $CLAUDE_DIR/memory/$SEED.bak."* ]]
    [[ "$output" == *"[dry-run] cp $SHANNON_DIR/memory-seed/$SEED $CLAUDE_DIR/memory/$SEED"* ]]
    [ "$(cat "$CLAUDE_DIR/memory/$SEED")" = "my edits" ]
    [ ! -e "$CLAUDE_DIR/$HOOK" ]
}

@test "the settings merge appends Shannon's entries and leaves the user's alone" {
    mkdir -p "$CLAUDE_DIR"
    cat > "$CLAUDE_DIR/settings.json" <<'EOF'
{
  "model": "opus",
  "env": { "GIT_EDITOR": "vim" },
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [ { "type": "command", "command": "echo mine" } ] }
    ]
  }
}
EOF
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"append: PreCompact/*"* ]]
    [[ "$output" == *"append: SessionStart/*"* ]]
    [[ "$output" == *"append: PreToolUse/Write|Edit"* ]]
    [[ "$output" == *"skip (user-customized): PreToolUse/Bash"* ]]
    [[ "$output" == *"append: env/GIT_SEQUENCE_EDITOR"* ]]
    [[ "$output" == *"skip (user-customized): env/GIT_EDITOR"* ]]
    local s="$CLAUDE_DIR/settings.json"
    [ "$(jq -r .model "$s")" = "opus" ]
    [ "$(jq -r .env.GIT_EDITOR "$s")" = "vim" ]
    [ "$(jq -r .env.GIT_SEQUENCE_EDITOR "$s")" = "true" ]
    [ "$(jq -r '.hooks.PreToolUse | length' "$s")" = "2" ]
    [ "$(jq -r '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[0].command' "$s")" = "echo mine" ]
    [ "$(jq -r '.hooks.PreCompact[0]._shannon' "$s")" = "true" ]
    [ "$(jq -r '.hooks.PreCompact[0].hooks[0].command' "$s")" = "$(jq -r '.hooks.PreCompact[0].hooks[0].command' "$SHANNON_DIR/hooks/settings.json.snippet")" ]
    [ "$(jq -r .model "$CLAUDE_DIR"/settings.json.bak.*)" = "opus" ]
}

@test "the settings merge requires jq" {
    mkdir -p "$CLAUDE_DIR" "$BATS_TEST_TMPDIR/tools"
    printf '{}\n' > "$CLAUDE_DIR/settings.json"
    local tool path
    for tool in bash dirname mkdir cp cat; do
        path=$(command -v "$tool") && ln -s "$path" "$BATS_TEST_TMPDIR/tools/$tool"
    done
    PATH="$BATS_TEST_TMPDIR/tools" run "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"jq is required to merge"* ]]
}
