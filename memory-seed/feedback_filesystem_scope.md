---
name: Search only relevant project directories; outside them, read only known paths, and never scan system directories or /tmp
description: Search only within project directories known to be relevant to the current task. Never `find /`, `grep -r /`, or a wide glob over `/tmp`, `/home`, `/etc`, `/usr`, `/var`, or another user's home, even with `--maxdepth`. The walk is costly, and its output exposes system state unrelated to the task. `/tmp` is shared with other processes and sessions, so its matches are usually false positives. Read a path that a tool reported by that exact path rather than searching for it. Reading a known path outside the project is fine for memory files, an executable found with `which` or `command -v`, and a conventional config file that the task needs. One that can hold secrets or host details needs the user's consent. Only an explicit system-administration request justifies a wider search. Where to write files instead: feedback_repo_scratch_dirs.
core: true
type: feedback
---

Keep searches within the project directories known to be relevant to the current task, and paths explicitly linked into them. Do not scan system directories or shared space to find something, or to work around not knowing where it is. Outside those directories, read only paths that are already known, for the reasons below.

**Never**, even with `--maxdepth`, `-name`, or another narrowing:

- `find`, `grep -r`, or `rg` rooted at `/`, `/tmp`, `/home`, `/etc`, `/usr`, `/var`, `/opt`, `/srv`, `/root`, or any user's home directory;
- a wide glob over such a directory, such as `ls /home/*` or `cat /etc/*.conf`.

The walk is costly, and its output exposes system state that has nothing to do with the task. `/tmp` in particular is shared by every process on the system, including other Claude sessions and debris from crashed processes. A match there is usually a false positive that leads to a wrong diagnosis: "the failing test's log is in `/tmp/testXYZ`", when that file is left over from yesterday.

**Reading a known path outside the project** is fine for:

- memory files, under `~/.claude/memory/` or a project's memory directory;
- an executable located by name, with `which <tool>`, `command -v <tool>`, or one or two conventional install paths;
- a conventional configuration file that the task needs, read-only, such as `~/.gitconfig` or a project's `rust-toolchain.toml`;
- with the user's consent, a file that can hold secrets or host details, such as `~/.ssh/config` or a credentials file.

Even with consent, avoid a command that would show secrets in its output, unless the user has explicitly asked for that.

**An explicit system-administration request** ("check the mounts", "find what is listening on port 8080") is the one case that can justify a search beyond the project. The user is then aware of its scope, and takes responsibility for it.

When it is not clear whether a path counts as inside a relevant project directory, ask before searching.

**How to apply:**

- To find a tool, use `which <tool>` or a known path. If it is not there, ask rather than walk a directory tree.
- To check whether something is installed, ask the package manager (`brew list`, `dpkg -l`, `pip show`, `cargo --list`).
- When a tool reports a path, such as a log, a build artifact, or a test's temporary directory, use that exact path later. If the file is gone, say so rather than searching or globbing for it.
- If a diagnosis seems to need a scan beyond the project, stop and ask: usually the path is already known, or the scan is not needed.

Where to write files instead of `/tmp`: [[feedback_repo_scratch_dirs]].
