---
name: Keep hard-wrapped prose wrapped — rewrap edited paragraphs with rewrap-check, and never split a code span, link, or URL across lines
description: When an edit leaves a line of a hard-wrapped paragraph more than about 10 columns longer or shorter than its neighbours, rewrap the paragraph to the file's established width. Leave it when the difference is small, or when an unbreakable span (inline code or math, a link, a URL) makes the line long. Before each commit, run `~/.claude/rewrap-check --width N <paths>` on the changed files; `--fix` rewraps only the edited paragraphs, and `--all` checks whole files, including untracked drafts such as a commit message. Read the diff of whatever `--fix` changed. Measure width in characters, not bytes. Where text is rendered as Markdown, an inline code span or a link opens and closes on the same line. A URL is never broken or trimmed to fit a width.
type: feedback
---

Many files are wrapped by hand: specifications, READMEs, design documents, commit messages, and the comments of source code. They are often read in terminal viewers or as line-based diffs, where one long line among short ones (or vice versa) is jarring and looks careless.

## Rewrap an edited paragraph when its lines drift

After an edit, rewrap the paragraph if any of its lines ends up more than about 10 columns longer or shorter than the others. Match the width that the file already uses, which varies between files, rather than imposing another; commit messages are usually wrapped at 72. The last line of a paragraph may be short.

Leave the paragraph alone when:

- the difference is small, under about 10 columns, since a smaller diff is easier to review;
- the long line contains an unbreakable span, such as inline code or math, a link, or a URL. Such a line can stay long.

This applies to every way of editing, not only to the editor tool. A scripted substitution (`sed`, a Python `str.replace`) lengthens or shortens lines too, and it is easy to skip the check because the substitution "succeeded".

## Use rewrap-check

`rewrap-check`, which Shannon's `install.sh` installs as `~/.claude/rewrap-check`, does the check. It flags each paragraph that an edit touched whose line breaks differ from a greedy wrap at the given width, and it ignores untouched paragraphs:

- `~/.claude/rewrap-check --width N <files>` checks the uncommitted edits; `--commit REF` compares with another commit, and `--staged` checks the index.
- `--fix` rewraps the flagged paragraphs in place. It exits 0 unless the run fails, and prints a note for each over-width line that it cannot reflow. `--show` and `--diff` print the rewrap instead.
- `--all` treats every line of the named files as edited, and reads files that git does not track. Use it for a whole new file, or for a draft outside the repository's history, such as a commit message under `work/`.

It reads Markdown and plain text, reStructuredText, and the comments of Rust, Python, and Lean, including Python and Lean docstrings and Python scripts that have no extension. It keeps inline code, math, and links whole, and reports a code span split across lines. It also reports any changed line that is too wide, except in tables and fenced code blocks. Pass it file paths, not directories.

Run it on the changed files before each commit, and read its report. **Read what `--fix` changed** before committing. It can join a line that was broken on purpose, or split a span that it did not recognize, so look at each rewrapped paragraph in `git diff`.

## Inline spans, links, and URLs stay whole

Where text is rendered as Markdown, as GitHub renders commit messages, PR descriptions, issues, comments, and `.md` files, and as documentation tools render many doc comments:

- **An inline code span opens and closes on the same line.** A line break inside one turns into a space, which changes the code. When wrapping, move the whole span onto one line; for a span too long for any line, use a fenced code block instead.
- **A link `[label](url)` stays on one line.** If the sentence around it wraps, put the link on a line of its own.

Anywhere, **a URL is unbreakable, and exempt from width limits.** Never put a line break inside one, and never shorten or trim a URL just to fit a width. A shorter equivalent URL is fine once you have tested that it works.

## Pitfalls

- **Measure width in characters, not bytes.** `awk`'s `length` counts bytes. So a line holding a multi-byte character, such as `⟨`, `→`, or an em-dash, reads two or three columns longer than it is. Use `rewrap-check`, or Python's `len()` on the decoded text. Treat an `awk` report of one or two columns over the limit, on a line with such characters, as suspect. BSD `fmt` counts bytes too.
- **Replace whole lines when editing part of a wrapped sentence.** The replaced text may end partway through a wrapped line. Then the replacement is joined to the rest of that line, which can produce a line far over the width. Include the whole wrapped lines in the edit, or rewrap the paragraph afterwards.
- **For a paragraph that a script computes,** wrap it with Python's `textwrap.TextWrapper(width=N, break_long_words=False, break_on_hyphens=False)`, so that identifiers and URLs stay whole, with `initial_indent` and `subsequent_indent` for a comment marker. For a block comment, append its closing marker (such as ` */` or Lean's ` -/`) to the text before wrapping, so that it lands on the last line. To replace a paragraph in a file, wrap both the old and the new text with the same settings. Check that the old text occurs exactly once before replacing it. Then a paragraph that has moved is an error rather than a silent no-op.
