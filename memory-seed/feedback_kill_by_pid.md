---
name: Kill processes only by explicit PID — never by name or pattern
description: To stop a process, find its exact PID, confirm that it is the intended target, and `kill <pid>`. Never `pkill <name>`, `pkill -f <pattern>`, `killall <name>`, or `kill $(pgrep …)`. A name or pattern also matches unrelated processes, such as the user's editor running the same tool, and `pgrep NAME` matches substrings (`pgrep lean` matches `CleanupPreparePathService`). Stop a background job by the task ID or PID that its launch reported, and its children (`pgrep -P <pid>`). Send TERM first, and keep `-9` for a process that ignores TERM.
core: true
type: feedback
---

Never kill a process by its name or by a pattern on its command line. That rules out `pkill <name>`, `pkill -f <pattern>`, `killall <name>`, and `kill $(pgrep …)`. Find the exact PIDs, confirm that each is the intended target, and kill only those.

A name or a pattern can match far more than intended. `pkill` and `killall` match the process name, so every process of that name dies; `-f` only widens the match to the whole command line. `pgrep NAME` matches substrings of names: `pgrep lean` also matches `CleanupPreparePathService`. The processes that share a tool's name are often ones that the user cares about, such as an editor's language server or another session's build. Killing the wrong one is hard to undo. In one session, `kill $(pgrep -f 'lake build|lean --')`, meant to stop one background build that held a lock, killed 75 processes, among them the editor's language servers and other sessions' workers. The pattern kill is never the shortcut that it appears to be.

Signs that a kill went wrong:

- a surprising exit status, such as 144 (128 + 16) when the command signalled its own subshell;
- unrelated processes vanishing;
- more processes ending than expected.

**How to apply:**

- Stop a background job by the task ID or the PID that its launch reported, and stop its children if needed. Where the harness has a tool for stopping tasks, use it.
- To find candidates, list them read-only with their PID, parent, and full arguments: `ps -axo pid,ppid,etime,args | grep <pattern>` is fine for listing. Match the full path of the executable or its exact last component, and check each PID's identity and parent.
- To collect a process's subtree, walk its children from the root PID with `pgrep -P <pid>`, repeatedly.
- `kill` only the PIDs that you confirmed. Send TERM first, and keep `-9` for a process that ignores TERM.
