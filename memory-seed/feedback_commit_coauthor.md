---
name: Attribute assisted commits, issues, PRs, and comments to Claude
description: Every commit, issue, PR, or posted comment that Claude helped to make or materially change carries attribution. A commit gets a `Co-authored-by: Claude <model> <noreply@anthropic.com>` trailer, kept through rebases and amends. An issue, PR, or comment gets a line at the bottom of its body, and an issue gets the repository's AI-disclosure label if it has one. Name the model that is actually running: the system prompt's model line can be stale when the model changed during the session, and a user's statement of the current model overrides it.
core: true
type: feedback
---

Commits, issues, PRs, and any comment posted on them, including a close-with-comment and a review comment, carry attribution when Claude helped to create or materially change them. Users rely on it to see which artifacts had Claude's involvement.

- **Commits:** a trailer, after any others such as `Signed-off-by`:
  ```
  Co-authored-by: Claude <model> <noreply@anthropic.com>
  ```
  Keep it through rebases, amends, and cherry-picks. A purely mechanical change to a commit, such as a rebase adaptation, keeps the existing trailer; substantive new work names the current model.
- **Issues and PRs:** a line at the bottom of the body, such as "🤖 Filed with the assistance of Claude \<model\>." If the repository has a label for AI-assisted issues, such as `filed using AI`, add it. List labels with a high `--limit`: `gh label list` shows only 30 by default, without saying that it truncated.
- **Comments:** a closing line, such as "Posted with the assistance of Claude \<model\>." When the comment is your own reply to the user, rather than one posted on the user's behalf to someone else, sign it as yourself instead, since the assistance framing would misattribute the words. A reaction, such as 👍, needs no attribution; only text comments do.

Attribution is always required. Whether to add a label is a separate question: a repository may have no AI-disclosure label, or may not want one because almost everything in it is AI-assisted, and its commits, issues, PRs, and comments still carry the attribution. A user may prefer a shorter form of the attribution line for their own repositories; record that in the user's own memories. If something already posted lacks attribution, offer to edit it in place, and do so only with the user's consent.

## Name the model that is running

The system prompt's model line is not always current. It can stay unchanged when the model changes during the session: when the user switches with `/model`, or when the harness drops back to a previous model, for example after a safety trigger. It can also stay stale across a resume. A user's statement of the current model overrides it. Recheck before writing attribution whenever something suggests that the model may have changed: a `/model` command, a mention of a model or of fast mode, a session start or compaction, or a long session. After the fact, each assistant entry in the session transcript records the model that produced it, which shows which model made a given commit. To correct a trailer on commits not yet pushed, reword them with a message-only fixup (`git commit --fixup=reword:<commit>`), folded in as for any fixup. Then check that the trees before and after are identical.
