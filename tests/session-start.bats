#!/usr/bin/env bats
# Tests for hooks/session-start.sh.
#
# See ../docs/testing.md for the per-case table this suite implements.
# Strategy: override HOME (and CLAUDE_PROJECT_DIR) to a per-test tmpdir
# so the corpus can be sized into green / yellow / red bands dynamically.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../hooks/session-start.sh"
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME/.claude/memory"
    export CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$CLAUDE_PROJECT_DIR"
}

# Write a memory corpus of approximately target_bytes total, spread across
# n files (default 1). Each file is padded with spaces so wc -c reports
# the requested size; the script estimates tokens as bytes/4.
size_corpus() {
    local target_bytes=$1 n=${2:-1}
    local per_file=$((target_bytes / n))
    for i in $(seq 1 "$n"); do
        printf '%*s' "$per_file" '' > "$HOME/.claude/memory/file${i}.md"
    done
}

@test "parses without syntax errors" {
    run bash -n "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "always emits the session-start reminder text" {
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Session-start and post-compaction reminder"* ]]
    [[ "$output" == *"feedback_memory_size_budget.md"* ]]
}

@test "empty memory corpus reports 0 files and ~0 tokens" {
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"0 files, ~0 tokens"* ]]
}

@test "empty corpus emits no yellow / red warning" {
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" != *"⚠️"* ]]
}

@test "green corpus (<50k tokens) emits no warning" {
    size_corpus 100000   # ~25k tokens
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" != *"⚠️"* ]]
}

@test "yellow corpus (50k–100k tokens) emits yellow warning only" {
    size_corpus 280000   # ~70k tokens
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"⚠️"* ]]
    [[ "$output" == *"(yellow on 1M)"* ]]
    [[ "$output" != *">100k tokens"* ]]
}

@test "red corpus (>100k tokens) emits red warning" {
    size_corpus 500000   # ~125k tokens
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"⚠️"* ]]
    [[ "$output" == *">100k tokens"* ]]
}

@test "project CLAUDE.md present emits project-context line" {
    echo "test project context" > "$CLAUDE_PROJECT_DIR/CLAUDE.md"
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Project context"* ]]
    [[ "$output" == *"CLAUDE.md"* ]]
}

@test "project AGENTS.md present emits project-context line" {
    echo "agents config" > "$CLAUDE_PROJECT_DIR/AGENTS.md"
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Project context"* ]]
    [[ "$output" == *"AGENTS.md"* ]]
}

@test "no project CLAUDE.md or AGENTS.md emits no project-context line" {
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" != *"Project context"* ]]
}
