# Target repository boundary

## Purpose

Agent Workflow Setup is development infrastructure. It governs how coding agents
plan, implement, verify, and deliver changes to a target repository. It is not part
of the Keiko product, and its development-agent model is not the product runtime's
agent model.

This boundary keeps a target repository independently buildable, reviewable, and
governed while allowing an operator to use richer local orchestration.

## Ownership

| Target repository owns                                    | Workflow repository owns                    |
| --------------------------------------------------------- | ------------------------------------------- |
| Product source and architecture                           | Reusable orchestration skills and playbooks |
| `CONTEXT.md` product language and boundaries              | Development-agent roles and model routing   |
| Repository-specific `AGENTS.md` / `CLAUDE.md` contracts     | Harness-specific agent configuration        |
| ADRs and product security invariants                      | Optional local hooks and helper commands  |
| Issue and pull request templates                          | Cross-repository workflow automation        |
| CI, deterministic verification, and release gates         | Curated operator or team workflow memory    |
| Product Agentic Coding lifecycle and runtime abstractions | Development delivery lifecycle              |

The target's CI and repository controls remain authoritative. Local workflow gates
provide earlier feedback but cannot replace protected branches, required checks,
or review requirements that the target actually requires.

Target `AGENTS.md`, scoped instructions, ADRs, and explicit user choices override
generic workflow defaults. For Keiko, ADR-0135 authorizes accepted, checked
`dev` delivery through native auto-merge; ADR-0145 retires `agent:pre-pr`.
An explicit final epic review hold remains in force for that run and adds no
per-child approval. Otherwise retain the generic final human-review default
where the target and user have not authorized another path.

Server-side branch controls are target-owned. Optional stronger epic protection
must not become a workflow-only blocker or a new administrative prerequisite;
required quality evidence and review settlement still apply.

## Target document roles

These documents are complementary and must not silently replace one another:

- the product specification defines what the product must achieve and why;
- `CONTEXT.md` defines canonical domain language and resolved product boundaries;
- `AGENTS.md` defines how humans and coding agents must work in that repository;
- ADRs preserve durable architecture decisions and their rationale; and
- skills and runbooks define how to execute a development workflow.

## Existing Keiko integration

The current installer and skills were built for Existing Keiko. Web integration
uses live symlinks for `.agents`, `.codex`, `.claude`, and related optional harness
files. Both Web and Native retain their own root `AGENTS.md` and `CLAUDE.md`:
installation and worktree linking preserve existing regular files and symlinks,
including dangling links. They never create authority documents from workflow
defaults or add Git excludes for those target-owned documents. Missing or
unreadable documents produce a warning; restore any authority document the target
requires before agent work. A missing optional harness document adds no new requirement. Existing local Git excludes are not rewritten, so an installation migrated
from the old Web overlay should also review and remove its obsolete `/AGENTS.md`
and `/CLAUDE.md` excludes. A prior overlay's target-owned backup must be restored
by the operator rather than guessed by the installer.

This optional harness integration must not be assumed to be a generic integration
contract for another product repository.

Memories, gates, roles, paths, and product assumptions accumulated for Existing
Keiko require an explicit assessment before use with another target.

## Keiko Native integration

Keiko Native is a greenfield product repository with its own product context,
ADRs, contribution contract, templates, quality control plane, and Agentic Coding
domain model. This repository must not overwrite or become a mandatory build-time
or runtime dependency of those assets.

The [Keiko Native profile](../profiles/keiko-native.md) and its integration must:

- augment rather than replace the Native repository's `AGENTS.md` and controls;
- be optional so a contributor can build and verify Native without this private
  repository;
- be versioned and referenced by an immutable release or commit, not a mutable
  checkout;
- import no Existing Keiko memory or product assumption without case-by-case
  review;
- leave Native issue templates, pull request templates, CI, and quality gates in
  the Native repository; and
- keep development-agent roles separate from the roles, authority, lifecycle, and
  runtime abstractions implemented by the Native product.

The installer detects Native and, as with Web, preserves its root `AGENTS.md` /
`CLAUDE.md` while linking optional harness files. It does not enforce immutable
version pinning: install Native from a separate checkout at the chosen commit and disable automatic
updates there. Do not treat a mutable live checkout as a pinned integration.
See [local editing](local-editing.md) for the supported pinning procedure.

## Private and shared use

This repository may remain private personal tooling while one operator owns its
use. A target repository must not depend on inaccessible tooling for its normal
build, verification, review, or release process.

If the workflow becomes required for multiple contributors, publish a governed
version to an access-controlled team location, document onboarding and supported
targets, and pin each target integration to a compatible version.

## Referencing this workflow

A target repository may link to a compatible workflow release as an optional
developer accelerator. The reference should identify the profile and immutable
version and must not transfer product authority or source-of-truth status to this
repository.
