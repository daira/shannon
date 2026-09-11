# TODO

Tracking list for Shannon work. Entries are brief; details for any item live in `docs/<topic>.md` when one exists.

## Tests

<!-- See also: `docs/testing.md` is the canonical source for the test design and the per-script test-case tables. The TODO items below should not enumerate test counts or per-case details (those belong in `docs/testing.md`); edits to the test design happen there, not here. If a TODO item adds or removes a *script* to be tested, both files need updating. -->

- [x] Write the bats suite for `check-memory-synthesis.sh`. Lives at `tests/check-memory-synthesis.bats`; 13 tests covering all rows of the per-case table in `docs/testing.md`, including a parse-check. Mutation-tested to confirm the assertions actually catch regressions (changing the project-scoped reminder text caused only the project-scoped row to fail).
- [x] Add `tests/fixtures/`. Contains the transcript fixtures used by `tests/save-session.bats`: a valid transcript, a partially malformed one, an all-malformed one, and two non-UTF-8 variants (bytes-inside-a-string and bytes-corrupting-the-structure). The other suites don't need fixture files — `check-memory-synthesis.bats` and `check-tmp-path.bats` use inline JSON payloads, and `session-start.bats` builds its memory-corpus and project-context directories dynamically in `setup()` (shrunk via `SHANNON_CONTEXT_SIZE=1000` so the corpora stay byte-sized).
- [x] `.github/workflows/test.yml` running the bats suite on push and PR. Installs `bats` and `jq` via apt (simpler than `bats-core/bats-action` and avoids one more third-party action to pin). Top-level `permissions: contents: read`; `actions/checkout` pinned to a release SHA with `persist-credentials: false`.
- [x] `.github/workflows/zizmor.yml` running `zizmor` on the workflow files themselves on push and PR. Uses `uvx zizmor` after `astral-sh/setup-uv`; both actions SHA-pinned with the release tag in a trailing comment.
- [x] `.github/dependabot.yml` for the `github-actions` ecosystem with a 7-day cooldown, so the SHA pins above stay current without burying the repo in PRs.
- [x] `session-start.sh` test cases. Lives at `tests/session-start.bats`; 10 tests covering all rows of the per-case table (parse-check, reminder text always emitted, empty / green / yellow / red corpus sizing, CLAUDE.md / AGENTS.md project-context presence and absence). Uses per-test HOME and CLAUDE_PROJECT_DIR overrides into `BATS_TEST_TMPDIR` plus a dynamic `size_corpus` helper rather than checked-in fixture directories. Surfaced an empty-corpus crash in the script, fixed in the preceding commit.
- [x] `save-session.sh` test cases. Lives at `tests/save-session.bats`; see `docs/testing.md` for the per-case table. Uses checked-in fixture transcripts under `tests/fixtures/` (well-formed, partially malformed, all-malformed, and two non-UTF-8 variants). Surfaced the non-UTF-8 traceback behaviour in `jsonl-to-md.py`, tolerated via the preceding commit through `errors="replace"`.
- [x] `check-tmp-path.sh` test cases. Lives at `tests/check-tmp-path.bats`; 10 tests covering all rows of the per-case table in `docs/testing.md` (the four trigger patterns, the `/tmp/claude-*` exemption, two non-trigger / false-positive cases, missing-field and malformed-JSON canaries, plus a parse-check). Mutation-tested: changing the exemption pattern caused only the exempt-case test to fail.

- [ ] `install.sh` test cases (the settings.json merge). The jq filter now
  merges both `hooks` entries (append / update-shannon-managed / skip-user-
  customized, keyed by the `_shannon` marker) and top-level `env` keys
  (append when absent / ok when already equal / skip when the user set a
  different value; added 2026-08-13 for `GIT_SEQUENCE_EDITOR`/`GIT_EDITOR`).
  Neither path has a bats suite; the env path has only been checked by
  running the extracted filter by hand against an empty and a
  user-customized target. Per-case table to go in `docs/testing.md`.

## Hook scripts

