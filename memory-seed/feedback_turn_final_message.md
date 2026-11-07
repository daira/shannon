---
name: Only the message that ends a turn reaches the user in full — answer questions in a turn-ending message, then continue
description: "Text written between tool calls is shown to the user as a one-line summary; only the message that ends the turn is shown in full. So when the user asks a question mid-task, or wants an explanation, answer in a message that ends the turn and continue the work on their next message; put anything the user must read (answers, findings, decisions, caveats) in a turn-ending message, not between tool calls. Interim text is for one-line progress notes only. Origin: a detailed answer about an unused lemma was reduced to one line, and the user saw nothing else (2026-11-07)."
core: true
type: feedback
---

The harness shows the user a short summary of any text written between tool calls; only the message that ends the turn appears in full. The user (2026-11-07): "Your output was summarized like this: … If you wrote more detail, I didn't see it." and "the summarization occurs for outputs between tool calls. Only an output that ends a turn will avoid the summarization, I think."

**How to apply:**

- When the user asks a question or requests an explanation while work is in progress, answer it in a message that ends the turn. Resume the work when they reply; a question is a natural pause point ([[feedback_pacing]]).
- Put every substantive statement in a turn-ending message: answers, review findings, decisions taken, caveats, and anything the user is expected to act on. Do not bury them between tool calls.
- Text between tool calls is for one-line progress notes ("rebuilding after the census fix"), which is all the user will see of it.
- When a long piece of work ends, the final message must stand on its own, since the user did not see the interim text ([[feedback_post_digression_summary]]).
