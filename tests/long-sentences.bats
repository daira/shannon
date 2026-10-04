#!/usr/bin/env bats
# Tests for bin/long-sentences. Each test feeds prose on standard input.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../bin/long-sentences"
}

# words N: print N distinct words separated by single spaces, without punctuation.
words() {
    local i out=w1
    for ((i = 2; i <= $1; i++)); do out+=" w$i"; done
    printf '%s' "$out"
}

@test "long-sentences parses without syntax errors" {
    run python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "short sentences pass silently" {
    run "$SCRIPT" <<< 'A short sentence. Another one, with a comma.'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "a sentence over the word limit is flagged with its count" {
    run "$SCRIPT" <<< "Start, $(words 20), $(words 15) end."
    [ "$status" -eq 1 ]
    [[ "$output" == "37 words: Start,"* ]]
}

@test "the word limit can be changed" {
    run "$SCRIPT" --max-words 40 <<< "Start, $(words 20), $(words 15) end."
    [ "$status" -eq 0 ]
}

@test "a long run without internal punctuation is flagged" {
    run "$SCRIPT" <<< "$(words 27) end."
    [ "$status" -eq 1 ]
    [[ "$output" == "28 words:"* ]]
}

@test "two semicolons in one sentence are flagged" {
    run "$SCRIPT" <<< 'One; two; three.'
    [ "$status" -eq 1 ]
}

@test "a code span counts as one word, including a double-backtick span" {
    run "$SCRIPT" <<< "Start, \`a b c d e f g h i j\`, \`\`k \`l\` m n o p q r s t\`\`, $(words 24) end."
    [ "$status" -eq 0 ]
}

@test "a code span broken across a line is one word" {
    run "$SCRIPT" <<< "Start, \`a b c d e f g h i j k l;
m n o p q r s t u v w x;\`, $(words 20) end."
    [ "$status" -eq 0 ]
}

@test "a closing quote after a full stop ends the sentence" {
    run "$SCRIPT" <<< "It said, \"$(words 20) done.\" Then, $(words 15) end."
    [ "$status" -eq 0 ]
}

@test "e.g. before a code span does not end the sentence" {
    run "$SCRIPT" <<< "Start, $(words 20), e.g. \`code\`, $(words 10) end."
    [ "$status" -eq 1 ]
    [[ "$output" == "34 words:"* ]]
}

@test "each bullet is its own unit" {
    run "$SCRIPT" <<< "- First, $(words 20) end
- Second, $(words 20) end"
    [ "$status" -eq 0 ]
}

@test "a fenced code block is skipped" {
    run "$SCRIPT" <<< "Text.

\`\`\`
$(words 40)
\`\`\`"
    [ "$status" -eq 0 ]
}

@test "a fenced code block marked with tildes is skipped" {
    run "$SCRIPT" <<< "Text.

~~~
$(words 40)
~~~"
    [ "$status" -eq 0 ]
}

@test "a final paragraph of trailers is skipped" {
    run "$SCRIPT" <<< "Subject.

Co-authored-by: $(words 40)"
    [ "$status" -eq 0 ]
}

@test "a paragraph that opens with a key and a colon is still checked" {
    run "$SCRIPT" <<< "Note: $(words 40) end.

Co-authored-by: Someone"
    [ "$status" -eq 1 ]
}

@test "with --diff, only the added line comments are read" {
    diff="+// Start, $(words 20), $(words 15) end.
+let x = $(words 40);
-// Removed, $(words 20), $(words 15) end."
    run "$SCRIPT" --diff <<< "$diff"
    [ "$status" -eq 1 ]
    [ "$(grep -c 'words:' <<< "$output")" -eq 1 ]
    [[ "$output" == *"Start,"* ]]
}

@test "an unmatched double backtick does not open a code span" {
    run "$SCRIPT" <<< "Start, \`\`a $(words 26)\` end."
    [ "$status" -eq 1 ]
}

@test "an escaped backtick does not open a code span" {
    run "$SCRIPT" <<< "Start, \\\`a $(words 26)\` end."
    [ "$status" -eq 1 ]
}

@test "a shorter fence inside a longer fence does not close it" {
    run "$SCRIPT" <<< "Text.

\`\`\`\`
\`\`\`
$(words 40)
\`\`\`\`"
    [ "$status" -eq 0 ]
}

@test "a fence of the other character does not close it" {
    run "$SCRIPT" <<< "Text.

~~~
\`\`\`
$(words 40)
~~~"
    [ "$status" -eq 0 ]
}
