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

Building something that compiles, or that passes its tests, shows that it is correct, not that it is needed (see the first incident below). Duplication costs twice: the wasted work, and two mechanisms that later readers have to reconcile. Existing work has also usually met the subtle cases that a rewrite would rediscover the hard way.

## Search again as the work grows

A survey at the start is not enough. Search again whenever the thing being built gains a new dimension: a second payload type, a second consumer, or a generalization. The second incident below shows why.

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

## Two incidents

**A support layer that already existed.** A support layer for a probabilistic bound was designed, written, and built. It had four parts:

- an update-invariance lemma for a lookup function;
- a builder for an escape set from per-query annotations;
- a variant of the adversary that completes its queries, with four transport lemmas;
- the composed bound.

Then the user asked for a check that these were not already present in some form. A survey found every piece already in the tree, under other names:

- the invariance lemma duplicated an existing statement exactly;
- a membership lemma existed as the stronger "if and only if";
- the escape-set builder existed with an extra fallback branch, which made the whole completed-query variant unnecessary;
- the composed bound existed in a more general form, which was also the intended skeleton for the theorem being built.

All of that work was wasted, and it would have shipped two mechanisms for one job.

**A fifth copy.** A compositional trace layer for a circuit formalization was being built, to replace an expensive certified computation. The work went one payload at a time: one label shape, then a second. When a third was needed, a shared layer was written to avoid a third copy. Asked whether that new module was specific to the proof it served, the answer was no. The same question had been asked twice that session about other people's files, and not once about the module just written. The survey that followed found the same extraction already implemented four times:

- twice in the layer below, as two record types that were the two halves of one;
- once in the upstream framework, fused with placement;
- once in the local tree.

One of those files had already been used, earlier in the same work, for a different lemma; its neighbour was never looked at. Only two of the four were justified, because they solve different problems: a compositional form before placement, and a semantic form after it. The waste was in the other two, and in the absence of any proved relationship between them.

Naming the structure would have found them sooner. The label lists, activation counts, row extents, and column sets were all one fold (Lean's `foldMap`) at different target monoids. The framework's own summary type was their product monoid, and its `combine` had been proved associative and unital, but was never registered as a monoid. The question "what algebraic structure is this?" was already in memory at the time. It did not fire, because nothing in the work matched its trigger.

## Define things in their most principled form

- **Refer to the source that already carries a value.** If a value is already held by another definition in the codebase, refer to that definition rather than pasting the literal again. The definition then says what the value is, and there is no second copy to drift.
- **Tie a value that must match an external source to it with a check.** When a constant must match a deployed implementation or a reference table, keep the literal. Add a machine-checked assertion of the connection next to it: a test, a static assertion, or a checked example. Spell the assertion so that it mirrors the source's own text. If the source stores a constant as a list of limbs, compare with those limbs verbatim, so that a reader can check it by eye. Cite the source with a pinned link ([[feedback_durable_prose]]).
- **Work out the principled option at a design fork.** When the choice is between a cheap local workaround and a principled restructuring, many users prefer the principled side, even at the cost of a wider refactoring. Present the principled option fully worked out, not as an afterthought. Split it into a later unit only when it deserves a review of its own.
