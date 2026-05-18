---
name: Authoring memories — default to global; synthesize with existing ones first; write recipe-bearing summaries; act on memory-worthy observations; match existing styling when updating
description: "Rules for authoring memories. (1) Default to writing under `~/.claude/memory/` (global) rather than `~/.claude/projects/<slug>/memory/` (project-specific) — cross-project generalizability is the common case. (2) Before creating a new memory, check whether it could be folded into an existing one. (3) Write the `MEMORY.md` index summary so it carries the specific command/recipe/failure-mode — not just the topic name. (4) When the agent notices in conversation that something is memory-worthy ('worth noting', 'this is a refinement to memory X', 'another instance of pattern Y'), the next action should be to write (or to ask), not to narrate. Conversation prose evaporates at compaction; only memory persists across sessions. (5) When updating an existing memory, match the existing styling and emphasis — don't bold or otherwise emphasize the new addition just because it's new (recency bias). (6) Word global memories generically: say 'the user' (and 'they/them') rather than the specific name in rule-describing prose; reserve the name for the user profile memory, direct quotes, and genuine incident attributions."
type: feedback
---

Memory-corpus hygiene has several parts. The rules below cover placement (§1), synthesis (§2), summary form (§3), acting on observations (§4), avoiding recency bias (§5), and using generic wording (§6).

## 1. Default to the global directory

Write new memories under `~/.claude/memory/` (global) unless they are genuinely specific to one project. The default to global rests on the premise that cross-project generalizability is the common case, and a global default minimizes friction. If the user has explicitly granted blanket consent for global defaults (e.g. *"you have my permission to write global memories whenever they're generalizable across projects, which is very often"*), record that consent as a quoted attribution in their user profile memory (`user_<name>.md`) per §6 — it applies to them specifically and may not generalize to other users adopting this seed.

- **Global (default):** `~/.claude/memory/<name>.md`. Applies to any project Claude works on for this user. This is the right home for almost every feedback rule — preferences about prose style, git workflow, tool invocation, review etiquette, security posture, memory hygiene, etc.
- **Project-specific:** `~/.claude/projects/<slug>/memory/<name>.md`. Reserved for facts or rules that genuinely only make sense inside one project — e.g. the layout of a project-internal tool, a broken dependency unique to one build, a task list that only applies to one repo. If the rule could plausibly apply to another repo Claude might work on for the same user, it is global.
- **If in doubt, pick global.** Sanitization (per `feedback_external_reports.md`) keeps project-identifying details out of the memory body; the cross-project sharing benefit outweighs the near-zero cost of a memory that happens to be most-used in one project.
- **When adding a global memory, update `~/.claude/memory/MEMORY.md`**, not the project's. When moving an existing project-specific memory to global, remove the stale entry from the project's `MEMORY.md` as part of the same change.

## 2. Before creating a new memory, check for synthesis with an existing one

A new rule rarely sits in isolation. Before adding a new file, scan `MEMORY.md` for:

- **Same topic, different angle** — e.g. a new "commit message quality" rule fits into an existing "commit messages" memory rather than becoming a third one.
- **Precondition / consequence of an existing rule** — e.g. "check clean tree before rebase" is a precondition for `git revise` / `fixup + autosquash`, so it lives inside the `git_history_editing` memory.
- **Complementary rule** — e.g. "narrate plans" and "stay silent when polling" are two faces of the same narration-style question; one memory, not two.
- **Obvious corollary** — don't write memories whose body is shorter than their frontmatter.

If there's a good fit, **fold the new guidance into the existing memory** (updating both body and summary) rather than creating a sibling. Consolidated memories with multi-section bodies are usually easier to recall than a sprawl of near-duplicates.

If there's no good fit, create the new memory file — but err on the side of synthesis when it's close.

## 3. Write summaries that carry the recipe, not just the topic

`MEMORY.md` is always loaded into the session context; individual memory files are only loaded when explicitly `Read`. So the **index summary is the version of each rule that has active attention by default**. A summary that only names the topic (e.g. "git rm risks losing uncommitted files") doesn't give enough to apply the rule in the moment — the agent would have to remember to Read the full file first, and frequently won't.

**Write the summary so that — for the common case — reading only the summary is enough to apply the rule correctly.** That means:

- **Include the key recipe** ("use `git rm --cached PATH` to stop tracking but keep on disk"), not just the failure mode.
- **Cover the most common variant** as well as the edge case. If a rule has a one-line canonical form, put it in the summary.
- **Name the specific failure mode** so the agent pattern-matches a situation as covered. "prevent variable-expanded filenames being parsed as options" is too abstract; "in `grep`/`rm`/`cp`, write `grep -qF -- \"$var\"` so a `$var` starting with `-` isn't parsed as a flag" pattern-matches better.
- **Don't worry about a hard char-per-entry cap**, but keep each entry short enough to scan quickly. The documented limit is **200 lines total**: after line 200 the index is truncated, so long entries crowd higher-importance rules below the cut. Prefer a slightly longer summary that can be applied directly over a terse one that sends the agent chasing the file — unless that tips the corpus over the line cap, in which case prefer synthesis / pruning (§3).

**Signs a summary is too thin:**

- It just names the topic ("shell quoting", "commit messages").
- It states the failure mode but not the fix.
- It uses generic verbs like "be careful" / "always check" without a concrete recipe.

## 4. When you notice something memory-worthy, *write it* — don't just say "worth noting"

