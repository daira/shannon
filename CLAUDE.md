# CLAUDE.md — guidance for Claude when working on Shannon itself

Shannon is a meta-toolkit: hooks and seed rules that address
memory-augmented agent failure modes. The repo is intentionally small,
intentionally opinionated only on infrastructure, and intentionally NOT
tied to any particular project, domain, or user.

## Two principles that shape every change

1. **Mechanical guarantees over text exhortation.** A hook fires regardless
   of training pressure; a text instruction can be skipped. Prefer the hook
   when a mechanical guarantee is available.

2. **Minimum opinionated content for seed memories.** Seed memories address
   *universal* failure modes (recall miss, trigger miss, synthesis miss,
   narration discipline, attribution, no-push-by-default, etc.). They do not
   prescribe stylistic preferences (commit-message format, code style, naming
   conventions) — those are per-user and out of scope.

## Sanitization is mandatory for shipped content

This is an open-source repo distributed publicly. Anything that ships in
`memory-seed/`, `claude-md/`, `hooks/`, or `docs/` must be scrubbed of:

- **Real names.** Use `<name>` / `<other-name>` as placeholders. The only
  exception is named credit in `README.md` and `LICENSE` for the author and
  copyright holders.
- **Specific project / repo / file-path references.** A seed memory that
  cites a particular protocol spec, a specific GitHub PR number, or a
  particular codebase has not been sanitized.
- **Specific incident dates or session identifiers.** "Origin" sections
  describe the failure *pattern*, not the *specific incident*. Genericized
  framing — "A user observed …", "A common failure mode is …" — replaces
  dated / named anecdotes.
- **Quoted user permissions that don't generalize.** If a seed memory
  references a user's stated permission (e.g. *"you have my permission to
  X"*), the seed says *"if your user has granted this permission, record
  it as a quoted attribution in their `user_<name>.md`"* — it does NOT
  carry the permission itself, which is specific to one user and may not
  apply to other adopters.

When in doubt, grep for known leakage terms before committing: actual
project names, real GitHub handles, real personal names, dates that
identify a single session.

## Structure

```
shannon/
├── README.md                       user-facing intro
├── CLAUDE.md                       this file (contributor guidance)
├── install.sh                      idempotent, non-destructive installer
├── claude-md/
│   └── CLAUDE.md.example           template installed to ~/.claude/CLAUDE.md
├── hooks/
│   ├── settings.json.snippet       JSON to merge into ~/.claude/settings.json
│   ├── check-memory-synthesis.sh   trigger gate before memory writes
│   ├── session-start.sh            recall reminder + corpus-size report
│   └── save-session.sh             PreCompact transcript snapshot
├── memory-seed/                    universal meta-rules, sanitized
└── docs/                           philosophy + extension guide
```

## Conventions for contributions

- **Hook scripts factor into `~/.claude/<name>.sh`.** Don't inline
  multi-line hook bodies in `settings.json` — heredocs and apostrophes
  inside JSON are fragile. The installer's job is to copy scripts and merge
  a small JSON snippet that references them.
- **Hook path-matching: in the script vs the `if` field.** When a
  `PreToolUse` (or similar) hook should only act on certain paths, decide
  where the path match lives by asking *"is there still something useful
  to prompt for in the matched cases?"* If yes, match in the script (a
  bash glob on `file_path` after the hook fires), so the script can emit
  a path-aware reminder. If no, match in the `if` field of the hook entry
  in `settings.json`, so the harness skips spawning the script entirely.
  The `if` route saves a process spawn per non-matching invocation; the
  script route keeps path logic in one place and lets a single hook emit
  different reminders for different paths. Caveat: Claude Code's
  permission-rule syntax supports prefix matches but not negation, so
  EXCLUDE-style `if` filters (e.g. "any memory path EXCEPT `MEMORY.md`")
  cannot be expressed directly — they would have to enumerate the
  prefixes that DO match. When excluding a single path or filename,
  script-level matching is usually the more practical choice even when
  no prompt is needed. Real instance: `check-memory-synthesis.sh`
  handles both `MEMORY.md` exclusion (no output) and `user_*.md`
  path-aware reminders (synthesis applies, sanitization does not)
  in-script for this reason.
