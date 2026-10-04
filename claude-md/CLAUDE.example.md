# Always-loaded rules

These rules are loaded by Claude Code into every session's context (via the `CLAUDE.md` mechanism at the user-global scope). They are the irreducible imperatives whose violation has high enough cost to warrant always-loaded status — they cannot be recovered by recall of a memory file alone, because the trigger moment may pass before the relevant memory body gets loaded. The full versions of each rule live in `~/.claude/memory/feedback_*.md`; the lines here are short pointers plus the load-bearing imperative.

## Synthesis check before memory-file writes

Before writing or editing a memory file under `~/.claude/memory/` or `~/.claude/projects/<slug>/memory/`, scan the `MEMORY.md` index for an existing memory that the new content could fit better in. If a close-fit host exists, fold into it rather than creating a sibling memory file. See the *Look for an existing home first* section of `feedback_rich_memory_summaries.md` for the synthesis rule. Shannon's `check-memory-synthesis.sh` hook injects this reminder mechanically at edit time when installed; the rule is the imperative regardless of whether the hook fires.

## Do not push without an explicit request

After a `git commit` (or `--amend`), do not push, force-push, or otherwise publish unless the user's most recent instruction explicitly says "push", "commit and push", or similar wording naming a publication action. Wording like "commit", "amend", "fold in", or "let me see how it looks" does not authorize a push. The earlier "commit and push" authorization in a session is per-commit, not standing. See `feedback_no_push_without_request.md` for the full rule, which recommends never pushing at all on a security-fix branch.

## Attribution for assisted artifacts

Commits, issues, PRs, and assisted comments all get attribution. Commits should include a Co-authored-by: line referencing the Claude model/version, which should be preserved through rebase and amend. Issues, PRs, and review comments: include a bottom-of-body line saying that they were filed by Claude Code. Issues additionally get the `filed using AI` label where the repo has one. See `feedback_commit_coauthor.md` for the full rule and the short-form variant used in specific repos.

## Scrub project-identifying details in global memories and external reports

When writing under `~/.claude/memory/` (a global memory shared across all projects) or filing a bug / PR against an upstream project (outside the user's own repos), strip filenames, project names, paths, usernames, session-local identifiers, and current-task framing. The default is conservative: tighten by default, relax per-context with user confirmation. See `feedback_external_reports.md` for the full rule and the five reasons behind the conservative default.

## Adding rules to this file

This template is intentionally sparse and includes only the highest-priority rules. Violating these rules may publish something unwanted, duplicate non-trivial work, or otherwise have a high cost. It is better to load them on every session / after every compaction than to load them on demand.
