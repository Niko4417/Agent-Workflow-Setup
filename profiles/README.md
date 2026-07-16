# Product profiles

A **product profile** lets the shared workflow (skills, gates, playbooks) run
against different target repositories without copying any target's normative
policy into this repository. A profile is **pointers, not policy**: it names
_where_ the target's live contracts live and _which mode_ each workflow step runs
in. The normative text stays in the target repository and remains its authority.

This mechanism realizes the doctrine in
[`docs/target-repository-boundary.md`](../docs/target-repository-boundary.md):
the target repository owns product context, `AGENTS.md`, `CONTEXT.md`, ADRs,
templates, CI, and gates; this repository owns reusable orchestration. A profile
**augments** a target's controls and never replaces them.

## Load-exactly-one invariant

A session selects **exactly one** profile and loads **only that profile file**.
Never load two profiles in one session. In a Keiko Native checkout the session
reads `keiko-native.md` and never sees `keiko-web.md`, and vice versa. This keeps
each session's context free of the other product's rules.

## Selection (skill Step 0)

Every `keiko-*` skill begins by selecting the profile against the target
checkout root, then states the result on its first output line
(e.g. `Profile: keiko-native (detected)`).

| Order | Rule                                                                                                                  |
| ----- | --------------------------------------------------------------------------------------------------------------------- |
| 1     | **Explicit override wins.** If the operator names a profile, use it.                                                  |
| 2     | **Keiko Native** — all of `CONTEXT.md`, `docs/planning/decision-addendum.md`, and `quality/project.json` are present. |
| 3     | **Keiko Web** — `docs/design-system/` is present and the Native markers are absent.                                   |
| 4     | **Ambiguous / none** — **stop and ask** the operator which profile applies. Never assume a default.                   |

Rule 4 is what prevents Native behavior from becoming an accidental global
default: absent clear markers, an **interactive skill** refuses to guess and asks.

**Non-interactive callers** (the gate scripts and `install.sh`, via
`scripts/profile-detect.sh`) cannot prompt, so on ambiguity they fall back to the
**safe `keiko-web` default** and **never auto-select `keiko-native`** — Native is
chosen only when all its markers are present (or `KEIKO_PROFILE` is set explicitly).
So "never guess Native" holds everywhere; only the ambiguity _fallback_ differs: a
skill asks, a script defaults to web.

## Profile schema (what each profile provides)

Each profile answers the same fields, as pointers to the target's own docs:

- **Authority docs** — the target contracts a planning/implementation agent reads.
- **Definition of Ready** — heuristic vs machine-validated; where readiness is granted.
- **Verify command(s)** — the deterministic local green bar.
- **Templates** — the target's issue/PR templates (owned by the target).
- **Branch & merge model** — base/target/source branches; `dev` and epic merge authority.
- **Evidence model** — how user-facing and release-acceptance evidence is produced.
- **Platforms** — the supported target matrix and explicit deferrals.
- **Labels** — the target's issue-label taxonomy.
- **Exclusions** — hard prohibitions (e.g. private-source handling).

## A profile must never

- Duplicate a target's normative product policy (link/read it instead).
- Store, copy, log, or request a target's private source material.
- Assume server-side controls (labels, branch protection, required checks) are
  active before the target has activated them.
