#!/usr/bin/env bats
# Tests for bin/rewrap-check. Each test commits a file in a fresh git repository, edits it, and
# runs the script on the edit.

bats_require_minimum_version 1.5.0

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../bin/rewrap-check"
    cd "$BATS_TEST_TMPDIR" || return 1
    git init -q repo
    cd repo || return 1
    git config user.name test
    git config user.email test@example.com
}

# edit FILE BEFORE AFTER: commit FILE holding BEFORE, then overwrite it with AFTER.
edit() {
    printf '%s' "$2" > "$1"
    git add "$1"
    git commit -q -m base
    printf '%s' "$3" > "$1"
}

LONG='A paragraph that an edit has made much too long for a width of forty columns.'

@test "rewrap-check parses without syntax errors" {
    run python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "an edited paragraph that needs rewrapping is flagged, and the check fails" {
    edit a.md $'short\n' "$LONG"$'\n'
    run "$SCRIPT" --width 40 a.md
    [ "$status" -eq 1 ]
    [[ "$output" == *"a.md:1-1:"* ]]
}

@test "a paragraph that the edit did not touch is not flagged" {
    edit a.md "$LONG"$'\n\nshort\n' "$LONG"$'\n\nshort, edited\n'
    run "$SCRIPT" --width 40 a.md
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "--fix rewraps the paragraph and succeeds" {
    edit a.md $'short\n' "$LONG"$'\n'
    run "$SCRIPT" --width 40 --fix a.md
    [ "$status" -eq 0 ]
    [[ "$output" == *"rewrapped 1 paragraph(s) in a.md"* ]]
    run "$SCRIPT" --width 40 a.md
    [ "$status" -eq 0 ]
    while IFS= read -r line; do
        [ "${#line}" -le 40 ]
    done < a.md
}

@test "the check reports an over-width line that it cannot reflow, and fails" {
    edit a.rs $'fn f() {}\n' $'fn f() { let x = 1; let y = 2; let z = 3; let w = 4; }\n'
    run "$SCRIPT" --width 40 a.rs
    [ "$status" -eq 1 ]
    [[ "$output" == *"a.rs:1: line exceeds 40 cols"* ]]
}

@test "--fix notes an over-width line that it cannot reflow, and still succeeds" {
    edit a.rs $'fn f() {}\n' $'fn f() { let x = 1; let y = 2; let z = 3; let w = 4; }\n'
    run "$SCRIPT" --width 40 --fix a.rs
    [ "$status" -eq 0 ]
    [[ "$output" == *"a.rs:1: note: line exceeds 40 cols"* ]]
}

@test "--fix leaves alone a list that directly follows a paragraph's line" {
    edit a.md $'x\n' "$LONG"$'\n- first item\n- second item\n'
    run "$SCRIPT" --width 40 --fix a.md
    [ "$status" -eq 0 ]
    [ "$(tail -n 2 a.md)" = $'- first item\n- second item' ]
}

@test "--fix leaves alone a list in line comments" {
    edit a.rs $'// x\n' "/// $LONG"$'\n/// - first item\n/// - second item\nfn f() {}\n'
    run "$SCRIPT" --width 40 --fix a.rs
    [ "$status" -eq 0 ]
    [ "$(tail -n 3 a.rs)" = $'/// - first item\n/// - second item\nfn f() {}' ]
}

@test "--fix does not join a setext heading to the paragraph after it" {
    edit a.md $'x\n' $'Title\n-----\n'"$LONG"$'\n'
    run "$SCRIPT" --width 40 --fix a.md
    [ "$status" -eq 0 ]
    [ "$(head -n 2 a.md)" = $'Title\n-----' ]
    while IFS= read -r line; do
        [ "${#line}" -le 40 ]
    done < a.md
}

@test "--fix rewraps an edited Python docstring, keeping its quotes on the first and last words" {
    edit a.py $'def f():\n    """Short."""\n' \
        $'def f():\n    """A docstring that an edit has made much too long for forty columns."""\n'
    run "$SCRIPT" --width 40 --fix a.py
    [ "$status" -eq 0 ]
    [ "$(cat a.py)" = $'def f():\n    """A docstring that an edit has made\n    much too long for forty columns."""' ]
}

@test "--fix leaves alone a docstring's quote-only lines and its doctests" {
    edit a.py $'def f():\n    """\n    Short.\n    """\n' \
        $'def f():\n    """\n    A docstring that an edit has made much too long for forty columns.\n\n    >>> f()\n    """\n'
    run "$SCRIPT" --width 40 --fix a.py
    [ "$status" -eq 0 ]
    [ "$(cat a.py)" = $'def f():\n    """\n    A docstring that an edit has made\n    much too long for forty columns.\n\n    >>> f()\n    """' ]
}

@test "a triple-quoted string that is not a docstring is not reflowed" {
    edit a.py $'import os\nX = """short"""\n' \
        $'import os\nX = """A string that an edit has made much too long for forty columns."""\n'
    run "$SCRIPT" --width 40 --fix a.py
    [ "$status" -eq 0 ]
    [[ "$output" == *"a.py:2: note: line exceeds 40 cols"* ]]
    [ "$(tail -n 1 a.py)" = 'X = """A string that an edit has made much too long for forty columns."""' ]
}

@test "a file without an extension is read as Python when its shebang names python" {
    local n=0 shebang
    for shebang in '#!/usr/bin/env python3' '#!/usr/bin/env python' '#!/usr/bin/python3'; do
        n=$((n + 1))
        edit "tool$n" "$shebang"$'\n"""Short."""\n' \
            "$shebang"$'\n"""A docstring that an edit has made much too long for forty columns."""\n'
    done
    run "$SCRIPT" --width 40 tool1 tool2 tool3
    [ "$status" -eq 1 ]
    [[ "$output" == *"tool1:2-2:"* ]]
    [[ "$output" == *"tool2:2-2:"* ]]
    [[ "$output" == *"tool3:2-2:"* ]]
}

@test "a file without an extension and without a python shebang is not read" {
    edit tool $'#!/bin/sh\n# short\n' \
        $'#!/bin/sh\n# A comment that an edit has made much too long for forty columns.\n'
    run "$SCRIPT" --width 40 tool
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "--all flags a badly wrapped paragraph that the edit did not touch" {
    edit a.md "$LONG"$'\n\nshort\n' "$LONG"$'\n\nshort, edited\n'
    run "$SCRIPT" --width 40 a.md
    [ "$status" -eq 0 ]
    run "$SCRIPT" --all --width 40 a.md
    [ "$status" -eq 1 ]
    [[ "$output" == *"a.md:1-1:"* ]]
}

@test "--all reads a file that git does not track" {
    edit other.md $'x\n' $'x\n'
    printf '%s\n' "$LONG" > new.md
    run "$SCRIPT" --width 40 new.md
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    run "$SCRIPT" --all --width 40 new.md
    [ "$status" -eq 1 ]
    [[ "$output" == *"new.md:1-1:"* ]]
}

@test "--all works outside a git repository" {
    mkdir "$BATS_TEST_TMPDIR/plain"
    cd "$BATS_TEST_TMPDIR/plain" || return 1
    printf '%s\n' "$LONG" > msg.txt
    GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR" run "$SCRIPT" --all --width 40 msg.txt
    [ "$status" -eq 1 ]
    [[ "$output" == *"msg.txt:1-1:"* ]]
}

@test "--all --fix rewraps every badly wrapped paragraph of the file" {
    printf '%s\n\n%s\n' "$LONG" "$LONG" > new.md
    run "$SCRIPT" --all --width 40 --fix new.md
    [ "$status" -eq 0 ]
    [[ "$output" == *"rewrapped 2 paragraph(s) in new.md"* ]]
    while IFS= read -r line; do
        [ "${#line}" -le 40 ]
    done < new.md
}

@test "--all needs paths" {
    run "$SCRIPT" --all --width 40
    [ "$status" -eq 2 ]
    [[ "$output" == *"--all needs the paths"* ]]
}

@test "--all notes a named file of a type that it does not read" {
    printf '%s\n' "$LONG" > notes
    run --separate-stderr "$SCRIPT" --all --width 40 notes
    [ "$status" -eq 0 ]
    # shellcheck disable=SC2154  # run --separate-stderr sets $stderr
    [[ "$stderr" == *"notes: note: not a file type that rewrap-check reads"* ]]
}

@test "--all fails on a file that it cannot read" {
    run "$SCRIPT" --all --width 40 missing.md
    [ "$status" -eq 1 ]
    [[ "$output" == *"cannot read missing.md"* ]]
}

@test "a dollar sign inside a code span is not taken for a split math span" {
    edit a.md $'x\n' $'Run `kill $(pgrep x)` to stop it\nnow, and check.\n'
    run "$SCRIPT" --width 40 a.md
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "a code span split across lines is still flagged" {
    edit a.md $'x\n' $'Run `kill $(pgrep\nx)` to stop it now.\n'
    run "$SCRIPT" --width 40 a.md
    [ "$status" -eq 1 ]
    [[ "$output" == *"a code or math span is split across lines"* ]]
}

@test "a double-backtick span split across lines is flagged" {
    edit a.md $'x\n' $'Run ``kill -TERM\npid`` to stop it now.\n'
    run "$SCRIPT" --width 40 a.md
    [ "$status" -eq 1 ]
    [[ "$output" == *"a code or math span is split across lines"* ]]
}

@test "an escaped backtick does not open a code span" {
    edit a.md $'x\n' $'Run \\`kill -TERM` to stop it all\nnow, and check.\n'
    run "$SCRIPT" --width 40 a.md
    [ "$status" -eq 1 ]
    [[ "$output" == *"a code or math span is split across lines"* ]]
}

@test "a backslash inside a code span does not escape its closing backtick" {
    edit a.md $'x\n' $'Run `C:\\` for the job to stop it\nnow, and check.\n'
    run "$SCRIPT" --width 40 a.md
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "a shorter fence inside a longer fence does not close it" {
    edit a.md $'x\n' $'````\n```\n'"$LONG"$'\n````\n'
    run "$SCRIPT" --width 40 a.md
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
