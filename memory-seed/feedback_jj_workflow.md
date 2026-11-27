---
name: Driving jj (Jujutsu) in a colocated checkout — snapshots take everything, squash into the owning change, name commits by change ID, and leave remote operations to the user
description: In a jj checkout the working copy is the open change `@`, and the next jj command snapshots every unignored file into it: read `jj st` before `jj commit`, run `patch` with `--no-backup-if-mismatch`, and remove a committed stray by deleting it and `jj squash --into <change> -- <path>`. Build a stack with `jj new <base>` and `jj commit -m` per commit; an empty undescribed `@` on top is the resting state. Fix an earlier commit by editing the working copy and `jj squash --into <change-id> -- <paths>`: descendants rebase, and a bookmark on the rewritten commit follows it. Reword with `jj describe -r <change-id> -m`. Name commits by change ID, which survives rewrites; a SHA changes at every squash. jj has no `--no-pager` flag. In a colocated checkout git reads work, but after jj rewrites files, `gitk` lists files as modified with empty diffs (`git gui` probably does the same): stale stat data, cleared by `git update-index --refresh`. Fetch with `jj git fetch --remote <name>`, track with `jj bookmark track <name>@<remote>`, and push with `jj git push --remote <name> --bookmark <name>`; the push and credential rules are unchanged by the tool.
type: feedback
---

jj (Jujutsu) replaces git's index, stash, and amend with one idea: the working copy is a commit, the
open change `@`, and every jj command first snapshots the working copy into it. A colocated checkout
(`jj git init --colocate`) keeps `.git` live, so `git log`, `git diff`, `git merge-tree`, `gh`, and
build tools work unchanged. Make changes through jj, since a raw `git commit` lands on the detached
HEAD and advances no bookmark.

## Snapshots take everything that is not ignored

There is no staging. Read `jj st` before each `jj commit` ([[feedback_git_safety]]), and run `patch`
with `--no-backup-if-mismatch`, since its `.orig` backups otherwise land in the commit (three did,
once). A stray that was committed is removed by deleting it in the working copy and
`jj squash --into <change> -- <path>`. `.gitignore`, `.git/info/exclude`, and git's global excludes
file are all respected, so `work/` and `keep/` stay out ([[feedback_repo_scratch_dirs]]).

## Building a stack and fixing it up

- Start on a base with `jj new <base>`, edit, and seal the change with `jj commit -m '…'`, which
  opens an empty undescribed `@` on top. That is the normal resting state: `jj st` then says "The
  working copy has no changes".
- To fix an earlier commit, edit the working copy and `jj squash --into <change-id> -- <paths>`.
  Descendants rebase automatically, and a bookmark on a rewritten commit follows it, so the tip
  bookmark needs no resetting. Omit the paths only when every change in `@` belongs to that commit.
- To reword, `jj describe -r <change-id> -m '…'`.
- Name commits by change ID (`ouwtrtxl`), which survives rewrites; the commit SHA changes at every
  squash into the commit or an ancestor. Quote SHAs to the user only for the current state. Read
  both with a template, for example
  `jj log -r '<base>::@' --no-graph -T 'change_id.short() ++ " " ++ commit_id.short() ++ " " ++ bookmarks ++ " " ++ description.first_line() ++ "\n"'`.
- jj pages only on a terminal and has no `--no-pager` flag. A mistyped flag fails the command, and
  in a `&&` chain the rest is then skipped, silently if the output is not read.

## Working beside git tools

When jj checks out a commit or squashes into one, it rewrites the affected files, so their mtimes
change and git's index cache no longer matches them. `gitk` then lists such files as modified with
empty diffs (`git gui` probably does the same; only `gitk` was observed), while `git diff` from the
shell sees nothing. The contents never differed; `git update-index --refresh`, or a rescan in the
tool, clears the list.

## Remotes

`jj git fetch --remote <name>` updates the tracked bookmarks; `jj bookmark track <name>@<remote>`
adopts a bookmark that the remote has; `jj git push --remote <name> --bookmark <name>` pushes one
bookmark. The push rule ([[feedback_no_push_without_request]]) and a shell without push credentials
([[feedback_ambient_credentials]]) are unchanged by the tool: hand the user the exact commands, and
ask them to run the fetch as well where the shell cannot.
