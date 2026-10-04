#!/usr/bin/env python3
"""List each reference to a memory that is not one of Shannon's seeds.

Usage: check_memory_references.py ROOT

A seed, a hook, or the CLAUDE.md template that refers to a memory outside `memory-seed/` points
adopters at something they do not have, which is a sign that the seed corpus is incomplete. The
check reads `[[name]]` links and `name.md` references in `memory-seed/`, `claude-md/`, and
`hooks/`. In `memory-seed/` and `claude-md/` it also reads bare names such as
`feedback_repo_scratch_dirs`, as descriptions use them; in `hooks/` it does not, since shell
variables such as `project_dir` look like memory names. Prints `path:line: name` for each
unresolved reference, and exits 1 if there is any.
"""

import os
import re
import sys

PREFIX = r"(?:feedback|project|user|reference)_[A-Za-z0-9_]+"
LINK = re.compile(r"\[\[(" + PREFIX + r")(?:\.md)?\]\]")
FILE = re.compile(r"\b(" + PREFIX + r")\.md\b")
BARE = re.compile(r"\b(" + PREFIX + r")\b")


def main(root):
    seeds = {f[:-3] for f in os.listdir(os.path.join(root, "memory-seed")) if f.endswith(".md")}
    missing = []
    for directory, patterns in [
        ("memory-seed", (LINK, FILE, BARE)),
        ("claude-md", (LINK, FILE, BARE)),
        ("hooks", (LINK, FILE)),
    ]:
        path = os.path.join(root, directory)
        if not os.path.isdir(path):
            continue
        for name in sorted(os.listdir(path)):
            file = os.path.join(path, name)
            if not os.path.isfile(file):
                continue
            with open(file, encoding="utf-8", errors="replace") as f:
                for number, line in enumerate(f, 1):
                    found = {m.group(1) for pattern in patterns for m in pattern.finditer(line)}
                    for reference in sorted(found - seeds):
                        missing.append(f"{directory}/{name}:{number}: {reference}")
    for entry in missing:
        print(entry)
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
