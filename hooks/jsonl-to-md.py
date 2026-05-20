#!/usr/bin/env python3
"""
Convert a Claude Code JSONL session transcript to Markdown that resembles
the CLI rendering: plain user/assistant text, compact tool invocations,
and tool results truncated to a configurable number of lines.

Usage:
    jsonl-to-md.py [--result-lines N] <transcript.jsonl> [output.md]

If output is omitted, writes to stdout. Default --result-lines is 30.
"""
import argparse
import json
import sys
from pathlib import Path


def truncate_lines(text: str, max_lines: int) -> str:
    lines = text.splitlines()
    if len(lines) <= max_lines:
        return text.rstrip()

    kept = "\n".join(lines[:max_lines])
    return f"{kept}\n… ({len(lines) - max_lines} more lines)"


def render_tool_call(block: dict) -> str:
    name = block.get("name", "?")
    inp = block.get("input", {}) or {}
    inline = json.dumps(inp, separators=(", ", ": "))
    if len(inline) <= 200 and "\n" not in inline:
        body = inline[1:-1] if inline.startswith("{") and inline.endswith("}") else inline
        return f"⏺ **{name}**({body})\n\n"

    return f"⏺ **{name}**\n```json\n{json.dumps(inp, indent=2)}\n```\n\n"


def render_tool_result(block: dict, max_lines: int) -> str:
    content = block.get("content", "")
    if isinstance(content, list):
        parts = []
        for sub in content:
            if isinstance(sub, dict) and sub.get("type") == "text":
                parts.append(sub.get("text", ""))
            elif isinstance(sub, dict) and sub.get("type") == "image":
                parts.append("[image]")
            else:
                parts.append(json.dumps(sub))

        content = "\n".join(parts)

    if not isinstance(content, str):
        content = json.dumps(content)

    is_error = block.get("is_error")
    truncated = truncate_lines(content, max_lines)
    marker = "⎿  Error" if is_error else "⎿"
    return f"{marker}\n```\n{truncated}\n```\n\n"


def render_assistant_block(block: dict) -> str:
    btype = block.get("type")
    if btype == "text":
        return block.get("text", "").rstrip() + "\n\n"
    elif btype == "thinking":
        # Skip thinking — the CLI hides it by default.
        return ""
    elif btype == "tool_use":
        return render_tool_call(block)
    elif btype == "image":
        return "*[image]*\n\n"
    else:
        return f"```json\n{json.dumps(block, indent=2)}\n```\n\n"


def render_user_block(block: dict, max_lines: int) -> str:
    btype = block.get("type")
    if btype == "text":
        return block.get("text", "").rstrip() + "\n\n"
    elif btype == "tool_result":
        return render_tool_result(block, max_lines)
    elif btype == "image":
        return "*[image]*\n\n"
    else:
        return f"```json\n{json.dumps(block, indent=2)}\n```\n\n"


def quote_user_text(text: str) -> str:
    text = text.rstrip()
    if not text:
        return ""
    else:
        return "\n".join("> " + line if line else ">" for line in text.splitlines()) + "\n\n"


def render_message(role: str, content, max_lines: int) -> str:
    # User messages that are pure tool_result blocks are shown inline as the
    # result of the prior tool call, no quoting.
    if isinstance(content, list) and role == "user" and all(
        isinstance(b, dict) and b.get("type") == "tool_result" for b in content
    ):
        return "".join(render_user_block(b, max_lines) for b in content)
    elif isinstance(content, str):
        return quote_user_text(content) if role == "user" else content.rstrip() + "\n\n"
    elif isinstance(content, list):
        if role == "user":
            parts = []
            for b in content:
                if isinstance(b, dict) and b.get("type") == "text":
                    parts.append(quote_user_text(b.get("text", "")))
                else:
                    parts.append(render_user_block(b, max_lines))

            return "".join(parts)
        else:
            return "".join(render_assistant_block(b) for b in content)
    else:
        return f"```json\n{json.dumps(content, indent=2)}\n```\n\n"


def convert(jsonl_path: Path, max_lines: int) -> str:
    out = [f"# Session transcript: {jsonl_path.name}\n\n"]
    # Tolerate non-UTF-8 bytes: replace them with U+FFFD rather than
    # aborting. Claude Code transcripts are expected to be UTF-8 JSONL,
    # but if a stray byte sequence is somehow embedded (e.g. a tool
    # result that includes binary output), we'd rather render a slightly
    # garbled session than refuse to render anything at all.
    with jsonl_path.open(encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue

            try:
                evt = json.loads(line)
            except json.JSONDecodeError:
                continue

            etype = evt.get("type")
            if etype not in ("user", "assistant"):
                continue

            msg = evt.get("message", {})
            role = msg.get("role", etype)
            content = msg.get("content")
            if content is None:
                continue

            out.append(render_message(role, content, max_lines))

    return "".join(out)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--result-lines", type=int, default=30,
                        help="max lines of tool result output to show (default 30)")
    parser.add_argument("input", help="input JSONL transcript")
    parser.add_argument("output", nargs="?", help="output Markdown file (default stdout)")
    args = parser.parse_args()

    src = Path(args.input)
    if not src.exists():
        print(f"error: {src} not found", file=sys.stderr)
        return 1

    md = convert(src, args.result_lines)
    if args.output:
        Path(args.output).write_text(md)
    else:
        sys.stdout.write(md)
    return 0


if __name__ == "__main__":
    sys.exit(main())
