#!/usr/bin/env bash
# check-portable-commands.sh — PreToolUse hook for Bash: deny a command that
# invokes a platform-native tool whose behaviour differs from the
# implementation the agent's training matches, when that implementation is
# installed under another name.
#
# The motivating case is macOS: `sed` is BSD sed, whose in-place syntax,
# `a`/`i`/`c` commands, and escaping rules differ from GNU sed, and the agent
# repeatedly writes GNU-shaped invocations that fail or misbehave. Where GNU sed
# is installed as `gsed`, the fix is to use it every time. The same pattern
# applies to other BSD-versus-GNU pairs (awk/gawk, find/gfind, date/gdate, ...),
# so the tool names live in a table rather than in the code.
#
# Table entries are "native preferred". An entry is active only when
# `preferred` is on PATH and resolves to a different file from `native`, so on
# a GNU system, where `sed` already is GNU sed, or on a machine without `gsed`,
# the `sed gsed` entry does nothing. Add entries by uncommenting or appending.
#
# Detection looks for the native name in command position: at the start of the
# command or after a separator (`|`, `;`, `&`, `(`, a backtick, a newline),
# optionally preceded by variable assignments or wrappers (`sudo`, `exec`,
# `time`, `nice`, `env`, `command`, `xargs`), as a bare name or an absolute
# path, and after `find`'s `-exec`. Mentions of the name in prose, options, or
# arguments are not flagged.
#
# Output: `permissionDecision: deny` with a reason naming the replacement, so
# that the agent rewrites the call. Always exits 0; malformed input (bad JSON on
# stdin) produces no output and does not block the tool, since a blocking
# failure would silently break every Bash command.
#
# Invocation (from a `PreToolUse` entry in `settings.json` with
# `matcher: "Bash"`):
#   {"type": "command", "command": "exec ~/.claude/check-portable-commands.sh"}

set -uo pipefail  # NOT -e: absorb tool errors and always exit 0

TABLE=(
    "sed gsed"
    # "awk gawk"
    # "find gfind"
    # "xargs gxargs"
    # "date gdate"
    # "stat gstat"
    # "readlink greadlink"
    # "tar gtar"
)

cmd=$(jq -r '.tool_input.command // ""' 2>/dev/null) || cmd=""
[ -n "$cmd" ] || exit 0

# Canonical path of a command, or its PATH lookup when realpath is unavailable.
canonical() {
    local path
    path=$(command -v -- "$1" 2>/dev/null) || return 1
    realpath -- "$path" 2>/dev/null || printf '%s\n' "$path"
}

# Whether the entry applies here: the preferred tool exists and is not simply
# the native one under another name.
active() {
    local native=$1 preferred=$2 a b
    b=$(canonical "$preferred") || return 1
    a=$(canonical "$native") || return 0
    [ "$a" != "$b" ]
}

# Whether $cmd invokes $1 in command position.
invokes() {
    local name=$1 wrappers pat
    wrappers='([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*|sudo|exec|time|nice|env|command|xargs([[:space:]]+-[^[:space:]]+)*)[[:space:]]+'
    pat="(^|[|;&(\`])[[:space:]]*(${wrappers})*(/[^[:space:]]*/)?${name}([[:space:]]|$)"
    pat="${pat}|-exec[[:space:]]+(/[^[:space:]]*/)?${name}([[:space:]]|$)"
    printf '%s\n' "$cmd" | grep -Eq -- "$pat"
}

hits=()
for entry in "${TABLE[@]}"; do
    read -r native preferred <<<"$entry"
    if active "$native" "$preferred" && invokes "$native"; then
        hits+=("\`$native\` (use \`$preferred\`)")
    fi
done

if [ "${#hits[@]}" -gt 0 ]; then
    list=$(printf '%s, ' "${hits[@]}")
    list=${list%, }
    jq -n --arg reason "Non-portable command in this Bash call: ${list}. On this machine the native implementation differs from the one the agent's training matches, and the preferred implementation is installed, so use it instead. The table of native/preferred pairs is in the hook script check-portable-commands.sh." '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: $reason
        }
    }' 2>/dev/null
fi

exit 0
