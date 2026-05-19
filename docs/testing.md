# Testing the hook scripts

Shannon ships three hook scripts in `hooks/`:

- `check-memory-synthesis.sh` — `PreToolUse` hook that fires on `Write|Edit` and injects a synthesis-check reminder when the target path looks like a memory file.
- `session-start.sh` — `SessionStart` / `PostCompact` hook that emits the memory-re-read reminder and reports the corpus size.
- `save-session.sh` — `PreCompact` hook that snapshots the current transcript to `<project>/keep/`.

These scripts need unit tests, and eventually a CI workflow that runs them on push and pull-request.

## Testing pattern

Synthesize the stdin JSON each hook receives, pipe it to the script, and assert on three things:

1. **Exit code** — almost always 0 (non-blocking). The exception is `save-session.sh` which exits 1 on a missing transcript and 2 on a missing argument.
2. **Stdout JSON shape** — for hooks that emit `hookSpecificOutput.additionalContext`, the output should parse as JSON and contain the expected fields.
3. **Filesystem side effects** — for `save-session.sh`, the test should check that the expected output files are created in `${CLAUDE_PROJECT_DIR}/keep/`.

This pattern follows the `/update-config` skill's "Constructing a Hook (with verification)" workflow.

## Parse-check every script first

Before any behavioural test, the bats suite should parse-check each script — `bash -n <script>` for shell scripts, `python3 -m py_compile <script>` for the Python helper. A regression that breaks parsing is the most disruptive failure mode for a hook script: it surfaces as the hook erroring on every tool invocation until fixed, often with confusing error messages that point at a token deep inside an `additionalContext` JSON literal rather than at the real cause. `bash -n` runs the syntax check without execution; it is fast and catches the whole class — apostrophes that close a single-quoted shell argument (see `feedback_shell_quoting_review.md`), unclosed strings, unmatched braces or parens, malformed heredocs, trailing-backslash continuation errors.

Bats sketch:

```bash
@test "check-memory-synthesis.sh parses" {
  run bash -n "$BATS_TEST_DIRNAME/../hooks/check-memory-synthesis.sh"
  [ "$status" -eq 0 ]
}
```

Repeat for every shell script in `hooks/`; for `jsonl-to-md.py` substitute `python3 -m py_compile`. These parse-checks are the precondition that makes the behavioural assertions below meaningful — a script that fails to parse cannot be tested behaviourally at all.

## `check-memory-synthesis.sh`

<!-- See also: `TODO.md` "Tests" section references this table. The TODO
     deliberately does not enumerate cases; this table is the authoritative
     source for the per-case test design. Edits to the test cases here do
     not require TODO updates unless a whole script's worth of cases is
     added or removed. -->

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

## `session-start.sh`

| Case | Setup | Expected |
|---|---|---|
| Empty memory corpus | `HOME` points at a fixture with no `~/.claude/memory/*.md` files | reports 0 files, ~0 tokens; no yellow / red warning |
| Yellow corpus (50k–100k tokens) | Fixture corpus sized into the yellow band | yellow warning emitted |
| Red corpus (>100k tokens) | Fixture corpus sized into the red band | red warning emitted |
| With project `CLAUDE.md` | `CLAUDE_PROJECT_DIR` set to a fixture dir containing a `CLAUDE.md` | project-context line mentions the file and its token estimate |
| Without project `CLAUDE.md` | `CLAUDE_PROJECT_DIR` set to a dir without a `CLAUDE.md` | no project-context line |

**Strategy:** override `HOME` to a per-test fixture directory containing a synthesized memory corpus, and `CLAUDE_PROJECT_DIR` for the project-context cases. Sizing the corpus is done by writing fixture `.md` files whose total byte count puts the corpus into the green / yellow / red band.

## `save-session.sh`

| Case | Setup | Expected |
|---|---|---|
| Valid transcript | Fixture `.jsonl` transcript path, `CLAUDE_PROJECT_DIR` overridden | timestamped `.jsonl` and `.md` files appear in `${CLAUDE_PROJECT_DIR}/keep/` |
| Missing argument | Invoked with no argument | exit 2, usage message on stderr |
| Nonexistent transcript | Invoked with a path that does not exist | exit 1, error on stderr |

**Strategy:** fixture transcript and an overridden `CLAUDE_PROJECT_DIR`. The Markdown conversion step depends on `~/.claude/jsonl-to-md.py` being available; the test should either provide a fixture script or skip the Markdown assertion if the helper is absent (and confirm the `.jsonl` copy independently).

## Framework

Use **bats** ([bats-core](https://bats-core.readthedocs.io/)): the standard Bash test framework. It is installable via `apt`, `brew`, or `npm`, and there is a `bats-core/bats-action` GitHub Action for CI. Plain shell tests would work too, but bats provides setup / teardown, clearer test naming, and tap-style output that CI parsers handle well.

If there is a reason to avoid the dependency on bats (very small test surface, contributors expected to run tests by hand only), a plain-shell harness with a small assertion helper is an acceptable alternative.

## Test layout

```
shannon/
├── tests/
│   ├── check-memory-synthesis.bats
│   ├── session-start.bats
│   ├── save-session.bats
│   └── fixtures/
│       ├── empty-corpus/
│       ├── yellow-corpus/
│       ├── red-corpus/
│       ├── project-with-claudemd/
│       ├── project-without-claudemd/
│       └── valid-transcript.jsonl
└── .github/
    └── workflows/
        └── test.yml
```

## CI

A GitHub Actions workflow under `.github/workflows/test.yml` should:

1. Check out the repo.
2. Set up bats via `bats-core/bats-action` (or install via `npm install -g bats` if that action isn't suitable).
3. Run `bats tests/`.
4. Fail the PR / push if any test fails.

Run on `push` and `pull_request`.

## User-facing documentation

Contributors new to bats should be able to install it and run the suite without reading the bats documentation. Shannon's `README.md` — or a separate `docs/development.md` if the README grows too long — should cover:

- **Installing bats**, with one-line commands for the common platforms:
  - Debian / Ubuntu: `sudo apt install bats`
  - macOS: `brew install bats-core`
  - Cross-platform via npm: `npm install -g bats`
- **Running the test suite**: `bats tests/` from the repo root.
- **Running a single test file**: `bats tests/check-memory-synthesis.bats`.
- **Adding a new test**: a brief recipe with a pointer back to this document for the design conventions.

The audience is an open-source contributor arriving at the repo for the first time. Assume nothing about prior familiarity with bats.

## Shannon scripts vs `~/.claude/` scripts

These tests target the Shannon-shipped versions in `hooks/`. A user's installed copies in `~/.claude/` may have local customisations that diverge from the seed. Test failures in Shannon's CI do not necessarily mean a user's customised local script is broken, and vice versa. The installer remains non-destructive so a user's customised local script is never overwritten without an explicit opt-in.

## Notes

- The `check-memory-synthesis.sh` script's path-matching uses a shell glob, which means it does not consult the `autoMemoryDirectory` setting (a Claude Code setting that lets a user redirect `~/.claude/memory/` elsewhere). For most users this is fine; for full generality a future revision could consult that setting, but the added complexity is probably not worth it for v1.
- On Linux, the Claude Code settings watcher **does** hot-reload `~/.claude/settings.json` on file change (verified empirically — see the installer's post-install Activation note). On macOS and Windows this is unverified. This affects the installer's UX claims, not the tests directly, but worth noting in case a future test wants to verify post-install activation — it would have to spawn a fresh `claude` process or rely on the watcher, both of which are out of scope for unit tests.
