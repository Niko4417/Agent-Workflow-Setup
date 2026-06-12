# Agent Operating Rules

## Keiko Product Context

Keiko is a standalone enterprise developer-assist coding agent for regulated banking and insurance engineering
workflows. It is not a demo, proof of concept, or internal prototype. The product helps developers work safely in
existing repositories by inspecting bounded context, generating reviewable unit tests, investigating bugs, proposing
small patches, running verification, and producing traceable evidence for human review.

The system is designed to start as a TypeScript/npm-delivered coding-agent foundation and remain model-agnostic so
customer-provided models can be upgraded without rebuilding the product architecture. All generated output must remain
explainable, evidence-backed, developer-controlled, and suitable for regulated delivery environments.

## Templates

- Use the current GitHub issue templates in `.github/ISSUE_TEMPLATE/` when creating or updating issues.
- Use the current pull request template in `.github/pull_request_template.md` when opening or updating pull requests.
- Do not create free-form issues or pull requests by copying older examples unless the result is checked against the
  current template.
- Keep acceptance criteria, expected verification, review settlement, and closure evidence formally updated in GitHub.

## Delivery standard

- Build production-ready, state-of-the-art solutions.
- Keep implementations simple, maintainable, and focused on the issue scope.
- Be creative and innovative where it improves product quality, but avoid unnecessary special cases, speculative
  abstractions, and process overhead.
- Preserve existing architecture boundaries, quality gates, security posture, evidence semantics, and deterministic
  verification.

## Language and artifacts

- Write code comments, configuration, documentation, issues, pull requests, and GitHub comments in professional English.
- Do not commit local runtime state, secrets, customer data, private logs, generated caches, or tool-specific memory.
