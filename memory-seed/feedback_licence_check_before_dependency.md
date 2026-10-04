---
name: Check a dependency's own licence before building on it — at the file level, against the destination's licence and contribution clause
description: Before taking a dependency of any kind, read the artifact's own licence, in its header, its LICENSE file, or its manifest, not a containing repository's claim about it. Dependencies include packages, vendored files, ports, translations, and generated derivatives of someone's code, and copied snippets that do not fall under fair use. Check that licence against the destination's licence and its contribution clause. A derivative keeps the source's licence. Unless the licences are the same or the source is more permissive, raise it before starting work. Licence compatibility is complicated, and even a compatible combination can be an unwelcome hurdle. Record the check where the dependency is introduced.
type: feedback
---

Check the licence of anything that the project is about to depend on, before the work that builds on it starts. Taking a dependency includes:

- Adding a package or crate.
- Vendoring a file from another repository.
- Transcribing, porting, translating, or generating code from someone else's file. Examples are assembly transcribed into a proof assistant, a port to another language, and generated code that reproduces a source line by line. These are derivative works of the source, and so are comments or test files that quote its lines. Outputs of running the code (such as test vectors), or an independently written model are not derivatives.
- Copying a snippet from an answer, a paper, or a gist, where the copying does not fall under fair use.

**Read the artifact's own licence:** the file's header, the upstream repository's `LICENSE`, the manifest's licence field, or the registry's entry. A statement in an intermediate repository's README that "all code here is dual-licensed" describes that repository's own contributions. A file that it vendored from a single-licensed upstream keeps the upstream's licence, and usually still carries the upstream's header saying so. Two hops of vendoring do not change a licence.

For a dependency tree, a tool can read the manifests: for Rust, `cargo license`, or `cargo deny check licenses` where a project configures it. Use `cargo license --avoid-dev-deps` for what ships, and `--all-features` to include optional dependencies. Such tools cover packages, not a vendored or transcribed file, whose header is the only source. A feature-gated file still ships in the package to everyone who downloads it; only an optional dependency is fetched just by those who enable the feature.

**Compare it with the destination:** its licence, and its contribution clause (of the "unless you explicitly state otherwise, contributions are licensed as above" kind).

- If the licences are the same, or the source is more permissive than the destination, the dependency is fine. Keep the source's attribution and notices.
- A single-licensed source going into a dual-licensed destination works only if the source's licence stays within the source's own files, so that the rest of the project keeps both options. Apache-2.0 applies file by file, so Apache-2.0-only code can live in separate files inside a project licensed as "MIT or Apache-2.0". Each file then carries its own notice, and the top-level licence statement lists them. That does not carry over to a source under the GPL or LGPL, whose terms reach the combined work. For example, an LGPL-only source would stop a project licensed as "LGPL or MIT" from being offered under MIT.
- Copyleft (GPL, AGPL, or LGPL linked statically) going into a permissive project: stop, and raise it.

Licence compatibility is complicated, and even a combination that is technically compatible can be an unwelcome hurdle for the project's users and maintainers. So outside the first case, raise the question before starting work, and let the user decide; the maintainers may need to decide whether to admit such a dependency at all. An exception to the contribution clause has to be stated explicitly.

**Record the outcome where the dependency is introduced,** such as in a comment in the manifest, or in a README beside vendored files that names each file's origin, revision, and licence. A generated derivative's header states the source's copyright and licence, not the destination's default header.

In one case, a vendored file's single-licence header was read and noted at the time, yet the transcription generated from it was published under the destination's dual-licence header. Days of work later, the branch had to be withdrawn until the licensing was settled. The check would have taken one look at one header, at the start.