- [x] Move `check-memory-synthesis.sh`, `session-start.sh`, and `save-session.sh` into `hooks/`. The three scripts now live in `shannon/hooks/` and the maintainer's `~/.claude/<name>.sh` paths are symlinks pointing at them. Content is verbatim from the maintainer's setup (no separate sanitization pass was needed — the scripts were already generic).
- [x] Decide the `~/.claude/jsonl-to-md.py` dependency for `save-session.sh`. Decision: ship the helper in Shannon — it now lives at `hooks/jsonl-to-md.py`, and the maintainer's `~/.claude/jsonl-to-md.py` is a symlink pointing at it. `save-session.sh`'s reference path is unchanged; on the end-user install, the installer will place the helper at `~/.claude/jsonl-to-md.py` alongside the scripts.
- [x] Refine `check-memory-synthesis.sh` to branch on path class in-script. The script now handles the cases where the default synthesis-plus-sanitization reminder does not fit; see the script's header for the current set. The match-in-script vs match-in-`if`-field design rationale is captured in `CLAUDE.md`'s Conventions section.
- [x] Add `check-tmp-path.sh` Bash `PreToolUse` hook. Emits a reminder when the agent runs a Bash command referencing `/tmp/` (with the exception of `/tmp/claude-*` paths), nudging scratch files under `<project>/work/` instead. Cross-referenced with the global `feedback_repo_scratch_dirs.md` memory body so edits to either side stay in sync.
- [x] Confirmed the hook scripts run correctly on macOS (15.3.1, Apple Silicon). All five (`check-tmp-path.sh`, `check-memory-synthesis.sh`, `session-start.sh`, `save-session.sh`, `jsonl-to-md.py`) execute against the system `bash`/`awk`/`paste`/`wc`/`date` and nix `jq`/`python3` — no GNU-isms or Linux-only paths; the reminder-emitting hooks and their exemptions (`/tmp/claude-*`, `MEMORY.md`) behave as on Linux. This is *script-execution* portability; whether Claude Code hot-reloads `settings.json` on macOS was verified later (2026-09-11, macOS 15.3, Darwin 24.3): a `PreToolUse` hook added to `~/.claude/settings.json` fired on the next tool call of the running session, with no restart. The Installer post-install message still describes this as unverified (see the Installer item below).
- [ ] Update `check-tmp-path.sh` to check whether `work` and `keep` are already gitignored rather than suggesting that the agent check.

## Installer

- [x] Fill in `install.sh`. Implements `--copy` (default) and `--link` modes plus `--dry-run`. Non-destructive: existing files are skipped, never overwritten (unless `--force` — see below). The maintainer's setup of pre-symlinked files is correctly recognised as already-installed (every `install_file` reports "skip (exists)").
- [x] **`--force` option + broken-symlink warning.** `--force` replaces existing destinations instead of skipping: a regular file is backed up to `<file>.bak.<timestamp>` first; an existing symlink (including a broken or mis-pointed one) is replaced — so `--link --force` repairs links a prior install left dangling. Independently, *without* `--force` a skipped destination that is a broken symlink is now reported as a stderr warning suggesting `--force`, rather than a silent `skip (exists)`. Does not touch the settings.json merge (already merge-and-backup). Supersedes the manual-mv-aside note here and on the `--link` item below. Manually tested (no-force warning, dry-run, and force repairing a broken seed-memory link + backing up a real file); no bats coverage yet.
- [x] Write `hooks/settings.json.snippet` and implement `settings.json` merge. The fragment mirrors the maintainer's hooks block; the installer deep-merges via jq when the target file exists, identifying Shannon-managed entries by an `_shannon: true` marker on each entry (verified empirically that Claude Code's settings parser tolerates unknown fields). Per-event/matcher behaviour: append if absent, update if marker-bearing, skip with a warning otherwise. Backups written before overwriting.
- [x] Post-install message gives platform-specific activation instructions: Linux hot-reloads `~/.claude/settings.json` on file change (verified empirically), so new hooks fire on the next prompt without restart; on macOS / Windows the watcher behaviour is unverified, so the message points users at `/hooks` dismissal or restart as a fallback.
- [ ] Update the post-install message in `install.sh` (and `docs/installer-caveats.md`, if written) now that the macOS watcher is verified (2026-09-11, see the Hook scripts section): macOS joins Linux in the hot-reload case, leaving Windows as the unverified platform.
- [x] **Symlink install mode (`--link`).** Implemented in `install.sh`. Copy-install is the default for end users; `--link` is for developers and contributors who want their edits to flow back into Shannon's source. Per-file symlinks point `~/.claude/memory/<seed>.md` at `<shannon-checkout>/memory-seed/<seed>.md` (and the same for `~/.claude/<name>.sh` → `<shannon-checkout>/hooks/<name>.sh`, and `~/.claude/CLAUDE.md` → `<shannon-checkout>/claude-md/CLAUDE.example.md`). Editing a memory or hook then directly modifies the Shannon source. The installer rejects `--link` on filesystems without symlink support (probes with a test symlink to `/dev/null`); developers on Windows should use WSL. Existing files at the destination are SKIPPED rather than overwritten — manual move-aside is the current workflow for resolving conflicts.
- [x] One-time memory-seed reconcile for the maintainer's setup. Each of the four seed memories that overlapped with `~/.claude/memory/` — `feedback_memory_size_budget.md`, `feedback_rich_memory_summaries.md`, `feedback_external_reports.md`, and `feedback_memory_vs_skill.md` — now exists as a symlink in `~/.claude/memory/` pointing at the Shannon source. No drift possible for these files.
- [x] One-time hook-script reconcile for the maintainer's setup. All shipped hook scripts now live in `shannon/hooks/`; the maintainer's `~/.claude/<name>.sh` paths are symlinks pointing at them. No drift possible.
- [ ] **Idea (option B): content-hash manifest install** (dpkg-conffile pattern), as an alternative for the *end-user* install mode. The installer copies seeds into `~/.claude/memory/` *and* records source hashes in a sidecar manifest (`~/.claude/memory/.shannon-manifest.json`). On `shannon update`: if the user's local file is unchanged from the recorded hash, auto-update; if diverged, prompt or offer a 3-way merge. Strictly better than "skip if exists" because it surfaces drift to the user instead of letting it accumulate silently. Considered complicated for v1 — kept as a future enhancement.
- [ ] **Filed-elsewhere (option C): Anthropic feature request for native multi-directory memory loading.** Drafted but not filed yet. If accepted, this obsoletes both A and B by letting Claude Code load from a list of memory directories natively — no copy or symlink step.

