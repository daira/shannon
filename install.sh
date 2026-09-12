#!/usr/bin/env bash
# install.sh — install Shannon's hooks, seed memories, and `CLAUDE.md`
# template into the user's `~/.claude/` directory.
#
# See the Usage string below for details, and the post-install
# message at the end of this script for activation specifics.

set -euo pipefail

MODE="copy"
DRY_RUN=0
FORCE=0

usage() {
    cat <<'EOF'
Usage: ./install.sh [--copy | --link] [--force] [--dry-run]

Install Shannon's hooks, seed memories, and CLAUDE.md template into
~/.claude/.

Shannon can be installed in two modes:

  --copy     (default) Copy Shannon's files into `~/.claude/`. Existing
             files are not overwritten (the installer skips them and
             reports which were skipped).

  --link     Symlink each `~/.claude/<file>` to the Shannon source.
             Edits to memories or scripts then flow back into the
             Shannon checkout as changes that can be committed, or vice
             versa if you update the checkout. This mode is intended for
             maintainers and contributors. Requires filesystem symlink
             support (Linux / macOS / Windows Subsystem for Linux).

In both modes, existing files or links at the destination are skipped,
not overwritten, unless --force is given. A skipped destination that is a
broken symlink is reported as a warning suggesting --force.

  --force    Replace existing destinations instead of skipping them. A
             regular file is backed up to <file>.bak.<timestamp> first; an
             existing symlink is simply replaced (this repairs broken or
             mis-pointed links on re-run). Does not affect the settings.json
             merge, which already merges and backs up.

  --dry-run  Print what would be done without making changes.

  --help     Show this message.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --copy) MODE="copy" ;;
        --link) MODE="link" ;;
        --dry-run) DRY_RUN=1 ;;
        --force) FORCE=1 ;;
        --help|-h) usage; exit 0 ;;
        *) printf 'install.sh: unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

SHANNON_DIR=$(cd "$(dirname "$0")" && pwd)

# Destination root. Defaults to ~/.claude/; override with the CLAUDE_DIR
# environment variable for testing or for non-standard installs.
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"

# Verify Shannon directory structure
for required in hooks memory-seed claude-md; do
    if [ ! -d "$SHANNON_DIR/$required" ]; then
        printf 'install.sh: %s/%s missing — is this a Shannon checkout?\n' "$SHANNON_DIR" "$required" >&2
        exit 1
    fi
done

# Ensure ~/.claude/ and ~/.claude/memory/ directories exist
if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] mkdir -p %s %s\n' "$CLAUDE_DIR" "$CLAUDE_DIR/memory"
else
    mkdir -p "$CLAUDE_DIR" "$CLAUDE_DIR/memory"
fi

# Symlink-support check for --link mode
if [ "$MODE" = "link" ]; then
    test_link=$(mktemp -u "$CLAUDE_DIR/.shannon-link-test.XXXXXX")
    if ! ln -s /dev/null "$test_link" 2>/dev/null; then
        printf 'install.sh: filesystem does not support symlinks (or insufficient permissions); --link is unavailable.\n' >&2
        printf 'Try --copy instead, or use WSL on Windows.\n' >&2
        exit 1
    fi
    rm -f "$test_link"
fi

install_file() {
    local src="$1" dst="$2" bak
    # -e || -L: catch broken symlinks too, which -e alone misses.
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        if [ "$FORCE" -eq 0 ]; then
            # A broken symlink (link present, target missing) is almost
            # certainly a mistake to leave in place — warn and point at
            # --force rather than silently skipping it.
            if [ -L "$dst" ] && [ ! -e "$dst" ]; then
                printf 'skip (BROKEN symlink): %s -> %s — re-run with --force to repair\n' \
                    "$dst" "$(readlink "$dst")" >&2
            else
                printf 'skip (exists): %s\n' "$dst"
            fi
            return
        fi
        # --force: replace the existing destination. A symlink carries no
        # content of its own, so just remove it (this repairs a broken or
        # mis-pointed link on re-run); a regular file may hold user edits,
        # so back it up first.
        if [ -L "$dst" ]; then
            if [ "$DRY_RUN" -eq 1 ]; then
                printf '[dry-run] rm %s (replace existing symlink)\n' "$dst"
            else
                rm -f "$dst"
            fi
        else
            bak="$dst.bak.$(date +%s)"
            if [ "$DRY_RUN" -eq 1 ]; then
                printf '[dry-run] mv %s %s (backup before replace)\n' "$dst" "$bak"
            else
                mv "$dst" "$bak"
                printf 'backed up: %s -> %s\n' "$dst" "$bak"
            fi
        fi
    fi
    case "$MODE" in
        copy)
            if [ "$DRY_RUN" -eq 1 ]; then
                printf '[dry-run] cp %s %s\n' "$src" "$dst"
            else
                cp "$src" "$dst"
                printf 'installed (copy): %s\n' "$dst"
            fi
            ;;
        link)
            if [ "$DRY_RUN" -eq 1 ]; then
                printf '[dry-run] ln -s %s %s\n' "$src" "$dst"
            else
                ln -s "$src" "$dst"
                printf 'installed (link): %s -> %s\n' "$dst" "$src"
            fi
            ;;
    esac
}

