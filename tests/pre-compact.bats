#!/usr/bin/env bats
# Tests for hooks/pre-compact.sh.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../hooks/pre-compact.sh"
}

@test "pre-compact.sh parses without syntax errors" {
    run bash -n "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "it asks the summary to name the memories to read after compaction" {
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Memories to read after compaction:"* ]]
}
