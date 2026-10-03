---
name: Don't push without an explicit request, and never during a security fix — commit, then let the user review
description: After a commit or an amend, stop. Do not push, force-push, open a pull request, or otherwise publish unless the user's most recent instruction names that step ("push", "commit and push", "force-push"). "Commit", "amend", "fold in", or "let me see how it looks" do not authorize a push, and an earlier "commit and push" covered that commit only. Report the commit and let the user review it locally. On a security-fix branch, the default policy should be never to push or publish at all: even a branch name or CI activity can tip off attackers. If in doubt whether a branch is security-sensitive, ask before any network action that involves the repository.
type: feedback
---

After a `git commit` or `git commit --amend`, stop. Do not push, force-push, open a pull request, or otherwise publish the change unless the user's most recent instruction explicitly asks for that step. Most users review changes locally first, by reading the diff, running the tests, or looking at the rendered output. A push skips that review, and can publish something that the user wanted to revise.

**A push is authorized** only when the user's most recent instruction names a publication step: "push", "commit and push", "amend and force-push", "open a PR". **It is not authorized** by:

- "commit", "amend", "fold that into the last commit", or other wording that names only the commit;
- "let me see how it looks", or other wording that implies a review first;
- an earlier "commit and push", which covered that commit and not the ones after it;
- silence about pushing.

When in doubt, ask. One question costs less than the churn of an unwanted force-push, a broken link in a published description, or work in progress made public. Report the result as, for example, "Committed locally as `8917cce`; say when you want it pushed", not "Pushed".

## On a security-fix branch, default to never pushing

While a security fix is in progress, the default policy should be stronger: never `git push` (or force-push), open a pull request, or make its commits visible in any other way. The user publishes the fix when it is ready. Even metadata about a fix in progress can tip off attackers before it is released: a branch name or a commit time on a public remote, or activity in CI.

Treat a branch as security-sensitive when it looks like one. Examples are a hotfix branch, a name such as `fix/*-security*` or `*-security-fixes`, work framed as a security fix, work on a CVE, or work coordinated with a security researcher. There, do not run `git push`, `gh pr create`, or anything similar. Give the user the finished state and let them publish it. If a request to push arrives anyway, point out the risk, and leave the push to the user unless they confirm that their policy allows it. If in doubt about whether a branch is security-sensitive, ask before any network action that involves the repository. The policy holds until the user says that the fix is public.
