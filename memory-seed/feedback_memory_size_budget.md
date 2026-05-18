---
name: On session start and post-compaction, read every memory file in full IF the context window can comfortably absorb it. Otherwise read the subset that seems most relevant based on the descriptions in MEMORY.md, and use on-demand loads for other memories.
description: "The session-start / post-compaction hook instructs a full re-read of every memory under ~/.claude/memory/ and any project memory dir. Read each file's body into context, not just MEMORY.md's index lines. If your model's context window comfortably fits the corpus (rule of thumb: corpus < ~10% of window; typically true on 1M-context models, typically false on 200k), then read all of them, otherwise what seems to be the most relevant subset for this session. The full re-read overrides the on-demand default at session boundaries; compaction reliably drops standing preferences, and index summaries are recipe-bearing but not lossless. The hook also reports memory-corpus size against 1M-context thresholds (green <50k / yellow 50k–100k / red >100k). Pruning memory files is a separate concern, not a reason to skip the re-read on a model that can afford it."
type: feedback
---

The session-start / post-compaction hook in `~/.claude/settings.json` invokes `~/.claude/session-start.sh` (analogous to how the `PreCompact` hook invokes `save-session.sh`). That script is the authoritative source for the hook's output text and the size-threshold logic; if this memory and the script ever drift, trust the script. The hook has two jobs, and it is important to understand both:

1. **Instruct a full re-read of every memory file.** At every session start — including post-compaction restarts — read every file under `~/.claude/memory/` and every file under any project-specific `~/.claude/projects/<slug>/memory/` directory, in full. Load each file's body into context. Not just the `MEMORY.md` index lines.
2. **Report the memory-corpus size** so the full-read strategy stays affordable.

## Why the full re-read, and why it overrides the system-prompt default

Claude Code's system prompt, in its "auto memory" section, gives a default on-demand policy for memory files: `MEMORY.md` is auto-loaded, and individual memory bodies are loaded "when memories seem relevant" via `Read`. For normal mid-session behaviour that default is fine.

**At session start and after compaction, that default is insufficient**, and the hook's instruction overrides it:

- **Compaction reliably drops standing preferences recorded in memory**, even when MEMORY.md is still in context. The compaction summary is good at preserving the narrative of the session but consistently loses memory-recorded standing preferences unless the full bodies have been loaded since compaction.
- **MEMORY.md index summaries are recipe-bearing but not lossless.** Per `feedback_rich_memory_summaries.md`, the summaries are written so the common case can be applied from the summary alone — but the full bodies cover edge cases, and skipping them means edge-case behaviour quietly regresses.
- Users working with persistent agent memory consistently report "forgetting a lot during compactions" as the failure mode. The full re-read is the direct counter-measure.

So: at a hook-triggered session start, the correct behaviour is to actually execute the re-read — treat the hook's message as a task to perform, not as background context to acknowledge.

## How to execute the re-read

- One Bash call that cats every global `.md` under `~/.claude/memory/` (excluding `MEMORY.md` itself, which is already in context) with per-file headers is efficient: a single tool result holds all bodies. Read the file in chunks if the tool-result size exceeds the Read-tool per-call cap (~25k tokens).
- Follow with the project-specific memory dir if one exists (`~/.claude/projects/<slug>/memory/*.md`), and any `CLAUDE.md` in the current working directory.
- Mid-session — after the initial re-read — on-demand loading is fine. A topic-specific `Read` of a specific memory when its summary flags ambiguity is the right pattern. The full re-read is *specifically* a session-boundary action.

## The size budget

The hook prints:

```
Memory corpus: <N> files, ~<T> tokens (est. bytes/4).
```

and (optionally) a project-context line summing `CLAUDE.md` + `AGENTS.md` in the working directory, when either exists.

**Two distinct concerns the size report addresses:**

1. **Strategy choice (re-read vs index-only)** — the model decides this based on its own context window and the reported corpus size. Rule of thumb: corpus < ~10% of context window → full re-read is affordable; otherwise read MEMORY.md + a subset of memories most relevant to this session + on-demand loads. On a 1M-context model, ~100k corpus is still affordable; on a 200k model, anything over ~20k probably isn't.
2. **Pruning pressure** — independent of strategy. Even on a 1M model, a corpus that's growing without bound eventually crowds out working context and slows session bootstrap. The hook warns against the 1M thresholds because that's the typical model in use; warnings against a hypothetical smaller model would fire too eagerly.

**1M-context thresholds the hook uses:**

- **Green** (`< 50k tokens`): working budget; no action.
- **Yellow** (`50k–100k tokens`): watch for further growth; consider consolidating thin or near-duplicate memories next time one is added.
- **Red** (`> 100k tokens`): even on a 1M model, propose pruning candidates.

**When the hook reports yellow or red (and you're on a model that affords the re-read):**

1. Do the full re-read normally — the warning is about pruning, not about skipping the re-read.
2. Identify pruning candidates: stale project memories, memories whose content is now obvious from the repo state, near-duplicate memories that could be merged, notes-to-self that have served their purpose.
3. Propose removals with brief justification; do not silently delete.
4. Offer to consolidate related memories rather than deleting (e.g. multiple git-hygiene memories → one composite).

**If you're on a smaller-context model**: skip the full re-read entirely, rely on MEMORY.md + on-demand loads, and don't act on the pruning warning unless asked — the thresholds aren't calibrated for that situation.

## Why the hook rather than a self-reminder memory

`MEMORY.md` is truncated at ~200 lines. Beyond ~200 memory entries, rules encoded only as `MEMORY.md` entries become unreliably loaded. A hook that runs a shell script is independent of `MEMORY.md` visibility and executes on every session start, so both the re-read instruction and the size report are delivered regardless of index truncation.

The hook body lives in `~/.claude/session-start.sh` rather than inline in `~/.claude/settings.json` so the reminder text is editable without settings.json surgery, quoting is predictable (a heredoc can contain apostrophes and punctuation freely), and the script is testable in isolation by running `~/.claude/session-start.sh` at the shell. Same factoring pattern as `save-session.sh` for the `PreCompact` hook.

## Relationship to other memories

- `feedback_rich_memory_summaries.md` (write the recipe in the `MEMORY.md` summary) helps keep individual entries load-once-and-apply in mid-session on-demand reads.
- `MEMORY.md` pinning: this entry lives near the top of `MEMORY.md` on purpose, so it remains visible even if the index gets truncated by growth.
