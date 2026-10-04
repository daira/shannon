---
name: Publishing — draft until reviewed, bodies formatted for where they are shown, and a fresh comparison before every edit
description: These rules hold wherever a project publishes, whether on a forge such as GitHub or GitLab, or on its own website. Open a pull or merge request as a draft unless the user has reviewed its exact content or asked for it ready. Format a body for where it is shown. GitHub, for example, shows single newlines in descriptions and comments as line breaks, so join each hard-wrapped paragraph and bullet onto one line. Do not cite build job counts or the request's own commit SHAs in its description. Posted text can be edited by the user at any time. So edit it only when the user asks, keep a copy of everything that you post, and before each edit fetch the live text and compare it with that copy. Compare newline-robustly, after stripping carriage returns: `[[ "$(cat -- posted.md)" = "$(cat -- live.md)" ]]`. Treat any difference as the user's edit, which you surface or merge rather than overwrite. Wire the comparison to the edit with `&&`, never `;`.
type: feedback
---

These rules hold wherever a project publishes: a forge such as GitHub or GitLab, a mailing list, or the project's own website. GitHub serves as the example below.

## Pull and merge requests

- **Draft until reviewed.** Open a request as a draft (on GitHub, `gh pr create --draft`) unless the user has already reviewed the exact content, or asks for it to be opened ready. Marking a request ready tells maintainers, and any reviewers that trigger on ready requests, that it has been reviewed. So that call belongs to the user.
- **Format the body for where it is shown.** GitHub shows single newlines in PR descriptions, issues, and comments as line breaks, unlike in `.md` files. So a hard-wrapped body displays there with fixed breaks, which reads badly on a narrow screen. A draft kept for the user's review may be hard-wrapped. When posting it to such a place, join each paragraph, and each bullet with its continuation lines, onto a single line. Keep blank lines, headings, rules, and list markers, and leave fenced code blocks alone.
- **No build job counts.** "Full build green (8569 jobs)" says nothing about the change, since the count is mostly dependencies. Say "full build green", or nothing where the request shows its CI status.
- **No self-referential SHAs.** Do not cite the request's own commits by SHA in its description, as in a heading such as "Fix (`f41e6c2`)". A rebase or force-push makes the SHA stale, and the reviewer has the commit list anyway. Use descriptive headings instead. A pinned link to a commit in another repository is a different matter, and is fine.
- **Attribution** for descriptions and comments: [[feedback_commit_coauthor]].

## Editing what is already posted

A request's title and description, an issue's body, a comment, or a page on a project's site can be shared state: the user can edit it in a browser while you work. An edit that starts from a stale copy silently overwrites the user's changes. Edit something already posted only when the user asks you to, and then:

1. **Keep a copy of everything that you post**, written to a file when you post it, as the record of what you last wrote.
2. **Fetch the live text immediately before the edit,** not from earlier in the session.
3. **Compare the live text with your posted copy.** Any difference is an edit by the user or someone else. Surface it before composing your change, or merge your change into the live text when the two plainly do not conflict. Never apply your change to your stale copy.
4. **Then post,** and save the new text as your posted copy.

A fresh fetch is not enough by itself when the edit rebuilds part of the text, for example by regenerating a section from a draft. An edit by the user inside that section would be lost, which is why the comparison with your posted copy comes first.

**Compare robustly.** Sites and editors add or strip a final newline, and a web editor may save carriage returns (GitHub's does), so a plain `diff` reports differences that are not edits. Strip the carriage returns, and compare the texts as command substitutions, which drop trailing newlines. On GitHub, for example:

```bash
gh pr view 14 --json body --jq .body | tr -d '\r' > live.md &&
  [[ "$(cat -- posted.md)" = "$(cat -- live.md)" ]] &&
  gh pr edit 14 --body-file new.md && cp new.md posted.md
```

Quote the right-hand side of `[[ … = … ]]`, which otherwise matches as a pattern. When the comparison fails, show `diff -- posted.md live.md`.

**Wire the comparison to the edit.** Join them with `&&`, as above, or read the comparison's result and issue the edit as a separate command. With `compare; edit`, or a comparison piped into `head`, the edit runs whatever the comparison found.

**The recorded editor does not tell you whose edit it was.** An agent's writes through an API use the user's credentials, so the site records the user as the editor of both. GitHub also records edit events whose text did not change. Only the text, compared with your posted copy, shows what changed.

**Recovery.** If an overwrite has already happened, a site may keep the earlier revisions. On GitHub, the GraphQL `userContentEdits` connection on a comment, issue, or PR returns them, most recent first. Its `diff` field holds the full text of each revision. Find the user's revision, merge your change into it, and post that.
