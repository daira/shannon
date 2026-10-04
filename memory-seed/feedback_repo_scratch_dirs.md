---
name: Use a work/ or keep/ directory inside the repo, not /tmp — pick by durability; never rm -rf either
description: Files the agent creates that don't belong in version control go under `work/` (temporary files such as build output, PR/commit message drafts, intermediate diffs) or `keep/` (durable working drafts to retain across sessions). Both are git-ignored. Never use `/tmp`. The scratch dir is named `work/` (NOT `tmp/`) on purpose — `tmp`/"deletable scratch" framing pattern-matches to disposable at the weights level and triggers a reflexive `rm -rf` when this memory isn't fresh in context. HARD RULE: never `rm -rf` `work/` or `keep/` (they pre-exist and hold the user's own files); only `rm -f` the specific files you created, by exact path.
core: true
type: feedback
---

Files you create in a repository that don't belong in version control go in one of two directories at its top level:

- **`work/`** for temporary files: build and test logs, intermediate artifacts, diff dumps, PR and commit message drafts. When in doubt, use `work/`; moving a file to `keep/` later is easy, and recovering a deleted one is not.
- **`keep/`** for drafts to retain across sessions: review documents, design notes, drafts not yet ready to commit, session snapshots (`hooks/save-session.sh` writes them here), and anything the user wants to refer back to.

Never use `/tmp/`: it is shared with other processes and sessions, so files there can collide with another agent's, be cleaned up by the OS, and turn up in broad searches. If `work/` does not exist yet, `mkdir -p` it rather than falling back to `/tmp/`. For a program that writes temporary files you may need to find, such as a test runner, consider setting `TMPDIR` to `work/`. If a file must go outside the project, create one directory per session with `mktemp -d`, and refer to it by its absolute path. When the user says to move a file to `keep/` or `work/`, move it without asking. Searching and reading outside the project are covered by [[feedback_filesystem_scope]].

**Both must be git-ignored.** Before creating files there, run `git check-ignore work/ keep/`, keeping the trailing slashes: without them, a directory that does not exist yet is reported as not ignored. Read the output, which lists each ignored path, rather than the exit status, which is 0 if either one is; `git check-ignore -v` also shows which ignore file and pattern matched. If either is not ignored, ask whether to add it to the user-global ignore file or to the repository's `.gitignore`, or to use another location; do not edit either file unasked. If the user does not appear to use this convention already, explain why it is a good idea. Unlike `/tmp/`, `work/` keeps scratch files scoped to the project, isolated from other sessions, and out of commits; `keep/` holds the drafts that the user wants to retain across sessions. In the global file, anchored patterns (`/work/`, `/keep/`) ignore only the top-level directories, so a nested scratch directory needs an entry in the repository's own `.gitignore`.

## HARD RULE: never `rm -rf` either directory

`work/` and `keep/` are **not yours**: they usually exist before your `mkdir -p` and hold the user's own files. To clean up, remove only the files you created, by exact path (`rm -f work/mything.log`). For a subtree of your own, `mktemp -d work/claude-XXXXXX`, and remove that subtree by its path, never the parent.

The directory is named `work/`, not `tmp/`, for this reason. It used to be `tmp/`, described as "deletable scratch", until an agent ran `rm -rf tmp/` on one that held the user's files. The name and the description pattern-match to "safe to delete" whenever this memory is not in context, and vigilance does not change that. Describe the directories by what goes in them, never as deletable.
<!-- See also: the same rationale appears in `hooks/check-tmp-path.sh`, inside the
     `additionalContext` JSON string. Edits to the rationale here must be propagated
     there, and vice versa. -->
