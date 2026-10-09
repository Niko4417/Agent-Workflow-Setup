# Model routing

Audience: the lead orchestrator and maintainers of this workflow. Reviewed on
2026-10-09. `.agents/roles.yaml` owns standing models and effort; the harness role
files implement those settings. `python scripts/check-routing.py` checks them
against the README, Claude table, lead defaults, and final Claude quality hook.

## Standing policy

- Lead: GPT-6.1 Sol / high, or Claude Opus 5.5 / medium.
- Bounded lookup and straightforward docs: GPT-6 Luna (low/medium by role) or
  Claude Haiku 5.5 / medium. Haiku 5.5 supports effort; use low only for a short,
  explicit extraction/classification task, not a long agent investigation.
  A mechanical security scan can use Luna, but
  interpretation of auth, permissions, or exploitability belongs to the specialist.
- Scoped implementation and browser work: GPT-6.1 Sol or Claude Opus 5.5 / medium.
- Complex features, architecture, and review use the stronger standing settings
  in the role table. Accessibility auditing, authoritative verification, and
  security interpretation use Sol/Opus. Every former Sonnet route uses Opus;
  the final Claude quality hook also uses Opus.
- Codex escalation: GPT-6.1 Sol / xhigh for a specific problem that remains
  unresolved after correcting context and scope. GPT-6 Astra / high is manual-only:
  the operator must explicitly request it; never select it automatically.
- Claude escalation: Haiku 5.5 / medium → Opus 5.5 / medium → Opus 5.5 / high
  → Opus 5.5 / xhigh for a specific unresolved difficulty. Exceptional escalation
  remains Fable 5.1 / high after higher-effort Opus falls short.

The [cost/effort assessment](model-cost-effort.md) records current prices,
long-context thresholds, Haiku adoption boundaries, and candidate Pareto settings
for every active model and relevant older GPT alternatives. Standing GPT routes
remain unchanged after review; no Keiko task replay proves a cheaper setting
meets the same quality bar. These are provisional defaults, not a measured frontier.

Claude IDs are pinned; provider aliases and environment overrides can resolve to
different versions. Check account/provider support before spawning. Availability
fallbacks must be visible: never silently substitute a cheaper model for a
security audit. API prices do not measure subscription quota consumption.

## Risk and escalation

1. Route explicit, bounded work to its standing role. Keep one orchestrator and
   use the smallest useful team. Parallelize independent research/review or
   disjoint write scopes, within the runtime limit; keep sequential work sequential.
2. Broad exploration, architectural documentation, auth/permissions, migrations,
   concurrency, and difficult accessibility judgments require Sol/Opus or the
   appropriate specialist before implementation proceeds.
3. After a failure, diagnose missing context and task size first. Narrow or correct
   the request; then raise effort or model for a specific unresolved difficulty.
   On Codex, use Luna → Sol 6.1 / medium → Sol 6.1 / high → Sol 6.1 / xhigh,
   starting at the role's standing setting rather than running every step.
   Failure, high risk, or uncertainty never authorizes an automatic Astra spawn.
   A measured benefit can justify recommending Astra, but only an explicit
   operator request authorizes using it. Existing repair-attempt and human-review
   gates remain binding.
4. Give reviewers acceptance criteria, the diff, relevant code, and test results.
   Require reproducible findings independent of the implementer's summary.
5. Capture requested and actual model, effort, role, sandbox, escalation reason,
   elapsed time, retry count, and verification outcome in delivery evidence.
   Include billed uncached input, cache reads/writes, output including reasoning,
   and tool fees when comparing costs; record subscription usage separately.
   Keep raw transcripts local; exclude credentials, secrets, and private source.

## Runtime validation

An accepted model name in a catalog is not a successful spawn. A child describing
its own model is not runtime evidence. Validate a completed bounded task and the
child's recorded `turn_context` model/effort. For named roles, also check the
recorded `agent_role` and sandbox. Test a baseline role without model overrides;
test escalation separately with an explicit override. Do not use full-history
forks for tiered workers, and never omit a required role to make a spawn pass.

