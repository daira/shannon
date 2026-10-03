#!/usr/bin/env bats
# Tests for bin/rewrap-check. Each test commits a file in a fresh git repository, edits it, and
# runs the script on the edit.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../bin/rewrap-check"
    cd "$BATS_TEST_TMPDIR"
    git init -q repo
    cd repo
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