# Hook scripts: hooks/<name> → ~/.claude/<name>
for script in "$SHANNON_DIR/hooks"/*.sh "$SHANNON_DIR/hooks"/jsonl-to-md.py; do
    [ -e "$script" ] || continue
    install_file "$script" "$CLAUDE_DIR/$(basename "$script")"
done

# Seed memories: memory-seed/<name>.md → ~/.claude/memory/<name>.md
for seed in "$SHANNON_DIR/memory-seed"/*.md; do
    [ -e "$seed" ] || continue
    install_file "$seed" "$CLAUDE_DIR/memory/$(basename "$seed")"
done

# CLAUDE.md template: claude-md/CLAUDE.example.md → ~/.claude/CLAUDE.md
install_file "$SHANNON_DIR/claude-md/CLAUDE.example.md" "$CLAUDE_DIR/CLAUDE.md"

# settings.json — write the snippet directly if missing, otherwise merge.
SETTINGS="$CLAUDE_DIR/settings.json"
SNIPPET="$SHANNON_DIR/hooks/settings.json.snippet"
if [ ! -e "$SETTINGS" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '[dry-run] cp %s %s\n' "$SNIPPET" "$SETTINGS"
    else
        cp "$SNIPPET" "$SETTINGS"
        printf 'installed (copy): %s\n' "$SETTINGS"
    fi
else
    # Merging into an existing settings.json requires jq.
    if ! command -v jq >/dev/null 2>&1; then
        cat >&2 <<'EOF'

install.sh: jq is required to merge Shannon's hooks into an existing
~/.claude/settings.json. Install jq and re-run:

  Debian / Ubuntu: sudo apt install jq
  macOS (Homebrew): brew install jq
  Other platforms: https://jqlang.github.io/jq/download/
EOF
        exit 1
    fi

    # Merge semantics: for each (event, matcher) in the snippet,
    #   - if no entry with that matcher exists in the target → append our entry;
    #   - if an entry with that matcher exists AND has "_shannon": true →
    #     treat as Shannon-managed and replace with our entry;
    #   - if an entry with that matcher exists but lacks the marker →
    #     leave the user's entry alone and warn.
    # The "_shannon" marker is an unknown-to-Claude-Code field that survives
    # parsing (empirically; see docs/installer-caveats.md). It is more robust
    # than matching by script name, since it survives script renames and
    # doesn't require maintaining a hardcoded allowlist here.
    # Other events / matchers in the target settings.json are untouched.
    # Top-level "env" keys from the snippet are appended when absent; a key the
    # user has set to a different value is left alone and reported.
    filter=$(cat <<'JQ_FILTER'
def is_shannon_entry:
  ._shannon == true;

. as $target |
$snippet[0] as $s |
($s.hooks // {}) as $sHooks |

reduce ($sHooks | to_entries[]) as $eventPair (
  {result: $target, report: []};
  ($eventPair.key) as $event |
  reduce $eventPair.value[] as $sEntry (.;
    ($sEntry.matcher) as $m |
    (.result.hooks[$event] // []) as $tEvent |
    ([$tEvent | .[] | select(.matcher == $m)] | first // null) as $existing |
    if $existing == null then
      .result.hooks //= {} |
      .result.hooks[$event] //= [] |
      .result.hooks[$event] |= . + [$sEntry] |
      .report += ["append: \($event)/\($m)"]
    elif ($existing | is_shannon_entry) then
      .result.hooks[$event] |= map(if .matcher == $m then $sEntry else . end) |
      .report += ["update (shannon-managed): \($event)/\($m)"]
    else
      .report += ["skip (user-customized): \($event)/\($m)"]
    end
  )
)
| ($s.env // {}) as $sEnv
| reduce ($sEnv | to_entries[]) as $envPair (.;
    if (.result.env[$envPair.key] // null) == null then
      .result.env //= {} |
      .result.env[$envPair.key] = $envPair.value |
      .report += ["append: env/\($envPair.key)"]
    elif .result.env[$envPair.key] == $envPair.value then
      .report += ["ok (already set): env/\($envPair.key)"]
    else
      .report += ["skip (user-customized): env/\($envPair.key)"]
    end
  )
JQ_FILTER
)

    merged=$(jq --slurpfile snippet "$SNIPPET" "$filter" "$SETTINGS")

    # Print the report
    printf '%s' "$merged" | jq -r '.report[]'

    if [ "$DRY_RUN" -eq 1 ]; then
        printf '[dry-run] would update %s\n' "$SETTINGS"
    else
        # Backup before writing, in case the merge result is unexpected.
        backup="$SETTINGS.bak.$(date +%s)"
        cp "$SETTINGS" "$backup"
        printf '%s' "$merged" | jq '.result' > "$SETTINGS"
        printf 'merged: %s (backup at %s)\n' "$SETTINGS" "$backup"
    fi
fi

cat <<'EOF'

──────────────────────────────────────────────────────────────────────
Shannon install complete.

Activation:
  - On Linux, Claude Code watches ~/.claude/settings.json and hot-reloads
    it when the file changes, so the new hook entries take effect on the
    next prompt submission in any running session — no restart needed.
  - On macOS and Windows (including WSL targeting the Windows-side
    filesystem) we have not verified that the watcher behaves the same.
    If the new hooks don't seem to fire, restart `claude`, or open the
    `/hooks` dialog and dismiss it with Esc (this forces a reload).
  - In any case, restarting `claude` is guaranteed to pick up the new
    entries.

EOF

if [ "$MODE" = "copy" ]; then
    cat <<'EOF'
Copy-mode notes:
  - Files placed in ~/.claude/ are copies of the shipped Shannon
    versions. Edits there will NOT flow back to Shannon's source;
    re-run the installer (with manual conflict handling) when Shannon
    is updated upstream.
──────────────────────────────────────────────────────────────────────
EOF
else
    cat <<'EOF'
Link-mode notes:
  - ~/.claude/<file> entries are symlinks to the Shannon source.
    Edits to either side surface as `git diff` in the Shannon repo and
    can be committed back upstream.
──────────────────────────────────────────────────────────────────────
EOF
fi
