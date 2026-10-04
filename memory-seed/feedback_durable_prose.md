---
name: Durable prose stays true — self-contained, with pinned references, in step with the code and its own diff, and describing the present without overclaiming
description: Commit messages, PR and issue bodies, code comments, docstrings, and docs outlive the conversation and the branch state that produced them. So they do not refer to task numbers, agent IDs, or "as we discussed". Another repository's issue is `org/repo#N`, and another commit is described by its relationship, never as "the next commit". A code reference is pinned to a release tag or a full SHA, not a bare `path:line` or a branch-tip URL. Before each commit, check every claim in the message against the staged diff (`git diff --cached | grep -F '<token>'`), and when correcting a fact, fix every copy of it. Describe what is. Do not script undecided future work, and do not claim in the present tense a connection that the tree does not contain. A summary gives the meaning, not a copy of the code's exact formula. These hold at every commit, and a PR is not finished while a known overclaim remains.
core: true
type: feedback
---

Commit messages, PR descriptions, issue bodies, code comments, docstrings, and documentation are read later by people who do not have the conversation that produced them. They are also read after commits have been reordered, squashed, or dropped, and after the code has moved on. Each one has to stand alone, and to stay true.

## Self-contained

- Do not refer to task numbers from a task list, agent or conversation IDs, "as we discussed", or plans that exist only in the conversation. Inline a one-line description instead, and make a `TODO` name the missing capability, not a tracker entry. Issue numbers and commit SHAs are fine: they live in the repository or the forge.
- Write another repository's issue or PR as `org/repo#N`. A bare `#N` means the repository that the text lives in, and the qualified form also makes GitHub link it. The slip happens in quick replies, so before posting a comment or body, look at each bare `#N` and ask whether it belongs to the host repository.
- Do not refer to other commits by position ("the next commit", "the previous commit", "as introduced in commit X"): a reorder, squash, or drop makes such a reference wrong. Describe the logical relationship instead ("a separate commit adds …"). A commit message may still describe what its own commit changes relative to its parent. After a reorder, `git log --format=%B <base>..HEAD | grep -iE 'next commit|previous commit|in commit'` finds the references that may have dangled.

## Pinned references

- A bare `path:line` drifts as the file changes, and a URL to a branch's tip shows different content as the branch moves. In durable prose, link to a release tag, which reads best, or else to a full 40-character SHA, with `#L` anchors where specific lines are meant. A short SHA prefix is unsafe in a link: someone can push a commit with a matching prefix to a fork.
- Cite sources in code comments the same way, such as a constant copied from another implementation, or an algorithm being mirrored. Where the connection is machine-checkable, add a test or an assertion of it too.
- A living specification is cited at its current version, unpinned, unless a historical version is meant.
- Chat, review comments on a PR, and working notes may use a bare `path:line`, since their readers share the working tree. Within the same repository, prefer identifiers (`see parse_header`) to line numbers.

## In step with the diff and with every other copy

- **The message matches its own diff.** A message drafted early, against a plan or a first diff, keeps claims about content that was later cut. Before each commit, amend, or reword, read the message against the final staged diff. For each identifier, API, bullet, example, or path that it names, check that the diff has it (`git diff --cached | grep -F '<token>'`), and remove or rewrite what it does not. This bites hardest when the scope narrowed during drafting, and in a chain of amends. It also bites in a message written from a plan or a session summary, and in a security fix whose details were cut on purpose.
- **A correction reaches every copy.** The same fact often appears in several places: a commit message, a comment, a docstring, a README, or a design document. When correcting it in one, search for the others (`git show <sha>` for what a commit introduced, `git grep -i '<phrase>'` for the tree) and correct them too. Otherwise a reader finds the fixed version in one place and the stale one beside it.

## Describe the present, at the right level

- **Not the future.** Do not describe undecided future work in specific terms ("the planned follow-up is X", "this will be replaced by Y"). Plans change, and the stale plan then reads as authoritative; it also settles design questions in advance, and duplicates the tracker's job. A pointer to the issue that tracks the work is the most that belongs. When an edit touches such prose, trim it to the present. A "Status" section lists what is absent or assumed, not how it will be filled.
- **Not the change.** Outside a commit message, describe what is, not how it came to be: words like "now", "no longer", and "new" go stale once the change is old.
- **No overclaiming.** Present-tense prose that names a concrete artifact as doing something ("this is handled by `X`", "the premise is discharged by `Y`") must be true in the tree at that commit. Otherwise, state the intent ("the intended route is X; it is not implemented yet"), or attribute the claim to its source, such as a paper or a specification. To find overclaims, search new prose for phrases such as "handled by", "discharged by", "reduces to", or "delivered by" that name a definition, and check that something in the tree uses that definition. Splitting a long sentence into one claim per sentence also exposes them, since each claim must then stand on its own.
- **A corrected belief leaves prose behind.** When a test, a failed proof, or a reviewer overturns a belief, correct the prose that encoded it, not only the code. Read each comment or docstring against the code or statement beneath it: a claim that contradicts its own declaration is visible on sight.
- **Summaries interpret.** A module doc, section header, or PR overview says what a result means, not the code's exact formula or its term-by-term breakdown. The exact expression belongs in the code or the theorem statement, where it cannot drift from itself. A summary that holds an expression copied from the code goes stale when the code changes.

## At every commit, and before a PR is finished

These rules apply to each commit's tree and message, not only to the tip of the branch ([[feedback_commits_sequential_coherence]]). On a draft branch, fold a correction into the commit that introduced the prose, and fix an inaccuracy inherited from the base branch in its own commit at the front. A refactor that changes what a summary describes updates the summary in the same commit. A PR is not finished while a known overclaim remains in its tree, its documentation, or its description: fix the prose, or build the missing piece so that the claim becomes true.
