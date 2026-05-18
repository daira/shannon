# TODO

Tracking list for Shannon work. Entries are brief; details for any item live in `docs/<topic>.md` when one exists.

## Tests

- [ ] Write the bats suite (`tests/check-memory-synthesis.bats` first; six cases plus a seventh for excluding `MEMORY.md` from the reminder). See `docs/testing.md`.
- [ ] Add `tests/fixtures/` (stdin payloads, fixture memory corpora at green / yellow / red sizes, sample transcript).
- [ ] `.github/workflows/test.yml` running `bats tests/` via `bats-core/bats-action`.
- [ ] `session-start.sh` and `save-session.sh` test cases once those scripts are in `hooks/`.

## Hook scripts

- [ ] sanitize and copy `~/.claude/session-start.sh` and `~/.claude/save-session.sh` into `hooks/`. `save-session.sh` depends on `~/.claude/jsonl-to-md.py` — decide whether Shannon ships that helper, or makes the dependency optional and skips the Markdown rendering when it is absent.
- [ ] Refine `check-memory-synthesis.sh` to exclude `MEMORY.md` from the synthesis-check (the index file does not need it).

## Installer

- [ ] Fill in `install.sh`: non-destructive merge of hook scripts, `settings.json.snippet`, `memory-seed/`, and `CLAUDE.md.example` into `~/.claude/`. Skip existing files; offer `--force` and `--dry-run`.
- [ ] Write `hooks/settings.json.snippet` (the JSON fragment the installer merges).
- [ ] Post-install message must mention the no-hot-reload fact: the user should restart Claude Code or open `/hooks` to activate the new hooks.
- [ ] **Symlink install mode (`--link` or similar).** *Current direction (option A in the synced-memory discussion).* Copy-install is the default for end users; symlink-install is for developers and contributors who want their edits to flow back into Shannon's source. In symlink mode, per-file symlinks point `~/.claude/memory/<seed>.md` at `<shannon-checkout>/memory-seed/<seed>.md` (and the same for `~/.claude/<name>.sh` → `<shannon-checkout>/hooks/<name>.sh`, and `~/.claude/CLAUDE.md` → `<shannon-checkout>/claude-md/CLAUDE.md.example`). Editing a memory or hook then directly modifies the Shannon source; `git status` / `git diff` surfaces pending changes; `git pull` brings upstream updates in automatically. **Without this mode, drift between a user's local copy and Shannon's seed is unavoidable and the installer cannot reconcile it without overwriting.** Decisions needed: handling when the symlink target already exists as a regular file (move-aside-and-link, refuse with a diff, or interactive prompt). Windows portability is not a primary concern — the installer should reject `--link` if symlinks are unavailable on the platform; developers on Windows typically use WSL, where symlinks work normally.
- [ ] One-time reconcile for the maintainer's existing setup: for each personal memory under `~/.claude/memory/` that overlaps with a Shannon seed, diff against the seed, take the canonical version, then replace the personal file with a symlink to the Shannon source. Same for the hook scripts already installed under `~/.claude/`. After that pass, no drift is possible.
- [ ] **Idea (option B): content-hash manifest install** (dpkg-conffile pattern), as an alternative for the *end-user* install mode. The installer copies seeds into `~/.claude/memory/` *and* records source hashes in a sidecar manifest (`~/.claude/memory/.shannon-manifest.json`). On `shannon update`: if the user's local file is unchanged from the recorded hash, auto-update; if diverged, prompt or offer a 3-way merge. Strictly better than "skip if exists" because it surfaces drift to the user instead of letting it accumulate silently. Considered complicated for v1 — kept as a future enhancement.
- [ ] **Filed-elsewhere (option C): Anthropic feature request for native multi-directory memory loading.** Drafted but not filed yet. If accepted, this obsoletes both A and B by letting Claude Code load from a list of memory directories natively — no copy or symlink step.

## CLAUDE.md template

- [ ] Write `claude-md/CLAUDE.md.example`. Keep minimal — only irreducible imperatives. Candidates: synthesis-check, no-push-without-explicit-request, attribution requirement, scrub-paths-in-global-memories.

## Seed memories — remaining

- [ ] `feedback_no_push_without_request.md` (port from `~/.claude/memory/`, sanitize).
- [ ] `feedback_commit_coauthor.md` (port + sanitize; the per-org short-form rule must be replaced with generic guidance, since it is specific to the originating user's repos).
- [ ] `feedback_factor_hook_scripts.md` (port + sanitize).
- [ ] `feedback_silent_progress_polling.md` — port, or move to the opt-in tier if narration thresholds are too user-specific.

Already written: `feedback_memory_size_budget`, `feedback_rich_memory_summaries`, `feedback_external_reports`, `feedback_memory_vs_skill`.

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
- [ ] Consider `docs/installer-caveats.md` for the no-hot-reload fact, the settings-watcher subtlety, and other harness-loading semantics relevant to the installer.

## Commits

- [ ] Commit the current accumulated state before further changes accrue. Coherent scope: contributor `CLAUDE.md` extensions (sanitization rules, tests-expected, task-body-pointer); `Memories vs skills` section in the README + `feedback_memory_vs_skill.md` seed; `feedback_external_reports.md` seed; `docs/testing.md`; the friction-reduction principle in the README; `TODO.md` (this file).
