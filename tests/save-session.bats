#!/usr/bin/env bats
# Tests for hooks/save-session.sh.
#
# See ../docs/testing.md for the per-case table this suite implements.

bats_require_minimum_version 1.5.0

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../hooks/save-session.sh"
    HELPER="$BATS_TEST_DIRNAME/../hooks/jsonl-to-md.py"
    FIXTURE="$BATS_TEST_DIRNAME/fixtures/valid-transcript.jsonl"

    # Per-test HOME and CLAUDE_PROJECT_DIR so the script's `${HOME}/.claude/`
    # lookup of the jsonl-to-md helper and its `${CLAUDE_PROJECT_DIR}/keep/`
    # write target are both scoped to $BATS_TEST_TMPDIR.
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME/.claude"
    ln -s "$HELPER" "$HOME/.claude/jsonl-to-md.py"

    export CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$CLAUDE_PROJECT_DIR"
}

@test "save-session.sh parses without syntax errors" {
    run bash -n "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "jsonl-to-md.py parses without syntax errors" {
    run python3 -m py_compile "$BATS_TEST_DIRNAME/../hooks/jsonl-to-md.py"
    [ "$status" -eq 0 ]
}

@test "valid transcript: .jsonl and .md appear in keep/" {
    run bash "$SCRIPT" "$FIXTURE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"saved:"* ]]

    # Exactly one of each, named with a timestamp prefix.
    shopt -s nullglob
    local jsonls=( "$CLAUDE_PROJECT_DIR/keep/claude-session-"*.jsonl )
    local mds=( "$CLAUDE_PROJECT_DIR/keep/claude-session-"*.md )
    [ "${#jsonls[@]}" -eq 1 ]
    [ "${#mds[@]}" -eq 1 ]

    # The .jsonl is a byte-for-byte copy of the fixture; the .md is rendered.
    cmp "$FIXTURE" "${jsonls[0]}"
    [ -s "${mds[0]}" ]
    grep -qF "Session transcript" "${mds[0]}"
}

@test "missing argument: exit 2, usage on stderr" {
    run --separate-stderr bash "$SCRIPT"
    [ "$status" -eq 2 ]
    # shellcheck disable=SC2154  # run --separate-stderr sets $stderr
    [[ "$stderr" == *"usage:"* ]]
}

@test "empty argument: exit 2, usage on stderr" {
    run --separate-stderr bash "$SCRIPT" ""
    [ "$status" -eq 2 ]
    # shellcheck disable=SC2154  # run --separate-stderr sets $stderr
    [[ "$stderr" == *"usage:"* ]]
}

@test "nonexistent transcript: exit 1, not-found on stderr" {
    run --separate-stderr bash "$SCRIPT" "$BATS_TEST_TMPDIR/does-not-exist.jsonl"
    [ "$status" -eq 1 ]
    # shellcheck disable=SC2154  # run --separate-stderr sets $stderr
    [[ "$stderr" == *"not found"* ]]
}

@test "partially malformed transcript: valid lines rendered, garbage skipped" {
    local fixture="$BATS_TEST_DIRNAME/fixtures/partial-malformed-transcript.jsonl"
    run bash "$SCRIPT" "$fixture"
    [ "$status" -eq 0 ]

    shopt -s nullglob
    local mds=( "$CLAUDE_PROJECT_DIR/keep/claude-session-"*.md )
    [ "${#mds[@]}" -eq 1 ]

    # Both well-formed messages must appear; the garbage lines must not.
    grep -qF "first valid" "${mds[0]}"
    grep -qF "second valid" "${mds[0]}"
    run grep -qF "this line is not json at all" "${mds[0]}"
    [ "$status" -eq 1 ]
}

@test "all-malformed transcript: produces just the header" {
    local fixture="$BATS_TEST_DIRNAME/fixtures/all-malformed-transcript.jsonl"
    run bash "$SCRIPT" "$fixture"
    [ "$status" -eq 0 ]

    shopt -s nullglob
    local mds=( "$CLAUDE_PROJECT_DIR/keep/claude-session-"*.md )
    [ "${#mds[@]}" -eq 1 ]

    # Header is present; no further messages.
    grep -qF "Session transcript" "${mds[0]}"
    run grep -qF "not json" "${mds[0]}"
    [ "$status" -eq 1 ]
}

@test "invalid-UTF-8 bytes outside any JSON string: line is skipped, no message rendered" {
    local fixture="$BATS_TEST_DIRNAME/fixtures/structure-corrupting-utf8-transcript.jsonl"
    run bash "$SCRIPT" "$fixture"
    [ "$status" -eq 0 ]

    shopt -s nullglob
    local mds=( "$CLAUDE_PROJECT_DIR/keep/claude-session-"*.md )
    [ "${#mds[@]}" -eq 1 ]

    # The fixture's 0xff 0xfe bytes sit between the `:` and the next
    # token of the JSON object, so after replacement the line is no
    # longer parseable as JSON. The per-line try/except in the helper
    # silently skips it, leaving the .md with just the header and no
    # rendered messages. This is the companion case to the
    # "bytes inside a string" test above: it shows the replacement
    # happens uniformly across the line, and the post-replacement parse
    # failure is handled by the normal malformed-line path.
    grep -qF "Session transcript" "${mds[0]}"
    run grep -qF "hello" "${mds[0]}"
    [ "$status" -eq 1 ]
}

@test "invalid-UTF-8 transcript: bytes are replaced with U+FFFD, message still renders" {
    local fixture="$BATS_TEST_DIRNAME/fixtures/invalid-utf8-transcript.jsonl"
    run bash "$SCRIPT" "$fixture"
    [ "$status" -eq 0 ]

    shopt -s nullglob
    local mds=( "$CLAUDE_PROJECT_DIR/keep/claude-session-"*.md )
    [ "${#mds[@]}" -eq 1 ]

    # The fixture is a well-formed JSONL line whose `content` string
    # contains two raw non-UTF-8 bytes (0xff 0xfe). With errors="replace"
    # those bytes become U+FFFD before json.loads sees the line, so the
    # message parses and the rendered output contains "binary <U+FFFD
    # U+FFFD>!". This discriminates the replacement strategy from one
    # that drops the line (would have left the .md empty of messages)
    # or from one that crashes (would have produced a non-zero exit).
    grep -qF "Session transcript" "${mds[0]}"
    grep -qF -- $'binary \xef\xbf\xbd\xef\xbf\xbd!' "${mds[0]}"
}