Some model-visible tool interfaces expose model/effort overrides but omit
`agent_type`. Such an interface can validate explicit overrides only. Use a
role-capable local Codex interface to test named-role inheritance and report
this distinction. Claude configuration checks do not prove Claude runtime access:
run the equivalent smoke test with an authenticated Claude Code installation.

### Observed smoke tests (2026-10-04)

On Windows with Codex CLI 0.160.0, completed tasks and local runtime records confirmed:

| Test | Recorded result |
|---|---|
| Explicit independent child overrides | Luna / low, Sol 6.1 / medium, Astra / high |
| Named roles without model or effort overrides | explorer: Luna / low; implementor: Sol 6.1 / medium; security-auditor: Sol 6.1 / high |
| Automatic project role discovery | explorer role recorded with Luna / low |
| Read-only role from a full-access parent | Child recorded full access despite the role's `sandbox_mode = "read-only"` |
| Claude runtime | Untested: Claude Code was not installed on this machine |

These are spawn and configuration checks, not coding-quality benchmarks. Role
model/effort inheritance passed; role sandbox enforcement did not. Keep the
read-only settings in role files, but use a read-only parent for those workers
until the installed runtime demonstrably honors narrower child permissions.
Do not claim tool-level enforcement from the role name or written instructions.

Enable V2 explicitly and expose role metadata/model overrides as in
`codex/config.toml`. Project configuration must actually load (trusted project,
normal config loading); a run that ignores configuration is not a discovery test.

Before publishing, run:

```text
python scripts/check-routing.py
python tests/test-routing.py
```

Replay 20-50 representative Keiko tasks, including known review defects, before
treating these defaults as optimized. Keep tool versions, prompts, and budgets
consistent; compare completion, missed defects, false positives, retries, time,
and total usage. Small samples identify large regressions, not small superiority.

## Research basis

These are initial engineering choices, not a proven Keiko model ranking.

Sol 6.1 is the default and autonomous escalation model because official guidance
describes near-Astra performance at substantially lower standard API rates. No
representative Keiko evaluation currently establishes an Astra benefit worth its
premium. See the README's dated cost comparison. The Astra availability smoke
test is not evidence of a quality advantage or authorization for routine use.

- [OpenAI GPT-6 guidance](https://developers.openai.com/api/docs/guides/latest-model)
  positions Sol 6.1 for balanced complex coding and Luna for focused workloads.
- [Claude model overview](https://platform.claude.com/docs/en/models/overview)
  and [effort guidance](https://platform.claude.com/docs/en/build-with-claude/effort)
  document model IDs and effort support. Opus 5.5 and Haiku 5.5 default to medium.
  Effort scales differ across models; equal labels are not equal compute budgets.
- [Haiku 5.5 overview](https://platform.claude.com/docs/en/models/haiku-5-5/overview)
  supports bounded extraction/routing/subagent work and documents the 100K prompt
  price threshold. Low effort can skip checks in long agent prompts; start at medium.
- [Opus 5.5 overview](https://platform.claude.com/docs/en/models/opus-5-5/overview)
  positions it for long-running coding and knowledge work. Vendor scores do not
  establish a same-harness winner against Sol 6.1 for Keiko.
- [RouteLLM](https://arxiv.org/abs/2406.18665) supports quality/cost-aware selection,
  but its experiments are not Keiko coding-agent evaluations. Start with rules.
- [Scaling Agent Systems](https://arxiv.org/abs/2512.08296) finds that coordination
  helps some parallel tasks and harms some sequential tasks under tested budgets.
- [SWE-Bench Pro Verified](https://arxiv.org/abs/2609.08149) documents benchmark
  leakage and task-quality problems; use repository-owned verification.
- [Agent eval guidance](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)
  recommends starting with a small representative suite and iterating.