Conversation content evaporates: each turn's prose dissolves at session end (or earlier, at compaction). Only what's written to a memory file persists across sessions. So when the agent notices in conversation that something is memory-worthy — usually expressed as *"worth noting"*, *"this could be a memory"*, *"this is another instance of X pattern"*, *"this is a refinement to memory Y"* — the next action should be to **act**, not to narrate the intent.

Acting means one of:

- **Write the refinement / new memory now** (the default, when the host memory exists and the change is small / focused).
- **Surface to the user:** *"want me to add this to memory X?"* — when the change is bigger, the host is uncertain, or the user might prefer a different framing or scope.
- **Escalate explicitly:** *"I'm not sure where this fits"* — rare; usually the synthesis-check rule (§2) resolves placement quickly.

The thing **not** to do: leave the observation in conversation prose. *"Worth noting as a refinement to memory X: …"* without then actually editing memory X is a deferral disguised as an observation. The observation has no half-life — it influences only the current turn's reply, then disappears at the next compaction. The structural problem the memory was supposed to address (*"this insight will help future sessions"*) is unsolved.

**Heuristic:** if the agent finds itself writing *"this is a refinement to memory X"* or *"worth saving as a memory"*, treat that phrase as a **commitment to act**, not as a marker of having thought about it. The action is the saving; the prose is just talking about saving.

**Origin:** A user directive after the agent narrated *"Worth noting as a refinement to memory X: …"* with substantive content for the refinement, then moved on without writing it. The user pointed out that the observation would not be retained past the session unless saved. The corrective: when prose itself names a memory-worthy insight, the very next action should be the write.

## 5. When updating an existing memory, avoid emphasizing new content at the expense of existing content

When adding a new sub-rule, bullet, or example to an established memory, use the same level of emphasis (bold, italic, formatting) as the existing items, and keep the volume of text for this new item proportionate to its importance. The just-added content is not more important than the established items — they were memory-worthy when first written, and they remain so. Adding extra `**bold**` or `*italic*` to the new addition, or writing as much about it as several other items combined, is recency bias: the agent's attention is on the new item because it was just composed, but the reader's attention should be distributed by content importance, not by chronology of addition.

The same applies to the `MEMORY.md` summary: when extending a multi-clause summary with a new clause, the new clause should match the existing clauses' emphasis style. If the existing clauses are unbolded prose, the new one should be unbolded prose. If a clause genuinely warrants emphasis on standalone merit, that's a separate question — but the *just-added-ness* never warrants emphasis.

This combines with §4 above: the agent that has just noticed something memory-worthy and is about to write it down has an attention bias toward the new content. That bias surfaces as styling inflation. Resist it: write the new addition concisely and in the same voice as the surrounding content.

**Origin:** A user directive after the agent added a new sub-rule to a `MEMORY.md` summary using `**bold**` while the existing sub-rules were unbolded. The user noted: *"no need to emphasize the last line. (avoid recency bias when updating memories)"*.

## 6. Word global memories generically

In the body and `MEMORY.md` summary of a generally-applicable memory, say "the user" (and "they/them"), or "a user" in rule-describing prose. The specific name belongs only in:

- **The user profile memory** (`user_<name>.md`), which is *about* the user by name.
- **Direct quotes of things they have said** (or close paraphrases transcribed as quotes). The attribution stays named because the quote was uttered by a specific person at a specific time and can only be vouched for by them: `<name> has explicitly said: "…"`, not `The user has explicitly said: "…"`. If someone else reuses the memory, they will re-read the quote and decide on their own whether to inherit it.
- **Genuine author/actor context where the name is the signal** — e.g. "documents authored by `<name>` or `<other-name>`" as a way of identifying a specific style-consistent subset of files, or "this rule came from the `<name>` / `<project>` incident in which …" where the attribution is the rule's origin.

Everywhere else — motivation prose, failure-mode descriptions, "why" explanations, pattern descriptions — use "the user". A memory worded around one person reads as being about them specifically even when the rule generalizes, which either mis-signals the scope or forces other users to edit the name out when adapting.

- "the user" — the present user of this memory; ongoing preferences, recurring patterns, stated opinions, current setup. Example: "The user prefers terse responses with no trailing summaries."
- "a user" — a specific past incident that could have happened to anyone but *did* happen once and motivated this rule. Example: "A user almost accidentally deleted their entire fork when they only meant to delete a single branch."

Pronouns in generalized prose default to "they/them", not any specific user's pronouns. If a specific user's pronouns are recorded in their profile memory, use those in *their* direct-attribution contexts; "the user" in generic prose stays "they/them". Pronoun reference should track the subject it attaches to: "the user" → "they"; `<name>` (in the allowed name contexts) → whatever pronouns are set in `user_<name>.md`. Do not mix the two within a single sentence or clause.

## 7. How to apply (all parts together)

- When the user gives new feedback, first ask: does an existing memory already cover this? If close, fold in and update the summary; otherwise create new.
- When creating a new memory, default to the global directory unless the rule is genuinely project-specific.
- When creating a new memory, draft the body first (complete guidance), then *back-port* the recipe into the summary — don't just say "see full memory for details".
- When reviewing existing memories (periodically, or when one misfires), upgrade thin summaries with the recipe AND look for merge candidates with their neighbours. Also consider whether a project-specific memory would be better as a global one.
- If the rule genuinely doesn't compress (too many cases), name the single most common case in the summary and say "see memory for others".
- When the agent itself notices an insight in conversation worth saving, write it before continuing — don't leave it in transient prose.
- When updating an existing memory, match the existing styling and emphasis — recency bias makes new content read as more important than it is; styling and verbosity should reflect content importance, not chronology of addition.