- **Tests are expected for shipped scripts.** Any new script added to
  `hooks/` — or any substantive modification to an existing one — needs a
  corresponding test under `tests/`. See `docs/testing.md` for the testing
  approach: pipe-test with synthesized stdin JSON; assert on exit code,
  stdout JSON shape, and any filesystem side effects. The test suite uses
  [bats](https://bats-core.readthedocs.io/) and runs in CI.
- **The installer must remain idempotent and non-destructive.** Re-running
  `./install.sh` is safe. Existing user files
  (`~/.claude/settings.json`, `~/.claude/memory/*`, and
  `~/.claude/CLAUDE.md`) are merged into or skipped, never overwritten
  without explicit opt-in (`--force` or equivalent).
- **`CLAUDE.md.example` must stay minimal.** Only the irreducible
  imperatives — rules whose violation has high enough cost to warrant
  always-loaded status. Adding rules to the template is a high-bar change;
  consider whether the rule could live in a seed memory (recall-loaded when
  affordable) instead.
- **Seed memory filenames are stable surface.** Downstream users may rely on
  the filenames; renaming a seed memory is a breaking change. Pick names
  carefully on first commit, and treat renames like API renames.
- **Cross-references between seed memories must be consistent.** If
  `feedback_X.md` references `feedback_Y.md`, both should ship in the seed
  (or the reference should explain how to satisfy it without `feedback_Y.md`
  being present).
- **Same or closely-related content across files: cross-reference in
  comments, and propagate edits.** When the same content — or content
  closely related enough that edits in one place are likely to affect
  what should be in the other — appears in more than one file (e.g. a
  reminder text in a hook script and the prose of the same rule in a
  memory body; a memory body and the recipe-bearing `MEMORY.md` summary
  that condenses it; a design described in `docs/<topic>.md` and a TODO
  entry that summarises it), (a) annotate each location with a comment
  naming the other location(s), in whatever comment syntax the file
  uses (bash `# See also: <path>`, Markdown HTML comment
  `<!-- See also: <path> -->`, etc.); and (b) when one location is
  edited, propagate the edit to the others so they stay in sync. The
  cross-reference comments are the mechanism that catches future drift:
  an editor of one file sees, in that file, the names of the parallel
  copies that also need to change. Real instances in this repo: the
  `<project>/tmp/` rationale appears in both
  `hooks/check-tmp-path.sh`'s reminder text and (the global)
  `feedback_use_repo_tmp.md`'s body; `docs/testing.md`'s per-case test
  tables are cross-referenced from `TODO.md`'s Tests section. The
  body-and-`MEMORY.md`-summary relationship for all memory files is
  treated as implicit cross-reference (see
  `feedback_rich_memory_summaries.md` §4); no per-file `See also:`
  comment is needed for that case.
- **Task bodies are short pointers; durable design content goes in `docs/`.**
  The harness's default task-list view shows task subjects only, so design
  notes, test plans, scope expansions, and other content the user will want
  to read should live in `docs/<topic>.md` (or `tests/README.md`, etc.). The
  task body remains useful as a future-agent-facing backup but is not the
  canonical home. See the global `feedback_durable_task_context_in_file.md`
  for the general principle.

## Out of scope

- **Project-specific memories.** Those belong in
  `~/.claude/projects/<slug>/memory/` for the end user, not here.
- **Stylistic preferences.** Commit-message conventions, code style,
  naming, prose preferences — these are per-user.
- **Runtime tooling.** Linters, dedup finders, and other utilities that
  operate on the user's memory corpus at runtime are useful but a separate
  project; Shannon's scope is the install-time toolkit and the seed corpus.
