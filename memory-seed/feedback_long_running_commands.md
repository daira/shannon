---
name: Long-running commands — tee to a log, keep the exit status, tell the user the path, and never trust a build that overlapped edits
description: Run any command that may take a while, or whose output the user may want to inspect, as `(set -o pipefail && <cmd> 2>&1 | tee work/<name>.log | tail -50)`. The log keeps the full output, `pipefail` keeps the command's own exit status, and the subshell scopes the option. When the command runs in the background, tell the user the log's path. Judge success from the log's own success line, not from a chained `echo $?`. How safely two builds can share one output tree depends on the build system. Cargo's locking is robust. Other build systems (e.g. Makefile-based, Lean's lake) allow corruption, races, or deadlocks, and should therefore be serialized. Alternating between two checkouts or worktrees, kept rather than recreated, hides build latency. Disregard a build that overlapped with editing, and do not interrupt a long build for a cosmetic edit. When a build in a checkout is the user's next step, leave the checkout on the branch that the build needs and say which branch it is on. Before calling a build stuck, rule out a slow step and a machine that slept. Run benchmarks in the foreground with nothing else running, and on a laptop only on mains power. A backgrounded tool that reads stdin hangs: pass its no-stdin option (marp-cli `--no-stdin`) or `< /dev/null`. A `grep -v` that filters everything fails a `pipefail` chain, and a `;` lets a later `git commit` run after a failed step: keep the commit in its own command. A background script pauses at a step that needs a permission prompt, such as a `git commit` inside it, until the user answers, so keep such steps out of long background jobs.
core: true
type: feedback
---

## Log it, keep its status, and say where the log is

For any command that may take a while, or whose output the user may want to see, use:

```bash
(set -o pipefail && <cmd> 2>&1 | tee work/<descriptive-name>.log | tail -50)
```

The trigger is the command's duration, or the user's interest in its result, whatever kind of command it is: builds, test runs, analysis scripts, data processing, long searches, or benchmarks.

- **`tee` keeps the full output** in a log under the project's `work/` directory, for `tail -f`, `grep`, or a later look. Truncating with `head` loses the rest for good. Give the log a descriptive name.
- **`pipefail` keeps the command's exit status.** Without it, the pipeline reports the status of `tail`, which almost always succeeds, so a failed build looks successful. The subshell keeps the option from leaking into later commands. `bash -o pipefail -c '…'`, or writing to a file and reading it afterwards, also works.
- **Tell the user the log's path** when the command runs in the background, so that they can follow it themselves: "Build running in the background; the log is `work/build.log`."

Each part is weak alone: `tee` without `pipefail` hides failures, `pipefail` without `tee` leaves nothing to inspect, and a log whose path the user does not know cannot be followed. Use the whole pattern even when only a filtered summary is wanted. Use it also for a build that is one step in a longer chain: if the chain is later backgrounded and hangs, nothing shows how far an unlogged step got.

**Judge the result from the log.** In `(… | tee log | tail); echo "rc=$?"`, the reported status is the `echo`'s. Check the log's own success line, and look for error lines, rather than trusting the status of a chained command. Two related traps: a `grep -v` filter on the pipeline's output exits 1 when it filters everything, so with `pipefail` a successful command looks failed and a following `&&` chain stops; and a `;` after the filtered pipeline lets a following `git commit` run even though the step before it failed, which commits stale files. Keep the commit in a separate command, after reading the log.

**A backgrounded command can hang on stdin.** Some tools read standard input when it is open but not a terminal, which is what a backgrounded command gets: marp-cli waits "for data from stdin stream" and never renders. Pass the tool's no-stdin option (`--no-stdin` for marp-cli) or redirect `< /dev/null`, and put the option in the Makefile so that the next backgrounded build cannot hang.

**Under zsh,** `${PIPESTATUS[0]}` expands to nothing, silently; zsh's equivalent is the 1-indexed `$pipestatus`. A variable named `path` is tied to `PATH`, so a loop variable of that name breaks every later command. The subshell form above works in both bash and zsh.

## Concurrent builds on one output tree

How well two builds share one output directory depends on the build system:

| Build system | Two builds on one output tree |
| --- | --- |
| cargo (Rust) | robust locking; no failure seen |
| make (C and C++) | corruption seen |
| lake (Lean) | races and hard deadlocks seen; serialize strictly |

A race looks like real defects: an artifact "not found" that is on disk a second later, or a truncated metadata file, and a rerun fails on different files. A deadlock just stops, with every driver alive, the workers idle, and the log unchanged. To diagnose one, compare the log's modification time with the clock, and count the running build drivers: more than one is the usual cause.

- **Before starting a build, check whether one is already running,** and after a build fails, confirm that its driver has exited before retrying. A notification that a background task completed does not prove it: a failed build's driver has outlived its notification by many minutes, holding the lock the whole time.
- **To stop a stuck build,** stop the background task by its ID, then kill any surviving driver by its exact PID ([[feedback_kill_by_pid]]). Never delete a lock file to get unstuck ([[feedback_git_safety]]).
- **Alternate between two checkouts or worktrees.** Whenever a long build starts in one, work in the other. This hides the build's latency, and keeps two builds from sharing one output tree. The first build in a new checkout or worktree is often expensive, so keep both and reuse them, rather than throwing one away after each task. Move work between them through git, not by copying files. Commit in one, and fast-forward the other to that commit with `git merge --ff-only`, or with `git pull --ff-only` in a clone whose `origin` is the first clone's path.

## Reading a build correctly

- **A missing line is not evidence of a skip.** A build system prints when a step finishes. So a step that has been running for an hour has printed nothing, which looks the same as a step that was skipped. Under parallelism, a progress counter does not settle it either. Check state instead: whether the step's artifacts exist, and which files the running workers are compiling.
- **Before calling a build stuck, rule out a slow step.** An incremental build can replay an expensive step for a long time, so its cost reappears only after a clean build. Check that step's time from scratch in an earlier log. A frozen log is also what a machine that slept looks like.
- **Prefer evidence that does not depend on `ps`.** On macOS, `ps` refuses some fields without an entitlement, which can also shift its columns, so a reading of 0% CPU proves nothing there. Whether new artifacts are appearing, over a window longer than the slowest step, is better evidence.
- **Build times are wall-clock times,** so a machine that slept during a run inflates them, and so does the elapsed time that `ps -o etime` reports. Before quoting a time, ask whether that could have happened. Several independent measurements that agree are more trustworthy than one. CPU time is the honest measure. `ps` reports it as the cumulative `time` field, but macOS refuses that field without an entitlement, even for the shell's own processes, so there it comes from Activity Monitor. Usually a decision needs only "long enough to be worth removing", not a precise figure.
- **Run benchmarks in the foreground, with nothing else running.** A benchmark left in the background while the agent keeps working competes with that work for CPU. On a laptop, first check that it is on mains power (`pmset -g batt` on macOS): on battery, one benchmark took 13.0 ms instead of 8.7 ms. Split a long benchmark run by filter to fit the foreground timeout.
- **Compare timings from the same starting state:** the same prerequisites already built, and the same command for each variant. Say which state they shared, and give user time as well as wall time, since together they show whether the work ran in parallel.
- **A replay says nothing about trust.** Whether a step was replayed from the build system's cache or rebuilt tells you whether its cost was paid this time. It does not make the result less trustworthy, since the cache is already part of what the toolchain trusts, so do not report a replayed result as weaker. For more assurance than the toolchain itself gives, build from a clean checkout, ideally on another machine.

## Builds and edits

**Disregard a build that overlapped with editing.** If files were edited while a build ran, the build may have read a file before the edit, so its result can describe a tree that no longer exists. Rerun it. Building single modules while editing is worse, since afterwards nobody can tell which version of the source each artifact came from; verify with a full build.

**When a build in a checkout is the user's next step, leave the checkout on the branch that the build needs, and say which branch it is on.** The user builds from the checkout's current state, not from the branch that was last discussed. In one session, a branch for a second task was created after the first task's commits and the checkout was left on it, so the user's build of the first task's branch ran on the second one, and had to be stopped and restarted. Name the branch in the message that hands the build over, and switch back first if another branch was checked out in between.

**So a trivial edit is never worth interrupting a long build.** Any edit made during a build costs the whole build. Where a build system records source positions in its artifacts, even a whitespace change cascades a rebuild through everything downstream. Before editing during a build, ask what the edit is worth against restarting the build. Queue a cosmetic edit until the build finishes. If an edit must go in now, stop the build deliberately, make the edit, and restart. Do not over-protect a work-in-progress branch from an imperfect intermediate state when the reviewer already knows that it is in progress.

## Keep permission-prompting steps out of background scripts

A background script pauses at any step that needs a permission prompt, such as a `git commit`
inside it, until the user answers, and nothing in the script's own log shows the pause. One
pipeline's commit step waited an hour for the prompt. Which steps prompt is hard to predict: it
depends on the harness's heuristics and on which grants the session has already made. So do not
rely on predicting it. Put the steps with side effects that can live outside, such as commits,
in their own foreground calls before or after the long job, and after launching a background
job check its log's timestamps once: a step that should have finished and has logged nothing
may be waiting on a prompt, which looks the same as a hang.

## Memory-heavy checkers run one at a time

A checker or exporter that loads a whole development, such as a proof checker over a large
library, can take tens of gigabytes each. Never run two
at once, and never queue a second stage so that it may start while the first still runs.
Measure the first run's peak memory before deciding on any parallelism, and poll it with a
kill-by-PID threshold during long runs. In one session, a bisection that launched a second and
third stage while the first was still running put three checkers and their exports in memory at
once, about 200 GB, and the user had to kill them.
