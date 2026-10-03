---
name: Git safety — don't lose the user's work, stage files by name, and rewrite history with the right tool
description: Before `reset --hard`, `stash -u`, `stash drop`, `rm`, or `checkout <ref> -- <file>`, check what would be lost; run `git clean -f`/`-x`/`-X` only after showing the dry run and getting the user's confirmation. Name every file in `git add`, never `.`, `-A`, a directory, or a glob, and check each file's own diff first. To edit past commits, make fixup commits and fold them in with `GIT_SEQUENCE_EDITOR=true GIT_EDITOR=true git rebase -i --autosquash <parent>`; never detach, amend, and `rebase --onto`. At a conflict stop, resolve and `--continue`, never `--amend`; never script a loop over stops. Check the branch and a clean tree first, and the commit count afterwards. Run background git work in a separate clone, and never delete a live lock file.
type: feedback
---

## Commands that lose work

- `git rm PATH` deletes the file from the working tree too. It refuses a file with uncommitted changes, so what it deletes can be restored with `git checkout HEAD -- PATH`. `git rm -f` deletes such changes beyond recovery: never use it unasked. `git rm --cached PATH` stops tracking the file and keeps it.
- `git stash -u` removes untracked files from the working tree, so warn the user before using it. They survive in the stash as `stash@{N}^3`: `git checkout 'stash@{N}^3' -- <path>` restores one.
- `git clean` with `-f`, `-x`, or `-X` deletes untracked or ignored files beyond recovery, including ignored ones such as `.env` files and local notes. Never run it without showing the user the dry run (`git clean -n …`) and getting their confirmation.
- `git reset --hard` discards uncommitted changes, and commits that become unreachable. First check `git status`, `git log <upstream>..HEAD`, and `git rev-list --left-right --count HEAD...<upstream>`. To follow a force-pushed remote, prefer `git pull --rebase` or `git merge --ff-only`, which refuse rather than discard. After a mistake, the reflog still has the old commit, but only in that clone and for about 90 days.
- `git stash drop stash@{N}` renumbers the later stashes, so dropping several by index can hit the wrong one. Check each by its ID first (`git rev-parse stash@{N}`); a dropped stash can be restored with `git stash store -m <message> <id>`.
- `git checkout <ref> -- <file>` overwrites the file's uncommitted changes, so make sure of the branch first (see below).

## Stage files by name

Write `git add path/to/a path/to/b`, never `git add .`, `-A`, a directory, or a glob. Working trees hold untracked files that are not ignored, such as logs, editor backups, notes, and local experiments, and a wide add commits them. Read `git status --short` first. Many files are no reason for a wide add: list them all, or split the commit. When proposing a commit, show the exact `git add`.

Check each file's own diff (`git diff <file>`) before adding it whole: an earlier edit that was interrupted, still unstaged in the same file, would ride along into an unrelated commit. To undo a wrong add, unstage with `git reset HEAD -- <path>`; never fix it by committing.

## Rewriting history

Before a branch-sensitive operation (a rebase, an amend, a cherry-pick, `reset --hard`, `clean`, or `checkout <ref> -- <file>`), check the current branch with `git branch --show-current`, or put the `git checkout <branch>` at the head of the same command. The branch persists between commands, and `git rebase --onto A B branch` leaves you on `branch`. Check that the working tree is clean too, and stash first if it is not. Afterwards, check the commit count, and compare trees where the change should have left them alone.

Do not edit a past commit by detaching, amending, and `git rebase --onto`: if the old commit is still an ancestor, the rebase silently drops commits. Where detaching is unavoidable, as to change a commit's author, save the branch's commit ID first, so that `git reset --hard <id>` can recover it.

Instead, make a fixup commit (`git commit --fixup=<id>`, or `--fixup=amend:<id>` to change its message too), and fold it in with `GIT_SEQUENCE_EDITOR=true GIT_EDITOR=true git rebase -i --autosquash <parent>`. Set both variables: otherwise `rebase -i` opens an editor, which fails or hangs in a non-interactive shell. The base must be the parent of the earliest commit that a fixup targets; a fixup left unsquashed at the tip means that the base was too late. Avoid `--root` if the history has merges. Prefer this to `git revise --autosquash`: on a conflict, `git revise` asks questions on standard input, which the editor variables do not affect, so that in an agent's shell it fails or hangs. Also it may not be installed on some systems.

A rebase has two kinds of stop, which need opposite commands. At a conflict stop (`git status --porcelain` shows `UU`), the commit does not exist yet: resolve, `git add`, and `git rebase --continue`. A `git commit --amend` there would fold the changes into the previous commit. At an edit stop, the commit exists: `git commit --amend`, then `git rebase --continue`. So handle one stop per command and check its kind; never script a loop over stops. Where a scripted edit precedes the amend, chain them with `&&`, so that a failed edit stops the sequence. Key such a script on content, such as declaration names, rather than on line numbers, which differ at an earlier commit.

A rewritten commit that was never built can carry a defect that git does not see. Test each rewritten commit; where building each is too expensive, at least check each one's version of the touched files cheaply, for example by parsing them.

## Concurrency, locks, and diagnosis

Never run git operations in the background in a repository, or a worktree of it, while working in it: they contend for its locks. Use a separate clone. Never delete a lock file to get past an error, since the process holding it may still be running. Wait for that process, and remove the lock only once it is provably stale; then run `git fsck --full` before further changes. While diagnosing a failing git command, run it bare and show its exit status: piping it through `tail -1` can hide the message that explains the failure.
