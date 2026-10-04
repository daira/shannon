---
name: Authoring memories — default to global, look for an existing home, write recipe-bearing summaries and matchable triggers, keep memories (especially core ones) short, write down what you notice, match existing emphasis, and word memories generically
description: "Write memories under `~/.claude/memory/` unless a rule only makes sense in one project. Before creating one, look for an existing memory that it belongs in. Make each `MEMORY.md` summary carry the recipe and the failure mode, since the summary is what stays in context. Give each memory a trigger that the context can match: a workflow moment, a syntactic signature, or a hook. Keep memories, and core ones especially, short. When you notice that something is memory-worthy, write it or ask; do not just say so. Give an addition the same emphasis as what is there. Write 'the user' and 'they/them', keeping names for the profile memory, quotes, and attributions."
core: true
type: feedback
---

## Default to the global directory

Write under `~/.claude/memory/` unless a rule only makes sense in one project, and then under `~/.claude/projects/<slug>/memory/`. If in doubt, choose global: sanitization ([[feedback_external_reports]]) keeps project details out of it. Update the matching `MEMORY.md`, and when moving a memory to global, remove its entry from the project's index. Record a user's standing consent to global memories, quoted, in their profile memory.

## Look for an existing home first

Before creating a memory, scan `MEMORY.md` for one that the rule belongs in: the same topic from another angle, a precondition or consequence of an existing rule, or a complementary rule. If one fits, fold the guidance in, updating the body and the summary; when it is close, prefer folding. An obvious corollary needs no memory, and neither does a rule whose body would be shorter than its frontmatter.

## Write summaries that carry the recipe

`MEMORY.md` is always in context, but a memory's body only once it is read. So write each summary to be enough for the common case:

- the recipe, not just the failure ("use `git rm --cached PATH` to keep the file");
- the most common variant, and the rule's one-line form if it has one;
- the specific failure mode, so that a situation is recognized as covered.

A summary that only names its topic, gives the failure without the fix, or says "be careful" is too thin. The index is truncated after 200 lines, one per memory, so keep the number of memories down by folding and pruning. A summary's length costs context in every session, so give it what the common case needs and no more. Draft the body first and carry its recipe into the summary; if a rule does not compress, give the common case and say "see the memory". A body and its summary are two views of one content, so when editing either, check the other. When a memory misfires, and periodically, thicken thin summaries, merge neighbours, and make global any project memory that turns out to be general.

## Keep memories short, especially core ones

A memory's body costs context whenever it is read, and a core memory (`core: true`) is read in full at every session start and after every compaction. So say each rule once, and cut examples and history that do not change what the agent does. Keep core memories especially concise.

## Give a memory a trigger that the context can match

A trigger that is a judgement about the work as a whole ("when this turns into bespoke plumbing") is usually made only in hindsight, so the memory never fires. Prefer a moment in the workflow ("before a large refactoring", "after a second failed attempt"), a syntactic signature ("a `git add` naming a directory"), or, in the limit, a hook. When a memory failed to fire, fix its trigger rather than restating the rule more emphatically.

## Write it down when you notice it

Conversation evaporates at compaction; only memory files persist. When you notice that something is memory-worthy ("worth noting", "a refinement to memory X"), write it now, or ask the user when the right memory or framing is unclear. Saying so without writing it is a deferral disguised as an observation, so treat the phrase as a commitment. Mechanisms keep this path short, not diligence ([[feedback_mechanism_over_intention]]): this memory, the synthesis-check hook, and the always-loaded `CLAUDE.md` template.

## Match the existing emphasis when updating

Give an addition the same emphasis, formatting, and share of the text as the existing items, in the body and in the summary. Emphasizing it because it is new is recency bias ("no need to emphasize the last line").

## Word memories generically

Write "the user" for the memory's present user and "a user" for a past incident, with "they/them". Use a name only in the user's profile memory, in a quote attributed by name, or where the name itself is the information, such as a rule's origin. Use that person's own pronouns only there. A memory worded around one person reads as being about them.
