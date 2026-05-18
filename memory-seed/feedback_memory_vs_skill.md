---
name: Memory-vs-skill — declarative rules go in memory; procedural recipes that can run as scripts go in skills
description: "Claude Code persists context across sessions via two mechanisms: memories (always-loaded summaries via `MEMORY.md`; bodies on demand) and skills (lazy-loaded, invoked explicitly or auto-matched by the harness against the skill's description). Decision rule: if violating the rule *once* is bad and it must be active every time the area is touched, it's a memory — memories' always-in-context property serves reflex behaviour. If the content is a multi-step procedure where doing it without guidance is suboptimal but recoverable, it's a skill — skills' lazy loading saves context cost and lets the artifact ship executable helpers. Memories win on always-active rules; skills win on task-shaped procedures. A topic that humans would call a 'skill' (e.g. proficiency with git, prose editing) typically splits into a *cluster of memories* (the always-on rules) plus optionally a *skill* (the end-to-end procedure with scripts) — the two layers complement, not substitute. Skills do not solve the trigger-miss failure mode for declarative rules, because skill auto-surfacing depends on description-match against the user's framing, not the agent's own silent decisions."
type: feedback
---

Claude Code persists context across sessions via two different mechanisms — *memories* and *skills* — and the right home for a given piece of content depends on its shape, not its topic.

## Mechanical differences

**Memories** (`~/.claude/memory/`)

- `MEMORY.md` (index summaries) is auto-loaded into every session's context.
- Individual memory bodies are loaded on demand (via `Read`) or via the session-start hook for affordable corpora.
- Always-active recall property: the summary is in context whenever the agent is doing anything.
- Type-tagged via frontmatter (`feedback` / `user` / `project` / `reference`) — described in the Claude Code system prompt.
- Cross-reference each other freely; the corpus is one large interconnected ruleset.

**Skills** (`~/.claude/skills/`)

- A skill is a directory containing a `SKILL.md` (with `name` + `description`) plus optional supporting files: scripts, data, examples, references.
- Loaded only when invoked — either explicitly (`/<skill-name>`) or by the harness auto-matching the skill's `description` against the current task.
- Near-zero default context cost; pays only when invoked.
- Can ship executable helpers — a `git-safety` skill could include a `pre-reset.sh` script the agent calls.
- Designed for task-shaped, end-to-end procedures.

## The decision rule

Use **memory** when:

- The content is a *declarative rule, preference, or fact* that must be active every time the area is touched.
- Violating the rule once is a problem (irreversible, embarrassing, or expensive to undo).
- The content needs to compose with other rules — memory cross-references work naturally.
- The "reflex" property matters: the agent should hold the rule without needing to invoke anything.

Use a **skill** when:

- The content is a *multi-step procedure* with a recognizable shape ("when doing X, the steps are A, B, C").
- The agent typically wouldn't have the procedure on hand without help, but failing to follow it is suboptimal-and-recoverable rather than catastrophic.
- It benefits from shipping executable helpers (scripts, data files, examples).
- The skill's `description` is something the harness can pattern-match against to surface the skill at the right moment.

## Why this is non-obvious

Topics that humans call "skills" — e.g. *proficiency with git*, *prose editing*, *security review* — often translate into a **cluster of memories** in the agent's setup, not a single skill. The reason: human skill is the bundled package of *rules + procedures + heuristics + experience*. The agent's analogue splits along the always-active / on-demand axis:

- The rules and heuristics that must always govern the agent's behaviour in that area → memories.
- The end-to-end procedures the agent invokes when explicitly doing a task in that area → skills (or nothing, if the agent can compose from memory rules well enough).

Treating a "human skill" as a single skill-artifact for the agent typically under-serves the always-active layer. The agent would only get the rules when the skill is invoked, missing decisions made between invocations.

## A concrete heuristic

> If violating it *once* is bad, it's a memory.
> If doing it *without guidance* is suboptimal but recoverable, it's a skill.

Illustrative examples (specifics vary by user):

- "Never publish a fix from a security branch" → memory (one violation leaks the fix).
- "When recovering from a mid-rebase conflict, run these four steps" → skill candidate (the wrong order is annoying but recoverable).
- "Match the repo's existing scope-casing in commit prefixes" → memory (always-active preference).
- "When creating a new GitHub-hosted release, the workflow is `gh release create …` plus the artifact-upload step" → skill candidate (end-to-end procedure).

## Complementarity

For complex areas, memories and skills can layer cleanly:

- The memories carry the *rules the procedure must obey* (no force-push without `--force-with-lease`; preserve `Co-authored-by` trailers across rebases).
- The skill carries the *procedure itself* (here's the rebase-and-amend workflow), and may invoke the rules indirectly by following them.

This split keeps each artifact at the level it's designed for — memory for always-active constraints, skills for invokable procedures — without forcing either to do the other's job.

## Why this matters for the trigger-miss failure mode

Skills do not solve the *trigger-miss* failure mode for declarative rules. A skill's auto-surfacing depends on its `description` matching the current task context — which works for task-shaped invocations but fails for *silent decisions* (the agent about to run `git reset --hard` doesn't trigger a skill match unless the user mentions git operations first). For trigger-miss on rules, the right mechanism is a `PreToolUse` hook that fires on the specific action — the hook is mechanical, the skill is task-shaped.

## How to apply

When adding new content to the corpus, ask:

1. Is this a declarative rule that must be active every time the relevant area is touched? → memory.
2. Is this an end-to-end procedure that the agent invokes when doing a specific task? → skill.
3. Is it both? → split: rules to memory, procedure to skill, with the skill obeying the memory rules.

When the topic is one humans would call a "skill" (proficiency with X), don't reach for a skill-artifact by default. Map out the always-on rules first (those go to memory), and only build a skill when there is a clear end-to-end procedure with enough shape to benefit from being bundled.
