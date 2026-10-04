---
name: Commits make sense in order — each one builds without new warnings, passes its tests, and refers only to what exists; commit as you go; split what does too much
description: Reviewers often read a branch commit by commit, and later readers of the history (e.g. through `git log`, `git blame`, or `git bisect`) land on single commits. So each commit should hold up at its own point in history. Each one builds and passes its tests there, not only at the tip, and does not add any new compiler or linter warnings. It refers only to files, code, and names that already exist, and its message describes its own change without promising follow-up work. A project that works test-first may commit a failing test before its code. A PR also does not carry any known bug (even an untested one), or any placeholder such as `sorry` or a stub, unless it is a draft that names them. When part of a commit moves to the base branch, fold the adapting half into the descendant commit that introduces the affected code. After a history rewrite, run the tests at each rewritten commit. Commit at each logical boundary, not in one batch at the end. Suggest splitting a commit that bundles changes that a reviewer could assess separately, such as a refactor with a content change, or a clarity edit with a correctness fix.
core: true
type: feedback
---

Many reviewers read a branch commit by commit, from its base forward. Later readers of the history land on single commits too. For example, `git blame` points at the commit that last changed a line, and `git bisect` builds and tests commits one at a time. So the history is an artifact in its own right, not only its tip. In one user's words: "in general, I highly value commits making sense when reviewed in order." Each commit should be a coherent unit that a reviewer can check at its own point in history.

## Each commit stands at its own point

Every commit:

- builds and passes its tests at that point. A commit whose tests fail is broken even when the tip is green. A commit that is deliberately incomplete says so in its message.
- does not add any new compiler or linter warnings, since new warnings hide regressions among them. Warnings from before the branch are fine. Compare the warning count before committing, and watch for unused imports, dead code, and unused variables after a refactor. A new warning that is genuinely intended (as in a scaffold that the next commits fill in) is noted in the message or suppressed with a justified allow attribute.
- refers only to what exists at that point, not to any file, function, test, or name that a later commit adds. Content that describes later work (such as a README describing tests) goes in a commit after the thing that it describes. If the order is inverted, reorder or split.
- has a message that describes what this commit does, in names that exist at this commit. It does not make any forward-looking promise ("a follow-up will …", "a later commit will …"): the plan may change, and the sentence then stays wrong in the history. Sequencing intent belongs in the PR description or the issue tracker. A statement of this commit's own scope ("this is the minimal fix for the known case") is fine.

These obligations do not rule out test-driven development. Some projects commit a failing test before the code that makes it pass. There, that test may fail, and may refer to code that does not exist yet. Whether to work that way is up to the project.

A PR has two further obligations:

- **It does not carry any known bug,** even one that is not covered by any test. The default is to fix it in the PR, not to leave it for a follow-up. An exception needs a very good reason: put it to the user with that reason, and never decide it silently.
- **A PR submitted for merge does not carry any placeholder** that compiles but stands for unfinished work: a Lean `sorry` or `admit`, a stubbed fake implementation, or a `todo!()`. A draft may carry one where the hole is deliberate and named (as with a bound taken from the literature, or an obligation scheduled for a later commit). The commit message or a plan file then says so. Remove them all before the PR leaves draft; a CI check (such as an axiom census) can enforce it.

## Keeping each commit true while rewriting

- When reordering, watch for a change that depends on content from a later commit: strip it, split it, or stage it so that every intermediate commit stays coherent.
- When part of a commit moves to the branch that it stacks on (typically to make that branch correct by itself), a later commit that assumed the old behaviour is now wrong at its own point. Most sharply, a test written against the old behaviour can fail there. Fold the adapting half into the commit that introduces the affected code, so that the code is born matching the new base, and update that commit's message. This repair is required, not cosmetic.
- A rename made by a scripted fixup goes into the commit that introduced the identifier, not only the tip. It also goes into every later commit whose diff or message mentions it.
- After any history rewrite, run the tests at each rewritten commit, not only at the tip. Read each one's diff and message for references to what does not exist yet, for new warnings, and for changes that belong to another commit. [[feedback_git_safety]] covers the rewriting itself.

## Commit as you go

During multi-step work, commit each logical group of changes when it is complete, with a focused message. Do not batch them into one commit at the end: most users want to review work as it happens. A large uncommitted working copy is hard to separate afterwards. Concerns often interleave within the same files (such as a rename tangled with a prose sweep), and the clean split needs line-by-line surgery. Users often build up such a working copy, with or without an agent. So commit at each boundary, and when changes accumulate across several turns, offer to checkpoint them into focused commits. Fold, split, and squash during the work rather than leaving it for one large cleanup commit at the end.

## Suggest splitting a commit that does too much

A commit that bundles changes that could stand alone is harder to review (the reviewer must separate the strands), and harder to revert or cherry-pick in part. Usual candidates are two or more of: a refactor, a rename or terminology sweep, a substantive content change, a formatting-only change, and changes to unrelated concerns. Do not split tightly coupled changes, such as a function and its only caller, or a type's rename and the imports that follow it. This applies both to a commit about to be made and to one already on the branch.

- **The test is the reviewable unit.** Ask whether a part is self-contained enough for a reviewer to assess on its own terms. A general reusable lemma and the specialized proof that uses it are usually two units, even when written together, and so are shared infrastructure and its first caller. The unit of a commit is the unit of review, not of the work session.
- **Separate clarity changes from correctness changes** when the split is reasonably easy. A clarity edit (such as a rephrased paragraph, or an abstract claim made explicit) asks the reviewer whether it reads better. A correctness fix (such as a wrong statement corrected, or a missing constraint added) asks whether it is complete and right. Where the two overlap in the same lines, so that splitting is painful, name both concerns in the message.
- **How much is too much varies by user.** Learn this user's threshold over time, and when unsure, ask: "want me to split this into X and Y?"

Splitting is cheapest before the commit lands. Suggest it for a commit already pushed too; whether to rewrite a published commit is the user's decision.
