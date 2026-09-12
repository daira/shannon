# Testing Shannon

To run the test suite, first [ensure that `bats` is installed](https://bats-core.readthedocs.io/en/stable/installation.html):

- Debian / Ubuntu: `sudo apt install bats`
- macOS: `brew install bats-core`
- Nix: `nix profile install nixpkgs#bats`
- npm: `npm install -g bats`

To run all tests:
```
bats tests
```

To run a single test (for example `check-memory-synthesis`):
```
bats tests/check-memory-synthesis.bats
```

The remainder of this document discusses writing and maintaining tests.

## Testing the hook scripts

Shannon ships several hook scripts in `hooks/`:

- `check-memory-synthesis.sh` — `PreToolUse` hook that fires on `Write|Edit` and injects a synthesis-check reminder when the target path looks like a memory file.
- `check-tmp-path.sh` — `PreToolUse` hook for the `Bash` tool that reminds the agent about path conventions, in particular not to use the global `/tmp`.
- `check-portable-commands.sh` — `PreToolUse` hook for the `Bash` tool that denies a command invoking, in command position, a platform-native tool from a native/preferred table (seeded with `sed`/`gsed`) when the preferred implementation is installed under another name and is a different binary.
- `session-start.sh` — `SessionStart` / `PostCompact` hook that emits the memory-re-read reminder and reports the corpus size.
- `save-session.sh` — `PreCompact` hook that snapshots the current transcript to `<project>/keep/`.

Each script needs a unit test, and eventually a CI workflow that runs them on push and pull-request.

### Testing pattern

Synthesize the stdin JSON each hook receives, pipe it to the script, and assert on three things:

1. **Exit code** — almost always 0 (non-blocking). The exception is `save-session.sh` which exits 1 on a missing transcript and 2 on a missing argument.
2. **Stdout JSON shape** — for hooks that emit `hookSpecificOutput.additionalContext`, the output should parse as JSON and contain the expected fields.
3. **Filesystem side effects** — for `save-session.sh`, the test should check that the expected output files are created in `${CLAUDE_PROJECT_DIR}/keep/`.

This pattern follows the `/update-config` skill's "Constructing a Hook (with verification)" workflow.

### Parse-check every script first

Before any behavioural test, the bats suite should parse-check each script — `bash -n <script>` for shell scripts, `python3 -m py_compile <script>` for the Python helper. A regression that breaks parsing is the most disruptive failure mode for a hook script: it surfaces as the hook erroring on every tool invocation until fixed, often with confusing error messages that point at a token deep inside an `additionalContext` JSON literal rather than at the real cause. `bash -n` runs the syntax check without execution; it is fast and catches the whole class — apostrophes that close a single-quoted shell argument (see `feedback_shell_quoting_review.md`), unclosed strings, unmatched braces or parens, malformed heredocs, trailing-backslash continuation errors.

Bats sketch:

```bash
@test "check-memory-synthesis.sh parses" {
  run bash -n "$BATS_TEST_DIRNAME/../hooks/check-memory-synthesis.sh"
  [ "$status" -eq 0 ]
}
```

Repeat for every shell script in `hooks/`; for `jsonl-to-md.py` substitute `python3 -m py_compile`. These parse-checks are the precondition that makes the behavioural assertions below meaningful — a script that fails to parse cannot be tested behaviourally at all.

<!-- See also: `TODO.md` "Tests" section references these tables. The TODO
     deliberately does not enumerate cases; these tables are the authoritative
     source for the per-case test design. Edits to the test cases here do
     not require TODO updates unless a whole script's worth of cases is
     added or removed. -->

### `check-memory-synthesis.sh`

| Case | Stdin payload | Expected |
|---|---|---|
| Global memory path | `{"tool_name":"Write","tool_input":{"file_path":"/home/foo/.claude/memory/x.md"}}` | exit 0, default reminder emitted (synthesis + sanitization) |
| Project memory path | `{"tool_name":"Write","tool_input":{"file_path":"/home/foo/.claude/projects/slug/memory/x.md"}}` | exit 0, JSON emitted with a *project-scoped* `additionalContext` — both the project-vs-global check and the synthesis check, since a lesson with cross-project applicability belongs in the global tree instead. |
| `MEMORY.md` (index) | `{"tool_name":"Edit","tool_input":{"file_path":"/home/foo/.claude/memory/MEMORY.md"}}` | exit 0, no output. The exclusion lives in the script (not in `settings.json`'s `if` field), because Claude Code's permission-rule syntax supports prefix matches but not negation. The same exclusion applies to project-scoped `MEMORY.md` and to `memory-seed/MEMORY.md`. |
| Non-memory path | `{"tool_name":"Write","tool_input":{"file_path":"/tmp/random.txt"}}` | exit 0, no output |
| Edit-shaped input | `{"tool_name":"Edit","tool_input":{"file_path":"/home/foo/.claude/memory/x.md","old_string":"a","new_string":"b"}}` | exit 0, JSON emitted (Edit and Write share the `file_path` field, so the script handles both) |
| Malformed JSON on stdin | `not-json` | exit 0, no output (the script must never block the tool) |
| Missing `file_path` | `{"tool_name":"Write","tool_input":{}}` | exit 0, no output |
| `user_*.md` (user profile memory) | `{"tool_name":"Edit","tool_input":{"file_path":"/home/foo/.claude/memory/user_alice.md"}}` | exit 0, JSON emitted with a *path-aware* `additionalContext` — synthesis question still applies ("is this addition at home in this user profile, or does it belong in a feedback memory?") but the sanitization clause is dropped (named attribution is the point of these files). |
| Memory-seed source path | `{"tool_name":"Edit","tool_input":{"file_path":"/path/to/shannon-checkout/memory-seed/feedback_x.md"}}` | exit 0, default reminder emitted — `*/memory-seed/*.md` matches via the fall-through case branch, so when a maintainer's Claude instance edits the seed source directly it gets the same synthesis-check coverage as when a user's Claude edits the installed copy at `~/.claude/memory/`. |

The malformed-input case is **load-bearing**: a subtle regression in error handling could silently start blocking memory writes, and the user would see the Write fail with no obvious cause. This test is the canary for that regression. The same property should hold for any future hook script Shannon ships.

### `check-tmp-path.sh`

The script inspects `.tool_input.command` for references to `/tmp/`. It emits a reminder when the command appears to be writing scratch under `/tmp/`, and exempts `/tmp/claude-*` paths (Claude Code's own scratch).

| Case | `.tool_input.command` | Expected |
|---|---|---|
| Literal `/tmp/<path>` | `touch /tmp/foo` | exit 0, reminder emitted |
| Bare `/tmp` argument (space-bounded) | `ls /tmp foo` | exit 0, reminder emitted (matches the ` /tmp ` form of the trigger pattern) |
| `=/tmp/<path>` flag | `mkdir --parents=/tmp/foo` | exit 0, reminder emitted |
| `=/tmp ` flag (trailing space) | `myscript --dir=/tmp other` | exit 0, reminder emitted |
| `/tmp/claude-*` (Claude Code scratch) | `cat /tmp/claude-abc/result.txt` | exit 0, no output (exempt) |
| Non-tmp command | `ls /home/user` | exit 0, no output |
| `tmp` substring outside `/tmp/` | `cat /home/user/tmpfile.txt` | exit 0, no output (no false positive) |
| Missing `command` field | `{"tool_input":{}}` | exit 0, no output |
| Malformed JSON on stdin | `not-json` | exit 0, no output (must never block the Bash tool) |

The malformed-input case is **load-bearing** here too — and arguably more so than for `check-memory-synthesis.sh`, because a blocking failure on a Bash `PreToolUse` hook would break *every* Bash command the agent runs, not just memory edits.

### `check-portable-commands.sh`

The script inspects `.tool_input.command` for an invocation, in command position, of a native tool listed in its table, and emits a `permissionDecision: deny` naming the preferred replacement. An entry is active only when the preferred tool is on PATH and resolves to a different file from the native one, so the tests build their own PATH: a stub directory with distinct `sed` and `gsed` executables, plus symlinks to the real `bash`, `jq`, `grep`, and `realpath`. Unless stated otherwise, the expected result is exit 0 with a deny JSON whose reason contains `` `sed` (use `gsed`) ``.

| Case | `.tool_input.command` | Expected |
|---|---|---|
| After a pipe | `grep x file \| sed -n 1p` | deny |
| At the start of the command | `sed -i s/a/b/ file` | deny |
| Preferred tool itself | `grep x file \| gsed -n 1p` | exit 0, no output |
| After variable assignments | `LC_ALL=C FOO=1 sed -e p file` | deny |
| After `xargs` with options | `cat list \| xargs -0 sed -i s/a/b/` | deny |
| After `find -exec` | `find . -name '*.md' -exec sed -i 's/a/b/' {} +` | deny |
| By absolute path | `/usr/bin/sed -n 1p file` | deny (an explicit path to the native tool is still the native tool) |
| On a later line of a multi-line command | `echo first` newline `sed -n 1p file` | deny |
| Mentioned in prose | `echo "we used sed here"` | exit 0, no output |
| As an argument | `git log --oneline \| grep sed` | exit 0, no output |
| As a word prefix | `echo sedimentary` | exit 0, no output |
| Preferred tool absent | stub `gsed` removed; `grep x file \| sed -n 1p` | exit 0, no output (entry inert, as on a machine without GNU sed under another name) |
| Native name is the preferred tool | stub `sed` replaced by a symlink to `gsed`; `grep x file \| sed -n 1p` | exit 0, no output (entry inert, as on a GNU system) |
| Missing `command` field | `{"tool_input":{}}` | exit 0, no output |
| Malformed JSON on stdin | `not-json` | exit 0, no output (must never block the Bash tool) |

Known limitation, not tested: a heredoc body line that begins with the tool name is indistinguishable from a command line and is denied.

### `session-start.sh`

| Case | Setup | Expected |
|---|---|---|
| Empty memory corpus | `HOME` points at a fixture with no `~/.claude/memory/*.md` files | reports 0 files, ~0 tokens; no yellow / red warning |
| Green corpus (token count below the yellow threshold) | Fixture corpus sized below the yellow band for the configured `SHANNON_CONTEXT_SIZE` | no warning |
| Yellow corpus (token count between the yellow and red thresholds) | Fixture corpus sized into the yellow band for the configured `SHANNON_CONTEXT_SIZE` | yellow warning emitted |
| Red corpus (token count above the red threshold) | Fixture corpus sized into the red band for the configured `SHANNON_CONTEXT_SIZE` | red warning emitted |
| With project `CLAUDE.md` | `CLAUDE_PROJECT_DIR` set to a fixture dir containing a `CLAUDE.md` | project-context line mentions the file and its token estimate |
| Without project `CLAUDE.md` | `CLAUDE_PROJECT_DIR` set to a dir without a `CLAUDE.md` | no project-context line |

**Strategy:** override `HOME` to a per-test fixture directory containing a synthesized memory corpus, and `CLAUDE_PROJECT_DIR` for the project-context cases. Sizing the corpus is done by writing fixture `.md` files whose total byte count puts the corpus into the green / yellow / red band. Tests also set `SHANNON_CONTEXT_SIZE=1000` (default 1000000) so the threshold values shrink from 50k / 100k tokens to 50 / 100 tokens; the fixture corpus then stays byte-sized (~100 B for green, ~500 B for red) rather than ~500 KB per test, keeping the suite's disk and I/O footprint negligible without changing the ratios under test.

### `save-session.sh`

| Case | Fixture | Expected |
|---|---|---|
| Valid transcript | `valid-transcript.jsonl` (two well-formed messages) | exit 0, timestamped `.jsonl` and `.md` files appear in `${CLAUDE_PROJECT_DIR}/keep/`; the `.jsonl` is byte-identical to the fixture and the `.md` is a rendered transcript. |
| Missing argument | (none — script invoked with no args) | exit 2, usage message on stderr |
| Empty argument | (none — script invoked with `""`) | exit 2, usage message on stderr |
| Nonexistent transcript | a path that does not exist | exit 1, not-found message on stderr |
| Partially malformed transcript | `partial-malformed-transcript.jsonl` (valid lines interleaved with non-JSON lines) | exit 0, `.md` contains the well-formed messages but not the garbage lines (per-line skip semantics in the helper). |
| All-malformed transcript | `all-malformed-transcript.jsonl` (no parseable JSON lines) | exit 0, `.md` contains just the header and no message lines. |
| Invalid UTF-8 inside a JSON string | `invalid-utf8-transcript.jsonl` (well-formed JSONL with raw `0xff 0xfe` bytes inside a `content` string) | exit 0, `.md` contains the rendered message with the bad bytes replaced by U+FFFD (verifying the helper opens with `errors="replace"`). |
| Invalid UTF-8 outside any JSON string | `structure-corrupting-utf8-transcript.jsonl` (raw `0xff 0xfe` injected between JSON tokens) | exit 0, `.md` contains just the header. The replacement happens uniformly across the line; the post-replacement line is no longer valid JSON, so the per-line skip handles it as a malformed line. |

**Strategy:** fixture transcripts under `tests/fixtures/`, plus per-test overrides of `HOME` and `CLAUDE_PROJECT_DIR` into `$BATS_TEST_TMPDIR`. The script's hardcoded `${HOME}/.claude/jsonl-to-md.py` lookup is resolved by symlinking the shipped helper into the per-test `$HOME/.claude/` directory at `setup()`, so the test doesn't depend on whether the user has the helper installed.

## Testing the installer

`install.sh` is tested end to end. Each test runs the installer with `CLAUDE_DIR` pointing at a fresh directory under `$BATS_TEST_TMPDIR` (the installer's destination override), so the real `~/.claude` is never touched, and asserts on the exit code, the report lines, and the files placed. One hook script and one seed memory serve as spot checks; the installer treats every file of a kind the same way.

### `install.sh`

| Case | Setup and invocation | Expected |
|---|---|---|
| `--help` | `install.sh --help` | exit 0, usage printed |
| Unknown option | `install.sh --bogus` | exit 2, "unknown option" and the usage on stderr |
| Fresh copy install | empty destination; `install.sh` | exit 0; hook scripts, `jsonl-to-md.py`, seed memories, and `CLAUDE.md` are regular files identical to their sources; `settings.json` is the snippet verbatim; "installed (copy):" lines and the copy-mode notes |
| Fresh link install | empty destination; `install.sh --link` | exit 0; the destinations are symlinks to the checkout's files; "installed (link):" lines and the link-mode notes |
| Second run | after a copy install; `install.sh` | exit 0; every file reported "skip (exists):" and nothing installed; the settings are re-merged ("update (shannon-managed):" per matcher, "ok (already set):" per env key) with a backup of the previous `settings.json` |
| `--dry-run` | empty destination; `install.sh --dry-run` | exit 0, "[dry-run]" lines for the directories, the copies, and the snippet; nothing created |
| Broken symlink, no `--force` | the destination hook is a symlink to a missing target; `install.sh` | exit 0, "skip (BROKEN symlink): ... re-run with --force to repair" on stderr; the broken link remains |
| `--force --link` on a broken symlink | as above; `install.sh --link --force` | exit 0; the link now points at the checkout's file |
| `--force` on a mis-pointed symlink | the destination hook links to another existing file; `install.sh --link --force` | exit 0; the link is replaced; its old target is untouched |
| `--force` on a regular file | the destination seed memory holds user edits; `install.sh --force` | exit 0, "backed up:" line; exactly one `<file>.bak.<timestamp>` holding the edits; the destination now equals the seed |
| `--force --dry-run` | as above; `install.sh --force --dry-run` | exit 0, "[dry-run] mv ... (backup before replace)" and "[dry-run] cp ..." lines; the file and the rest of the destination unchanged |
| Settings merge with user customizations | a `settings.json` with a user `PreToolUse`/`Bash` entry (no `_shannon` marker), `GIT_EDITOR` set to another value, and an unrelated key; `install.sh` | exit 0; "append:" for the other events and for `GIT_SEQUENCE_EDITOR`, "skip (user-customized):" for the Bash entry and for `GIT_EDITOR`; the result keeps the user's entry, values, and unrelated key, gains Shannon's marked entries, and the previous file is backed up |
| Missing `jq` | an existing `settings.json`; a PATH holding only `bash`, `dirname`, `mkdir`, `cp`, and `cat`; `install.sh` | exit 1, "jq is required to merge" on stderr |

Not covered: the symlink-support probe failing (it needs a filesystem without symlinks), and a checkout missing one of `hooks/`, `memory-seed/`, or `claude-md/`.

## Framework

Use **bats** ([bats-core](https://bats-core.readthedocs.io/)): the standard Bash test framework. It is installable via `apt`, `brew`, `nix`, or `npm`, and there is a `bats-core/bats-action` GitHub Action for CI. Plain shell tests would work too, but bats provides setup / teardown, clearer test naming, and tap-style output that CI parsers handle well.

If there is a reason to avoid the dependency on bats (very small test surface, contributors expected to run tests by hand only), a plain-shell harness with a small assertion helper is an acceptable alternative.

## Test layout

```
shannon/
├── tests/
│   ├── check-memory-synthesis.bats
│   ├── check-tmp-path.bats
│   ├── check-portable-commands.bats
│   ├── install.bats
│   ├── session-start.bats
│   ├── save-session.bats
│   └── fixtures/
│       └── valid-transcript.jsonl
└── .github/
    └── workflows/
        └── test.yml
```

`check-memory-synthesis.bats`, `check-tmp-path.bats`, and `check-portable-commands.bats` use inline payloads (no fixture files); the last builds its stub-and-symlink PATH in `setup()` under `$BATS_TEST_TMPDIR`. `session-start.bats` builds its memory-corpus and project-context directories dynamically in `setup()`, scoped to `$BATS_TEST_TMPDIR` and shrunk via `SHANNON_CONTEXT_SIZE=1000`. `install.bats` runs the installer against a per-test `CLAUDE_DIR` under `$BATS_TEST_TMPDIR`. Only `save-session.bats` needs a checked-in fixture (`valid-transcript.jsonl`) so the round-trip can be verified deterministically.

## CI

A GitHub Actions workflow under `.github/workflows/test.yml` should:

1. Check out the repo.
2. Set up bats via `bats-core/bats-action` (or install via `npm install -g bats` if that action isn't suitable).
3. Run `bats tests/`.
4. Fail the PR / push if any test fails.

Run on `push` and `pull_request`.

## Shannon scripts vs `~/.claude/` scripts

These tests target the Shannon-shipped versions in `hooks/`. A user's installed copies in `~/.claude/` may have local customisations that diverge from the seed. Test failures in Shannon's CI do not necessarily mean a user's customised local script is broken, and vice versa. The installer remains non-destructive so a user's customised local script is never overwritten without an explicit opt-in.

## Notes

- The `check-memory-synthesis.sh` script's path-matching uses a shell glob, which means it does not consult the `autoMemoryDirectory` setting (a Claude Code setting that lets a user redirect `~/.claude/memory/` elsewhere). For most users this is fine; for full generality a future revision could consult that setting, but the added complexity is probably not worth it for v1.
- On Linux, the Claude Code settings watcher **does** hot-reload `~/.claude/settings.json` on file change (verified empirically — see the installer's post-install Activation note). On macOS and Windows this is unverified. This affects the installer's UX claims, not the tests directly, but worth noting in case a future test wants to verify post-install activation — it would have to spawn a fresh `claude` process or rely on the watcher, both of which are out of scope for unit tests.
