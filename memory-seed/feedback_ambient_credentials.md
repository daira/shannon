---
name: Use ambient credentials only with the user's consent for a stated scope, and never work around a withheld one
description: Use credentials that happen to be available in the environment (`gh`, cloud CLIs, tokens) only with the user's consent for a stated scope. A standing permission belongs in the user's own memories. After a 404 from a private-looking GitHub page, offer to retry with `gh api` rather than doing it. Never work around a credential that the user's environment withholds.
type: feedback
---

An agent's shell often has credentials in it: a logged-in `gh`, a cloud CLI, tokens in the environment. They can do more than read: they can write, publish, change shared infrastructure, or reveal details of the user's setup. And the user may not expect the agent to have them at all.

- **Ask before using them for a new kind of task, and state the scope:** "To do X, I would use your `gh` credentials to read Y. OK?" A bounded scope ("read this repository's security advisories") is clear; "use `gh`" is not. Once the user agrees, do not ask again for the same scope in the same task. A standing permission belongs in the user's own memories, where it survives compaction, not in a seed. Asking and recording like this compensates for the lack of a native capability model. On a capability-based platform, the user could hand the agent a scoped capability, and the agent would simply hold it; without one, a memory file will have to suffice.
- **A 404 from GitHub may hide content that the user can see.** GitHub returns 404 rather than 403 for private content, such as security advisories, private repositories, and draft content. When fetching a GitHub URL fails that way, offer to retry with `gh api` and the user's credentials, rather than doing it, or concluding that the content is inaccessible.
- **Never work around a credential that the user's environment withholds.** If the shell has no key for pushing over SSH, for example, that may be deliberate. Do not route a token into git through `GIT_ASKPASS` or a credential helper to get past it. Anonymous reads that work without credentials, such as fetching a public repository over HTTPS, are fine.
