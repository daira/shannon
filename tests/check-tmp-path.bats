#!/usr/bin/env bats
# Tests for hooks/check-tmp-path.sh.
#
# See ../docs/testing.md for the per-case table this suite implements.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../hooks/check-tmp-path.sh"
}

# Build a `Bash` PreToolUse payload via jq (so the command string can
# safely contain shell metacharacters) and pipe it to the script.
feed_cmd() {
    local payload
    payload=$(jq -nc --arg cmd "$1" '{tool_name: "Bash", tool_input: {command: $cmd}}')
    bash "$SCRIPT" <<< "$payload"
}

# Pipe a raw payload (for malformed / missing-field cases).
feed_raw() {
    bash "$SCRIPT" <<< "$1"
}

@test "parses without syntax errors" {
    run bash -n "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "literal /tmp/<path> triggers reminder" {
    run feed_cmd 'touch /tmp/foo'
    [ "$status" -eq 0 ]
    [[ "$output" == *additionalContext* ]]
    [[ "$output" == *"<project>/tmp/"* ]]
}

@test "bare /tmp argument (space-bounded) triggers reminder" {
    run feed_cmd 'ls /tmp foo'
    [ "$status" -eq 0 ]
    [[ "$output" == *additionalContext* ]]
}

@test "=/tmp/<path> flag triggers reminder" {
    run feed_cmd 'mkdir --parents=/tmp/foo'
    [ "$status" -eq 0 ]
    [[ "$output" == *additionalContext* ]]
}

@test "=/tmp flag with trailing space triggers reminder" {
    run feed_cmd 'myscript --dir=/tmp other'
    [ "$status" -eq 0 ]
    [[ "$output" == *additionalContext* ]]
}

@test "/tmp/claude-* paths are exempt (no reminder)" {
    run feed_cmd 'cat /tmp/claude-abc123/result.txt'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "non-tmp command emits no output" {
    run feed_cmd 'ls /home/user'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "substring containing 'tmp' without /tmp/ is not a false positive" {
    run feed_cmd 'cat /home/user/tmpfile.txt'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "missing command field emits no output" {
    run feed_raw '{"tool_name":"Bash","tool_input":{}}'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "malformed JSON on stdin does not block" {
    run feed_raw 'not-json'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
