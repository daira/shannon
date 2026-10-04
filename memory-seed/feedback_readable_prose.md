---
name: Write durable prose in the readable conversational register — short sentences, punctuation where a reader would pause, and lists that say what they are
description: Agents tend to write comments, docs, and commit messages in a compressed register (long sentences, nested qualifiers, noun stacks, undefined terms) although their conversational explanations read well. Draft durable prose as you would explain it aloud, and where a readable explanation already exists in the session, transplant it rather than re-deriving a compressed version. Put one idea in each sentence, define each term at first use, and keep parentheses at most one level deep. Before each commit, PR body, or posted comment, check with `~/.claude/long-sentences` for sentences over about 30 words, runs of over 25 words without punctuation, and two semicolons in one sentence. Read what it flags before committing or posting; it is not a gate. Then read each flagged sentence for its subject-verb distance: more than about 10-12 words of modifier between them needs a comma or a split. Use parentheses for an aside that the sentence can lose, and em-dashes for one that the argument needs. Mark a list as exhaustive or as examples ("e.g."), keep its entries uniform, and separate items with semicolons when they contain commas. A commit message gives what changed and the one operative reason.
core: true
type: feedback
---

## The register problem

Agents tend to write durable prose (documentation, comments, docstrings, design documents, commit messages) in a different register from their conversation. The conversational register is readable. The documentation register has long sentences, nested qualifiers, stacked nominalizations, coined but undefined terms, and parentheses inside parentheses. In one user's words: "you write perfectly readable conversational prose, and then when you write comments or documentation, it's in a different register that is far harder to read … Just where readability is most important!"

- **Draft durable prose as if explaining it in conversation.** Then remove only the conversational framing (questions, "shall I", plans in the first person), and keep the sentence structure.
- **Transplant, don't re-derive.** If the session already holds a readable explanation of the same content, write it down nearly verbatim, rather than composing a compressed "doc version" from scratch.
- **Read it back.** If you would not say a sentence aloud while explaining the topic, rewrite it. Reading back is not enough by itself, though: the compressed register reads fine to its writer, so also use the mechanical check below.
- **Keep sentences simple.** One idea per sentence. Define each term at first use. Prefer verbs to nominalizations. Keep parentheses at most one level deep.
- **No compressed jargon.** A coined shorthand ("the ±-fibre leaves ±y") hides the actual statement ("two points with equal x-coordinates have y-coordinates equal up to sign"). Say the statement in plain words, even for an expert audience: conversational does not mean simplified. Do not defend a shorthand on the grounds that insiders will decode it, since they often decode it wrongly or not at all. Likewise, do not carry a team's local metaphor into prose for a wider audience; unpacking it often exposes a distinction that the metaphor blurred.

Signs of the problem:

- the user says that the chat explanation read better than the doc, or asks you to "just write down what you said";
- the user asks for shorter sentences, or quotes a sentence back as too long.

## Why short sentences: a sentence break is a thinking break

At a sentence break, the reader stops to reconcile what they have read: they confirm the parse, settle what each pronoun refers to, and decide what each connector meant. A simple sentence can be understood on the fly. A long one, or one whose structure is only revealed late, leaves the reader unsure whether they parsed it correctly, and the uncertainty compounds.

Parsing load also hides gaps in the content. A reader who spends their attention on structure does not notice that a phrase said nothing, or that a sentence claimed something unsupported. Splitting a long sentence into one claim per sentence makes each claim answerable on its own terms, so a clarity rewrite often reveals overclaims ([[feedback_durable_prose]]). A rewrite is not finished until each sentence stands alone. A replacement for jargon that is still unclear out of context needs another pass, which names the concrete objects end to end.

The test while drafting: what must the reader hold open until the sentence ends (referents, attachments, the meaning of connectors)? Break the sentence where that state can be discharged.

## Check mechanically, then read

Before each commit, amend, reword, PR body, or posted comment, and on each changed doc comment, run a sentence-length check, and deal with what it flags:

