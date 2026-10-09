# Native planning

Load only when `keiko-native` is selected. The target's current schema and
authority documents govern; this checklist is a reading guide.

When the profile is `keiko-native`, the readiness bar is a **machine validator**
(`quality/issue-contract.mjs` via the target's `issue-readiness` workflow), so the
grill is driven by the contract, not a free decision tree:

- **Spine = the machine schema.** Walk the exact required sections for the issue's
  `type:*` (epic / task / decision / defect) as the checklist; each must reach a
  resolved, **placeholder-free** state, with a `Planning contract` version. Read the
  authoritative section list from `quality/issue-contract.mjs` in the target repo —
  do not restate it.
- **Answers = the authority docs.** Restate requirements from
  **`docs/planning/agent-planning-baseline.md`** (the repository-owned Fachkonzept
  projection — global requirements + the affected capability packets) and resolve
  every `inspect` question from the docs the profile names (`decision-addendum.md`,
  `code-quality-standard.md`, `CONTEXT.md`, accepted ADRs, Parity Ledger) **before**
  asking the user. Native raises the `inspect : ask user` ratio sharply — most
  technical unknowns are already decided by a doc.
- **Capability selection.** Every epic identifies its **Parity Ledger row** _or_ an
  **approved net-new capability** — development continues past parity, so net-new and
  mandatory-delta epics are first-class, not out of scope. Bind the outcome to one or
  more **acceptance journeys** and flag unresolved **decision gates** before any
  technology/architecture is assumed.
- **`grill-me` = residual only.** Use its interview technique solely for the genuine
  product / UX / policy / risk / scope / rollout decisions the docs cannot answer.
- **Restate, never expose the source.** The Planning Contract must restate every
  relevant requirement so an implementer needs no source access. **Never store,
  quote, log, or request the private Fachkonzept** or its location; a missing
  requirement is resolved with the product owner or the authorized planner, not by
  reaching for the source.
- **Native semantics** the grill must settle (from the addendum): greenfield rewrite
  (no shared runtime/source dep on Existing Keiko; every reuse candidate gets a
  recorded Reuse Assessment), Codex-App-Server runtime behind a governed adapter, no
  OpenCode work, platforms **Windows + macOS only (Linux deferred)**, local inference
  deferred.
- **Desktop journey (user-facing epics).** Keiko Native is a **desktop app**, so pin
  the desktop-specific acceptance rows the profile names — install/packaging, code
  signing + notarization (per platform, authoritative runner), auto-update/upgrade
  flow, first-run + OS permissions, offline/local-first behavior, crash/recovery, and
  the Win+macOS matrix cadence. These are where a desktop app fails and a web app
  never would; read the target's current host/runner ADRs and accepted plan rather than
  assuming a choice from an older planning baseline. See `profiles/keiko-native.md` → _Desktop
  release-acceptance dimensions_.

