---
name: Sanitize external reports and global memories of project-identifying details
description: When filing bugs / feature requests / PRs outside the user's own project, or when writing global memories that may be shared with other developers' Claude instances, strip filenames, paths, usernames, project names, session-local identifiers, and current-task context that aren't relevant to the artifact's purpose. The conservative default protects users with different working-in-public norms, employer constraints, embargo obligations, and risk profiles. Recipients can always relax permissions for their own usage by editing the artifact locally; the published default should be conservative. Always preserve the Claude attribution line — that's an intentional exception, since attribution is meant to be visible.
type: feedback
---

When filing bugs, feature requests, or PRs against projects **outside** the user's own (e.g. against an external toolchain, an upstream library, or a third-party framework), or when writing **global memories** (which may be shared with other developers' Claude instances), do not leak information about:

- The user's project name, directory, or path (e.g. `/home/$user/projects/foo/`, or path-encoded slugs that identify a specific project / user).
- Filenames specific to the user's project (e.g. `/tmp/<project-name>-build.log` → use `/tmp/build.log`).
- The user's current activity or task context that isn't directly relevant to the report.
- Internal details of what the user was working on when the issue arose.
- Session-local identifiers that won't exist outside the current session: TaskCreate task numbers, conversation IDs, tool-call IDs, current-session SHAs, and ephemeral file paths created mid-session. These are meaningful only within the session that created them; other readers — or future sessions of the same user — cannot resolve them. Refer to the underlying concern by description ("the audit-and-fix pass is a known follow-up", "the broader refactor task") rather than by session-local number.

**Why:** External reports are public artefacts — indexed, archived, visible to anyone. Global memories are *also* published / shared artefacts intended for distribution to other developers' Claude instances. Both inherit the same conservative privacy posture even when the immediate user has consented to publishing information about themselves. Five distinct reasons to default to scrubbing:

1. **Audience consent.** The artefacts will be used by people with *different* preferences. Even when the present user is comfortable with their information being public, including it sets the wrong default for users who do not share that openness — they may have different working-in-public norms, different employer constraints, or different risk profiles. Recipients can always relax permissions for their own usage by editing the memory locally; the published default should be conservative. Including identifying context also creates an awkward example to follow when other users want to contribute refinements.

2. **Portability / clarity.** Global memories framed in user-specific paths, usernames, or repo names are distracting and may fail to apply for another user whose Claude doesn't notice the specificity. Even when the rule still works, the recipient pays a translation cost. Generic framing reads cleanly without that overhead.

3. **Security work and embargo obligations.** When the user does security work, defaulting to avoiding leakage is an obligation *to others* — a co-author on an unpublished CVE, a coordinated-disclosure schedule, or an embargo with downstream-distributor partners — not merely a personal preference. Scrubbing minimizes the chance that an in-progress embargo accidentally surfaces in a memory body or external report.

4. **Adversarial context.** User/system-specific information (paths, usernames, working directories, machine names) can be useful to an adversary trying to compromise the user's devices. Even when much of it has leaked over time and wouldn't be too hard to find, it should not be included in artefacts that are publically indexed.

5. **Cautious-by-default for AI usage.** Defaulting to scrub keeps the relaxation decision a per-user, per-context choice that can be made later. Tightening after publication is much harder than starting tight; the asymmetry favours the conservative default, especially for users still building familiarity with AI assistants.

Even when the project itself is public, the *fact* that the user was working on it at a particular time is private context that doesn't belong in an external bug tracker, nor in a memory file destined for other developers' Claude instances.

**How to apply:**

- Before filing, re-read the report and replace any project-specific names / paths with generic placeholders (`/tmp/build.log`, `<project-dir>`, "the project I'm working on", or just delete the example).
- Examples should illustrate the issue with generic names; concrete details are unnecessary unless the report would be unintelligible without them.
- Issues against the user's own repos can include project-specific details freely, but the same conservative stance should still apply to user- and system-specific details, unless the user has given explicit consent.
- Global memories (in `~/.claude/memory/`) can be shared with other developers, so the same privacy considerations apply as for external reports. Use generic examples; omit project names, security-sensitive context, and user-specific paths.
- Always include the Claude attribution line at the bottom — attribution is an intentional exception to the sanitization rule (commits, issues, and PRs assisted by Claude should carry attribution; the format is a per-project convention).
