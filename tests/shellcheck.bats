#!/usr/bin/env bats
# Every shell script and bats suite in the repository passes shellcheck without any finding. Where
# the shellcheck command is not installed, the tests are skipped, except in CI ($CI set), where
# they fail.

setup() {
    if ! command -v shellcheck >/dev/null; then
        [ -z "${CI:-}" ] || { echo "shellcheck is not installed" >&2; return 1; }
        skip "shellcheck is not installed"
    fi
    cd "$BATS_TEST_DIRNAME/.." || return 1
}

@test "every shell script and bats suite passes shellcheck" {
    local files=() f
    while IFS= read -r -d '' f; do
        case "$f" in
            *.sh | *.bats) files+=("$f") ;;
            *.*) ;;
            *) if head -n 1 -- "$f" | grep -qE '^#!.*\b(ba|da)?sh\b'; then files+=("$f"); fi ;;
        esac
    done < <(git ls-files -z)
    [ "${#files[@]}" -gt 0 ]
    run shellcheck "${files[@]}"
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "shellcheck reports a finding in a script that has one" {
    cat > "$BATS_TEST_TMPDIR/bad.sh" <<'EOF'
#!/bin/sh
rm $1
EOF
    run shellcheck "$BATS_TEST_TMPDIR/bad.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *SC2086* ]]
}
