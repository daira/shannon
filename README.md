# Shannon

Does your Claude forget lots of things every time it compacts or starts
a new session? Even if you spend a lot of time trying to teach it how to
work more effectively? That's —at least partly— fixable.

Shannon (named after Claude Shannon, the founder of information theory)
is an [MIT-licenced](LICENSE) toolkit for improving how Claude agents
handle their memories. It includes hooks and seed rules to address common
failure modes that recur in practice when working with persistent agent
memory.

The specific approach taken here is tailored to Claude Code, but many of
the ideas are likely to port to similar agents. This project may well
become more general in future. High-quality contributions are welcome.

By default, this project focuses on meta-issues of memory retention and
usage. It is a little opinionated about that, but not about anything
else. You can opt into additional memory categories that make it more
opinionated — for example about code development practices; tips for
how Claude should use the shell, `git`, or other tools to avoid certain
pitfalls; etc.

## How current LLMs do and don't remember things

TBD: brief background on context vs memory-files, context limits, what
compaction is, why compacting can be so lossy, the role of the Claude Code
harness, etc.

Memory-augmented agents persist preferences and rules between sessions in a
memory corpus. Two failure modes commonly recur:

1. **Recall misses.** The relevant memory exists, but it isn't loaded into
   the agent's context at the moment of decision. Compaction reliably
   drops the bodies of memory files, even when the index of memory titles
   stays in context. The agent then makes decisions from its training
   instead of the recorded preference.

2. **Trigger misses.** The relevant memory *is* in context, but the agent
   doesn't fire the rule at the right moment. Training pressure to "act now"
   can override even a rule the agent has loaded.

These failures look identical from the outside —the recorded preference
doesn't apply— but they need different fixes.

## What Shannon provides

- **`CLAUDE.md` template** — irreducible imperatives that should never be
  missed. `CLAUDE.md` is always loaded into Claude Code's context, so the
  rules here won't compact away. This helps to address *recall misses*.

- **Hooks** — mechanical gates that fire at action time, not at recall
  time:
    - `check-memory-synthesis` injects a reminder before any new memory
      write to check for synthesis with existing memories;
    - `session-start` reminds the agent to reload the full memory corpus
      when affordable;
    - `save-session` snapshots the transcript before compaction.

  These hooks help to address *trigger misses*.

- **Seed memories** — a small starter corpus of universal meta-rules:
  synthesis-check-before-memory-write, no-push-without-explicit-request,
  attribution requirements, scrub-paths-from-global-memories, recipe-bearing
  index summaries, hook script factoring, narration discipline. These are
  the failure modes that show up consistently across users.

- **Opt-in memories** — These try to address a wider range of common
  failure modes of Claude Code.
  TBD: describe how the opt-in works mechanically.

- **Idempotent installer** — `./install.sh` merges into
  `~/.claude/settings.json` (without overwriting existing hooks), copies
  hook scripts to `~/.claude/`, copies the seed memories into
  `~/.claude/memory/` (skipping any that already exist), and installs the
  `CLAUDE.md` template.

## Security

Current mechanisms to limit the scope of what an AI agent can do are
relatively weak. Claude Code runs in a harness that is intended to mitigate
the most dangerous failure modes, but this is inherently limited:

- The agent acts with the user's permissions.
- It's *very* easy to accidentally or inadvisedly create a persistent rule
  allowing it to do dangerous things without any further prompting.
- The commands that it runs are often too long to be seen in full, too
  complicated to check, or outright obfuscated. (The obfuscation is
  sometimes for legitimate reasons like working around shell escaping
  issues, and sometimes really questionable.)

Shannon isn't able to do more than scratch the surface of these issues.
Instructions to an AI agent are effectively code. You should be very wary
of the potential for supply-chain attacks against both this project, and
any project you're working on.

## Quick start

```bash
git clone https://github.com/<owner>/shannon.git
cd shannon
./install.sh
```

After install, restart your Claude Code session. The new hooks fire from
the next session onward.

## What Shannon is not

- **Not a memory replacement.** Shannon works with Claude Code's existing
  auto-memory system.
- **Not project-specific.** No content here ties to any particular codebase
  or domain.
- **Not prescriptive, unless you want it to be.** The more opinionated
  categories of memory are all opt-in.

## Extending

Add your own memories to `~/.claude/memory/` as you normally would.
Shannon's seed memories sit alongside, not above; you can override any of
them by writing your own with the same filename. See `docs/extending.md`.

## Philosophy

A few principles guide what's in this project:

1. **Mechanical guarantees over text exhortation.** A hook fires regardless
   of training pressure. This is more reliable than a text instruction that
   can be skipped.
2. **Opt-ins for anything that is not universal.** The seed memories cover
   only universal failure modes. Anything that doesn't meet that criterion
   is opt-in.
3. **Batteries included.** If you do want to opt into more opinionated
   memories about code development practices, more reliable ways to use the
   shell and `git`, etc., those are included.
