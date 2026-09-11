#!/usr/bin/env bats
# Tests for hooks/check-portable-commands.sh.
#
# See ../docs/testing.md for the per-case table this suite implements.
#
# The script's active/inert decision depends on which tools are on PATH, so
# every test runs with a PATH built here from scratch: a stub directory with
# distinct `sed` and `gsed` executables (the configuration of a machine whose
# native sed is not GNU sed but has GNU sed installed under another name), and
# a tools directory with symlinks to the real `bash`, `jq`, `grep`, and
# `realpath` that the script needs (and `rm` and `ln` for the tests' own use).
# Two tests then vary the stubs: `gsed` absent, and `sed` a symlink to `gsed`.

set -euo pipefail

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../hooks/check-portable-commands.sh"

    TOOLS="$BATS_TEST_TMPDIR/tools"
    mkdir -p "$TOOLS"
    local tool path
    for tool in bash jq grep realpath rm ln; do
        if path=$(command -v "$tool"); then
            ln -s "$path" "$TOOLS/$tool"
        fi
    done

    STUBS="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUBS"
    printf '#!/bin/sh\nexit 0\n' > "$STUBS/sed"
    printf '#!/bin/sh\nexit 0\n' > "$STUBS/gsed"
    chmod +x "$STUBS/sed" "$STUBS/gsed"

    export PATH="$STUBS:$TOOLS"
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

# The deny output names the native tool and its replacement.
assert_denies_sed() {
    [ "$status" -eq 0 ]
    [[ "$output" == *permissionDecision*deny* ]]
    [[ "$output" == *'`sed` (use `gsed`)'* ]]
}

@test "parses without syntax errors" {
    run bash -n "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "sed after a pipe is denied" {
    run feed_cmd 'grep x file | sed -n 1p'
    assert_denies_sed
}

@test "sed at the start of the command is denied" {
    run feed_cmd 'sed -i s/a/b/ file'
    assert_denies_sed
}

@test "gsed is not flagged" {
    run feed_cmd 'grep x file | gsed -n 1p'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "sed after variable assignments is denied" {
    run feed_cmd 'LC_ALL=C FOO=1 sed -e p file'
    assert_denies_sed
}

@test "sed after xargs with options is denied" {
    run feed_cmd 'cat list | xargs -0 sed -i s/a/b/'
    assert_denies_sed
}

@test "sed after find -exec is denied" {
    run feed_cmd "find . -name '*.md' -exec sed -i 's/a/b/' {} +"
    assert_denies_sed
}

@test "sed by absolute path is denied" {
    run feed_cmd '/usr/bin/sed -n 1p file'
    assert_denies_sed
}

@test "sed on a later line of a multi-line command is denied" {
    run feed_cmd $'echo first\nsed -n 1p file'
    assert_denies_sed
}

@test "sed mentioned in prose is not flagged" {
    run feed_cmd 'echo "we used sed here"'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "sed as an argument is not flagged" {
    run feed_cmd 'git log --oneline | grep sed'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "a word beginning with sed is not flagged" {
    run feed_cmd 'echo sedimentary'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "inert when the preferred tool is absent" {
    rm "$STUBS/gsed"
    run feed_cmd 'grep x file | sed -n 1p'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "inert when the native name is the preferred tool" {
    rm "$STUBS/sed"
    ln -s gsed "$STUBS/sed"
    run feed_cmd 'grep x file | sed -n 1p'
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
