---
name: Deletions — never delete a branch or wipe a directory on your own initiative; restate and confirm what a requested deletion covers
description: "Never run `git branch -d`/`-D`, `git push --delete`, or a forge API branch deletion as cleanup or to free a name, even for a merged branch that you created: rename or pick another name, and report the branch's tip so that the user can delete it. Before deleting a fork, a repository, or more than one branch at the user's request, restate exactly what will go and get confirmation, since \"delete the <name> fork\" can mean a branch or a whole repository. Never `rm -rf`, `git clean`, or otherwise wipe a directory that you did not create, scratch directories included: remove only files that you created, by exact path, and make a fresh directory with `mktemp -d` when a clean one is needed."
core: true
type: feedback
---

Deletion is the user's decision. An agent that deletes on its own initiative, as cleanup or to get past an obstacle, removes something that the user may have wanted, and often for no gain.

## Branches

Never delete a branch on your own initiative, local or remote: no `git branch -d` or `-D`, no `git push --delete`, and no branch deletion through a forge's API. This holds for a fully merged branch, and for one that you created yourself.

- When a task ends, report each branch's final tip, so that the user can delete it without loss.
- When a branch name is taken, choose another name or rename (`git branch -m`). Do not delete the holder to free the name.
- A branch deleted by mistake can be restored while its commit is in the reflog or the object store: `git branch <name> <commit>`. Say what happened; do not restore it silently.

Some users keep every branch deletion for themselves, even on request. Record such a preference in the user's own memories.

## Forks, repositories, and several branches at once

Before deleting a fork, a repository, or more than one branch at the user's request, restate exactly what will be deleted, and ask the user to confirm. A request such as "delete the `<name>` fork" is ambiguous between one branch on a fork and the whole fork, and a user who meant the first nearly lost the second. Draw the user's attention to any confirmation prompt that the tool shows.

## Directories that you did not create

Never `rm -rf` a directory that you did not create yourself, and never empty one with `git clean` or `git stash -u`. This includes a project's scratch directory, and above all one with a disposable-sounding name such as `tmp/`, `temp/`, or `scratch/`: the user keeps their own files there, such as debug output and captured logs. Being ignored by git means that a file is not under version control, not that it is safe to delete ([[feedback_repo_scratch_dirs]]).

- To clean up, remove only the files that you created, by exact path (`rm -f work/thing.log`).
- When a command or test needs a clean or empty directory, create a fresh one with `mktemp -d`, or write into a uniquely named subpath that you control.
- If an existing shared directory really must be cleared, list it and ask the user first.

Ask also whether the deletion is needed at all. An agent once wiped a scratch directory to reproduce a missing-directory condition for a test that wrote somewhere else, so the user's files were lost for nothing.

[[feedback_git_safety]] covers the git commands that lose work, and [[feedback_filesystem_scope]] covers searching and reading outside the project.
