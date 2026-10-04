---
name: Reuse before building — search for existing forms, ask what structure the work has, and define things in their most principled form
description: Before writing new supporting machinery (helpers, lemmas, combinators, a module), search the codebase for the same content in another form. Search by concept, not only by the name that you would give it: the types involved, sibling operations, and other code that needs the same result. Search again whenever the work gains a new dimension, such as a second consumer or a second payload type. Ask whether new machinery is specific to where it sits, or general infrastructure that merely has a consumer there. Ask too what algebraic structure it has: near-duplicates are often one construction at different parameters. Ask the structure question at moments in the workflow: before a large refactoring, after any improvement, and when something proves harder than expected. Define a value by reference to whatever already carries it, rather than copying a literal. Tie a value that must match an external source to that source with a checked test or assertion.
type: feedback
---

## Search for the same content in another form

Before writing new supporting machinery, such as helper functions, lemmas, combinators, or a module, survey the codebase for the same content in another form. Search by concept, not only by the name that you were going to use:

- everything that mentions the type or structure being extended, across its whole namespace;
- sibling operations of the function at hand, since a lookup function's update and invariance properties tend to live beside it;
- other code that needs the same result, and what it built for itself.

When a reviewer or the user points at existing machinery, read that file completely before building further.

Building something that compiles, or that passes its tests, shows that it is correct, not that it is needed. In one session, a whole support layer was written and built before a survey, prompted by the user, found every piece already present under other names, in more general forms. Duplication costs twice: the wasted work, and two mechanisms that later readers have to reconcile. Existing work has also usually met the subtle cases that a rewrite would rediscover the hard way.

## Search again as the work grows

A survey at the start is not enough. Search again whenever the thing being built gains a new dimension: a second payload type, a second consumer, or a generalization. In another session, the early survey found and even used one existing implementation. Yet a fifth copy of the same extraction was being added before the survey was repeated, and found four.

## Two questions that find what a name search cannot

- **Is this specific to where it sits?** Machinery often lands in a directory because its first consumer lives there, not because it is about that directory's subject. Ask this of your own new module, not just of inherited code. If the answer is no, the layer below probably has some of it already. The same applies to meta-code: before writing a custom tactic, macro, or plugin, check whether existing ones compose to do the job.
- **What algebraic structure is this?** Near-duplicate families are often one construction at different parameters, and naming the structure finds duplicates that share no identifiers. Once the objects and maps are named (a monoid, a lattice, a homomorphism), the general results that compose them become obvious and reusable, and special cases dissolve.

A judgement such as "this is turning into bespoke plumbing" is usually made only in hindsight. So ask the structure question at moments that the work passes through anyway:

1. **Before any large refactoring.** The decision to do bulk work is itself the trigger: asked before writing many near-duplicate definitions, the question can collapse them into one per family.
2. **After any improvement,** whether a generalization, a simplification, a deletion, or a faster version. Each one changes the situation, and the new situation may admit a further improvement. That further step usually needs a design change of its own, not just the removal of code that became dead: ask what you would build differently now.
3. **When something proves harder than expected,** recall what it resembles, in your experience or in the literature. A known pattern often supplies both the right factoring and the words to state it.

Some structural signatures, weaker but checkable while typing, also call for the question:

- an induction or recursion over a free structure, such as a list, with one case per constructor, which often rediscovers a fold;
- the same shape of definition or lemma at two or more parameter types;
- a case analysis whose branches mostly close trivially, where the content is in the side condition;
- a hand-written version of a binary law for three or four arguments.

**A huge statement with a short proof means a missing abstraction.** Its bulk is usually repeated structure that wants a definition: factor out the recurring pieces, and state the siblings through them too. On a large proof, pick key lemmas rather than one monolithic proof, and commit the refactoring that introduces new abstractions before the new code that uses them ([[feedback_commits_sequential_coherence]]).

## Define things in their most principled form

- **Refer to the source that already carries a value.** If a value is already held by another definition in the codebase, refer to that definition rather than pasting the literal again. The definition then says what the value is, and there is no second copy to drift.
- **Tie a value that must match an external source to it with a check.** When a constant must match a deployed implementation or a reference table, keep the literal. Add a machine-checked assertion of the connection next to it: a test, a static assertion, or a checked example. Spell the assertion so that it mirrors the source's own text. If the source stores a constant as a list of limbs, compare with those limbs verbatim, so that a reader can check it by eye. Cite the source with a pinned link ([[feedback_durable_prose]]).
- **Work out the principled option at a design fork.** When the choice is between a cheap local workaround and a principled restructuring, many users prefer the principled side, even at the cost of a wider refactoring. Present the principled option fully worked out, not as an afterthought. Split it into a later unit only when it deserves a review of its own.