- a sentence of more than about 30 words, counting a code span as one word;
- a run of more than about 25 words without internal punctuation;
- two semicolons in one sentence.

The `long-sentences` script, which Shannon's `install.sh` installs as `~/.claude/long-sentences`, does it. Pipe the text to it, or pipe a diff to it with `--diff` to check only the comments that the diff adds (`git diff --cached | ~/.claude/long-sentences --diff`). Run it as its own step, and read its output before committing or posting; do not gate the step on it. A flagged sentence is one that might need attention, not necessarily one to change. Leave a sentence that the user has approved.

Then read each flagged sentence, and every sentence over about 20 words, for **subject-verb distance**, which no script measures. If more than about 10–12 words of modifier separate the main subject from its main verb, put a comma at the end of the longest modifier, or split the sentence. A pause-comma is acceptable there even where grammar would omit it. Restrictive modifiers stacked two or more deep ("the X constrained to Y the Z used to W") are often why the distance grew. They usually need a comma at the end of the outer one. These thresholds are approximate: lower them when a sentence that passes still reads awkwardly, and raise them if the commas start to stutter.

Behind the textual tests is a simpler one. If a reader saying the sentence aloud would naturally take a breath at some point, that point needs a comma, a semicolon, an em-dash, or a sentence break. Use it to cross-check a verdict that feels wrong.

## Choosing the punctuation

- **Comma:** for a soft pause, the end of a modifier, or a light aside.
- **Parentheses or em-dashes** for an aside inside a sentence, chosen by the removability test. If the sentence still holds together and stays accurate without the aside, it is incidental: use parentheses. If removing it damages the argument, it is necessary: use em-dashes, or work it into the sentence, or give it a sentence of its own. An aside can be necessary even when the bare sentence parses, when it supplies the intended referent of a vague noun phrase ("the `Manual` case —user-initiated rebuilds— is logged separately"). Use at most one pair of em-dashes in a sentence. Parentheses do not make an aside free: a sentence that is long only because of its asides still costs the reader, and many asides make frustrating reading.
- **Semicolons are usually sentence breaks in disguise.** A semicolon, like a separating em-dash, says that two independent clauses are more closely connected than a sentence break would imply. Typically the second follows from the first, so check whether that link matters. When it does, an explicit connective ("so", "because", "then") at the start of a new sentence usually carries it as well.
- **Full stop:** when no punctuation inside the sentence reads cleanly, two short sentences beat one awkward one.

## Lists

- **A list of parallel clauses** often reads better as bullets under an introductory sentence than as one long sentence, or as a run of disconnected short ones. Each bullet is one unit to reconcile, and the introduction keeps what links them. A semicolon at the end of a bullet is fine.
- **Say whether a list is exhaustive.** A bare list ("(plaintexts, keys, and transaction fields)") claims to be complete. If the items are examples, say so ("e.g."), and if you cannot check that a list is complete, mark it as examples. Close the last item with a conjunction (", and", ", or", or "; and"): "A, B, C" reads as an open-ended enumeration.
- **Separate inline items with semicolons when an item contains a comma**, and keep the conjunction before the last item ("; and"). With commas inside the items, comma separators leave the reader unable to find the boundaries.
- **Keep a list's entries uniform,** in one of two styles:
  - every entry is a full sentence or paragraph, capitalized and ending with a full stop; or
  - every entry is a fragment, and together they make one sentence: lowercase, separated by semicolons, with "and" or "or" before the last, and a full stop at the end.

  An entry that needs several sentences puts the whole list in sentence style. Parallel lists in one document use the same style.

## Smaller points

- A sentence that opens with a preposition and a bare "it" ("Over it, the event …") reads badly. Repeat a short noun phrase instead ("Over that space, the event …").
- **A commit message gives what changed, and the one operative reason.** Cut secondary justifications, which dilute the first. Cut the story of how a mistake arose, and caveats about scope that the diff already shows.
- Concision is about density, not omission: keep everything load-bearing, and say it in shorter units. Cut throat-clearing and restatement; a doc comment says what the thing is, then the key facts.
