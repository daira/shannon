# TODO

Tracking list for Shannon work. Entries are brief; details for any item live in `docs/<topic>.md` when one exists.

## Tests

<!-- See also: `docs/testing.md` is the canonical source for the test design and the per-script test-case tables. The TODO items below should not enumerate test counts or per-case details (those belong in `docs/testing.md`); edits to the test design happen there, not here. If a TODO item adds or removes a *script* to be tested, both files need updating. -->

- [x] Write the bats suite for `check-memory-synthesis.sh`. Lives at `tests/check-memory-synthesis.bats`; 13 tests covering all rows of the per-case table in `docs/testing.md`, including a parse-check. Mutation-tested to confirm the assertions actually catch regressions (changing the project-scoped reminder text caused only the project-scoped row to fail).
- [ ] Add `tests/fixtures/` (stdin payloads, fixture memory corpora at green / yellow / red sizes, sample transcript).
- [ ] `.github/workflows/test.yml` running `bats tests/` via `bats-core/bats-action`.
- [ ] `session-start.sh` and `save-session.sh` test cases.
- [ ] `check-tmp-path.sh` test cases.

## Hook scripts

- [x] Move `check-memory-synthesis.sh`, `session-start.sh`, and `save-session.sh` into `hooks/`. The three scripts now live in `shannon/hooks/` and the maintainer's `~/.claude/<name>.sh` paths are symlinks pointing at them. Content is verbatim from the maintainer's setup (no separate sanitization pass was needed — the scripts were already generic).
- [x] Decide the `~/.claude/jsonl-to-md.py` dependency for `save-session.sh`. Decision: ship the helper in Shannon — it now lives at `hooks/jsonl-to-md.py`, and the maintainer's `~/.claude/jsonl-to-md.py` is a symlink pointing at it. `save-session.sh`'s reference path is unchanged; on the end-user install, the installer will place the helper at `~/.claude/jsonl-to-md.py` alongside the scripts.
- [x] Refine `check-memory-synthesis.sh` to branch on path class in-script. The script now handles the cases where the default synthesis-plus-sanitization reminder does not fit; see the script's header for the current set. The match-in-script vs match-in-`if`-field design rationale is captured in `CLAUDE.md`'s Conventions section.
- [x] Add `check-tmp-path.sh` Bash `PreToolUse` hook. Emits a reminder when the agent runs a Bash command referencing `/tmp/` (with the exception of `/tmp/claude-*` paths), nudging scratch files under `<project>/tmp/` instead. Cross-referenced with the global `feedback_use_repo_tmp.md` memory body so edits to either side stay in sync.

## Installer

- [x] Fill in `install.sh`. Implements `--copy` (default) and `--link` modes plus `--dry-run`. Non-destructive: existing files are skipped, never overwritten. `--force` is not yet implemented; defer to a future enhancement (the manual-mv-aside workflow covers the current need). The maintainer's setup of pre-symlinked files is correctly recognised as already-installed (every `install_file` reports "skip (exists)").
- [x] Write `hooks/settings.json.snippet` and implement `settings.json` merge. The fragment mirrors the maintainer's hooks block; the installer deep-merges via jq when the target file exists, identifying Shannon-managed entries by an `_shannon: true` marker on each entry (verified empirically that Claude Code's settings parser tolerates unknown fields). Per-event/matcher behaviour: append if absent, update if marker-bearing, skip with a warning otherwise. Backups written before overwriting.
- [x] Post-install message gives platform-specific activation instructions: Linux hot-reloads `~/.claude/settings.json` on file change (verified empirically), so new hooks fire on the next prompt without restart; on macOS / Windows the watcher behaviour is unverified, so the message points users at `/hooks` dismissal or restart as a fallback.
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
