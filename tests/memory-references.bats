#!/usr/bin/env bats
# Every memory that a seed, a hook, or the CLAUDE.md template refers to is itself a seed: a
# reference to any other memory points adopters at something they do not have.

setup() {
    CHECK="$BATS_TEST_DIRNAME/check_memory_references.py"
    ROOT="$BATS_TEST_DIRNAME/.."
}

@test "the checker parses without syntax errors" {
    run python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' "$CHECK"
    [ "$status" -eq 0 ]
}

@test "every memory referenced by a seed, a hook, or the CLAUDE.md template is a seed" {
    run python3 "$CHECK" "$ROOT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "the checker reports references to memories that are not seeds" {
    fixture="$BATS_TEST_TMPDIR/shannon"
    mkdir -p "$fixture/memory-seed" "$fixture/hooks"
    printf 'See [[feedback_b]] and feedback_c, and [[feedback_a]].\n' > "$fixture/memory-seed/feedback_a.md"
    printf '# reads feedback_d.md; project_dir is a variable\n' > "$fixture/hooks/x.sh"
    run python3 "$CHECK" "$fixture"
    [ "$status" -eq 1 ]
    [[ "$output" == *"memory-seed/feedback_a.md:1: feedback_b"* ]]
    [[ "$output" == *"memory-seed/feedback_a.md:1: feedback_c"* ]]
    [[ "$output" == *"hooks/x.sh:1: feedback_d"* ]]
    [[ $'\n'"$output"$'\n' != *": feedback_a"$'\n'* ]]
    [[ "$output" != *"project_dir"* ]]
}
