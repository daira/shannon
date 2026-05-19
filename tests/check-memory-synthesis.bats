#!/usr/bin/env bats
# Tests for hooks/check-memory-synthesis.sh.
#
# See ../docs/testing.md for the per-case table this suite implements.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../hooks/check-memory-synthesis.sh"
}

# Pipe a JSON payload to the script and capture output via bats's `run`.
# Defined as a function so `run` can invoke it and JSON payloads with
# embedded shell metacharacters stay safely quoted.
feed() {
    bash "$SCRIPT" <<< "$1"
}

@test "parses without syntax errors" {
    run bash -n "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "global memory path emits default reminder" {
    run feed '{"tool_name":"Write","tool_input":{"file_path":"/home/foo/.claude/memory/x.md"}}'
    [ "$status" -eq 0 ]
    [[ "$output" == *additionalContext* ]]
    [[ "$output" == *sanitization* ]]
}

@test "project memory path emits project-scoped reminder" {
    run feed '{"tool_name":"Write","tool_input":{"file_path":"/home/foo/.claude/projects/slug/memory/x.md"}}'
    [ "$status" -eq 0 ]
    [[ "$output" == *additionalContext* ]]
    [[ "$output" == *Project-scope* ]]
}

@test "global MEMORY.md emits no output" {
    run feed '{"tool_name":"Edit","tool_input":{"file_path":"/home/foo/.claude/memory/MEMORY.md"}}'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "project MEMORY.md emits no output" {
    run feed '{"tool_name":"Edit","tool_input":{"file_path":"/home/foo/.claude/projects/slug/memory/MEMORY.md"}}'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "memory-seed MEMORY.md emits no output" {
    run feed '{"tool_name":"Edit","tool_input":{"file_path":"/path/to/shannon-checkout/memory-seed/MEMORY.md"}}'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "non-memory path emits no output" {
    run feed '{"tool_name":"Write","tool_input":{"file_path":"/tmp/random.txt"}}'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "Edit-shaped input on memory path emits reminder" {
    run feed '{"tool_name":"Edit","tool_input":{"file_path":"/home/foo/.claude/memory/x.md","old_string":"a","new_string":"b"}}'
    [ "$status" -eq 0 ]
    [[ "$output" == *additionalContext* ]]
}

@test "malformed JSON on stdin does not block" {
    run feed 'not-json'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "missing file_path emits no output" {
    run feed '{"tool_name":"Write","tool_input":{}}'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "global user_*.md emits user-profile reminder" {
    run feed '{"tool_name":"Edit","tool_input":{"file_path":"/home/foo/.claude/memory/user_alice.md"}}'
    [ "$status" -eq 0 ]
    [[ "$output" == *additionalContext* ]]
    [[ "$output" == *user-profile-memory* ]]
}

@test "project user_*.md emits user-profile reminder" {
    run feed '{"tool_name":"Edit","tool_input":{"file_path":"/home/foo/.claude/projects/slug/memory/user_alice.md"}}'
    [ "$status" -eq 0 ]
    [[ "$output" == *additionalContext* ]]
    [[ "$output" == *user-profile-memory* ]]
}

@test "memory-seed source path emits default reminder" {
    run feed '{"tool_name":"Edit","tool_input":{"file_path":"/path/to/shannon-checkout/memory-seed/feedback_x.md"}}'
    [ "$status" -eq 0 ]
    [[ "$output" == *additionalContext* ]]
    [[ "$output" == *sanitization* ]]
}