## CLAUDE.md template

- [x] Write `claude-md/CLAUDE.example.md`. Covers the four candidate imperatives (synthesis-check before memory writes, no-push-without-explicit-request, attribution for assisted artifacts, scrub project-identifying details in global memories and external reports) plus a closing "adding rules to this file" guard that keeps the template minimal over time.

## Seed memories — remaining

- [ ] `feedback_no_push_without_request.md` (port from `~/.claude/memory/`, sanitize).
- [ ] `feedback_commit_coauthor.md` (port + sanitize; the per-org short-form rule must be replaced with generic guidance, since it is specific to the originating user's repos).
- [ ] `feedback_factor_hook_scripts.md` (port + sanitize).
- [ ] `feedback_silent_progress_polling.md` — port, or move to the opt-in tier if narration thresholds are too user-specific.

Already written: `feedback_memory_size_budget`, `feedback_rich_memory_summaries`, `feedback_external_reports`, `feedback_memory_vs_skill`, `feedback_shell_quoting_review`.

## Opt-in memories tier

- [ ] Decide the mechanism: subdirectory under `memory-seed/`? Separate top-level dir? How does the installer let users opt in?
- [ ] Fill in the README "Opt-in memories" TBD section once the mechanism is settled.
- [ ] Likely initial candidates: git-cluster memories, narration discipline, commit-message conventions, prose-style preferences.

## README placeholders

- [x] Resolve `<owner>` in the quick-start `git clone` URL once canonical home is decided.
- [ ] Fill in the "How current LLMs do and don't remember things" TBD section — background on context vs memory-files, context limits, what compaction is, why compaction can be lossy, the role of the harness.
- [ ] Fill in the "Opt-in memories" TBD (depends on the opt-in mechanism above).
- [ ] Decide whether to split a `docs/design-principles.md` out of the README when length crosses a threshold.

## Other docs

- [ ] Write `docs/extending.md` — referenced from the README "Extending" section, does not exist yet.
- [ ] Consider `docs/installer-caveats.md` for settings-reload semantics (Linux-watched, macOS / Windows unverified) and other harness-loading details relevant to the installer.

## Commits

- [x] Commit the initial accumulated state — done in `fe8b46f`. Scope: contributor `CLAUDE.md` extensions (sanitization rules, tests-expected, task-body-pointer); `Memories vs skills` section in the README + `feedback_memory_vs_skill.md` seed; `feedback_external_reports.md` seed; `docs/testing.md`; the friction-reduction principle in the README; `TODO.md` (this file).
- [x] Commit the further state accumulated since `fe8b46f`. The installer-section design captures, `docs/testing.md` additions for the path-class exclusion cases, the contributor `CLAUDE.md` extension recording the match-in-script vs match-in-`if`-field hook-design rule, the `hooks/settings.json.snippet` and four hook scripts, the jq-based `settings.json` merge with marker-based detection, the `CLAUDE_DIR` override, and the platform-specific post-install activation message have all landed in subsequent commits.
