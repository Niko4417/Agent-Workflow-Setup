# Model cost and effort assessment

Reviewed **2026-10-09**. Scope: all six models in this workflow's standing,
escalation, or manual-only tiers, plus relevant older GPT alternatives. This is
an engineering recommendation based on official documentation and current API
rates. No representative Keiko quality/latency replay was run for this update.
The measured cost-quality Pareto frontier therefore remains unknown.

## Decision

- Replace every Claude Sonnet route with **Opus 5.5**, including the Stop quality
  hook and team templates. Sonnet is excluded by operator policy; exclusion is
  not evidence that it is economically dominated.
- Upgrade `explorer` and `docs` to **Haiku 5.5 / medium**. Adopt it for bounded
  evidence lookup and source-grounded documentation. Broad architectural
  investigation and consequential document decisions still require Opus.
- Retain **GPT-6 Luna / low or medium** for bounded roles and **GPT-6.1 Sol /
  medium or high** for execution/review. Keep Sol / xhigh as targeted escalation.
  Current guidance supports these tiers; there is no task-specific evidence to
  justify reducing every high setting or increasing every role to a flagship.
- Use **Opus 5.5 / high** for the coordinator and architect, as requested by the
  operator; this is a quality preference rather than a measured Pareto improvement.
- Try Opus / high, then / xhigh on a corrected, bounded hard task before Fable /
  high. **Astra remains manual-only**, even when an evaluation suggests benefit.

## Comparable API rates

USD per million tokens, Standard processing, global rates, excluding regional
premiums, tool fees, taxes, retries, and cache population. Each row links to the
provider's model page. Cached input means a cache hit, not a cache write.

| Model | Uncached input | Cache read | Billed output | Higher prompt tier |
| --- | ---: | ---: | ---: | --- |
| [Haiku 5.5](https://platform.claude.com/docs/en/models/haiku-5-5/overview) | $0.10 | $0.01 | $0.50 | Above 100K: $0.50 / $0.05 / $2.50 |
| [GPT-6 Luna](https://developers.openai.com/api/docs/models/gpt-6-luna) | $0.10 | $0.01 | $0.50 | Above 272K: $0.20 / $0.02 / $0.75 |
| [GPT-6.1 Sol](https://developers.openai.com/api/docs/models/gpt-6.1-sol) | $2 | $0.10 | $10 | Above 272K: $4 / $0.20 / $15 |
| [Opus 5.5](https://platform.claude.com/docs/en/models/opus-5-5/overview) | $4 | $0.20 | $20 | No additional long-context tier listed |
| [Fable 5.1](https://platform.claude.com/docs/en/models/fable-5-1/overview) | $10 | $0.25 | $50 | No additional long-context tier listed |
| [GPT-6 Astra](https://developers.openai.com/api/docs/models/gpt-6-astra) | $10 | $1 | $50 | Above 272K: $20 / $2 / $75 |

Prompt thresholds use the whole input, including cached context, not just newly
added tokens. GPT long-context multipliers apply to the whole request. Haiku's
higher tier applies to input, output, and cache prices once its prompt exceeds
100K. Keep lookup bundles bounded; do not split context if doing so loses evidence.

Haiku's five-minute/one-hour cache writes cost $0.125/$0.20 at up to 100K and
$0.625/$1 above it. Opus writes cost $5/$8; Fable writes cost $12.50/$20.
[Claude model pricing](https://platform.claude.com/docs/en/about-claude/pricing)
and the linked model pages establish those rates. Current GPT cache writes cost
1.25× uncached input, including the long-context multiplier. Batch/Flex and
Fast/Ultrafast have different rates; do not mix them into a Standard comparison.
[OpenAI pricing](https://developers.openai.com/api/docs/pricing)

API spend is not a proxy for Claude Code/Codex subscription quota. Model account
access, provider aliases, and runtime effort support must be checked separately.

## Cost examples and crossover

These are arithmetic scenarios, **not model performance measurements**. Assume
an existing cache, identical token counts, and 5K total billed output tokens
(including thinking/reasoning). Cache writes, tools, retries, and the lead's
coordination cost are excluded from these single-request examples.

| Model | 20K new + 80K cached input (100K prompt) | 20K new + 180K cached input (200K prompt) |
| --- | ---: | ---: |
| Haiku 5.5 | $0.0053 | $0.0315 |
| GPT-6 Luna | $0.0053 | $0.0063 |
| GPT-6.1 Sol | $0.0980 | $0.1080 |
| Opus 5.5 | $0.1960 | $0.2160 |
| Fable 5.1 | $0.4700 | $0.4950 |
| GPT-6 Astra | $0.5300 | $0.6300 |

At 100K, Haiku and Luna have equal token prices: choose based on accepted results,
latency, and harness fit. At 200K, Haiku costs **5× Luna** for this mix. That
makes Luna a better price candidate for large lookup context, without proving
that its quality dominates Haiku. Haiku 5.5 also counts roughly 30% more tokens
for the same text than Haiku 4.5, so tokenizer changes must be included in any
migration replay. [Haiku specifications](https://platform.claude.com/docs/en/models/haiku-5-5/overview)

Opus costs **2× Sol** on each token category at short context. Astra is **5× Sol**
on uncached input/output and **10×** on cache reads. At equal success rates, Astra
would need to reduce the weighted token/tool/retry cost by enough to offset its
premium; the 100K example requires less than 18.5% of Sol's example cost-weighted
usage to be cheaper. Actual completion rates and token mixes can change this.
Fable has cheaper cache reads than Astra despite equal input/output rates; this
also does not establish a cross-provider quality ranking.

## Candidate cost-quality frontier by effort

These are task-conditioned candidates to evaluate, not an ordered capability
scale. A setting is Pareto-dominated only when another setting has no higher
measured cost or latency and no lower accepted quality, with at least one strict
improvement. Effort labels do not represent equal compute across models and do
not change the listed token rate: they change usage, latency, and sometimes retries.

| Model | Starting effort | Increase effort when | Assessment |
| --- | --- | --- | --- |
| Haiku 5.5 | medium for explorer/docs; low only for short extraction/classification | high for longer bounded tasks or strict instruction following | Cheap Claude worker candidate; compare high/xhigh with Opus medium before adopting |
| GPT-6 Luna | low for lookup; medium for docs/mechanical triage | high/xhigh for harder bounded work with a clear verifier | Cheap GPT worker candidate; broad judgment still escalates to Sol |
| GPT-6.1 Sol | medium for scoped execution; high for complex implementation/review and the lead | xhigh for a specific unresolved problem after fixing context | Default complex-work candidate; keep low as an eval candidate for genuinely tiny edits |
| Opus 5.5 | medium for scoped execution/review; high for coordinator/architect/heavy coding/security/performance | high, then xhigh for unresolved difficulty | Required replacement for former Sonnet roles; higher quality must earn higher usage |
| Fable 5.1 | high for exceptional escalation | xhigh/max only with measured headroom | Premium long-horizon candidate after higher-effort Opus falls short |
| GPT-6 Astra | high only when explicitly requested under this workflow | xhigh/max only with measured headroom and authorization | Premium manual candidate; never an automatic fallback |

[OpenAI model selection](https://developers.openai.com/api/docs/guides/model-selection)
recommends comparing models/settings on the same inputs.
[Claude effort guidance](https://platform.claude.com/docs/en/build-with-claude/effort)
supports medium defaults for Opus/Haiku and warns that Haiku low can skip checks
in long prompts. Both Claude models support low/medium/high/xhigh/max. Sol 6.1
and Astra support low through max but not none/minimal; Luna also supports none.
Use the provider/model's supported settings, not app-only effort labels.

Haiku is also worth evaluating for summaries, compaction, routing labels, and
mechanical scan-result extraction. Treat those outputs as advisory and verify
sources; no new standing role is added. Keep authoritative acceptance checks,
security interpretation, accessibility judgments, PR decisions, and merge-driving
orchestration on Opus/Sol. Availability failures must be reported, not hidden by
silently restoring an old Haiku or Sonnet route.

## Older GPT alternatives

Prices below are Standard input/cache read/output per million tokens, within the
short-context tier. The linked pages establish current rates.

| Alternative | Rates | Routing decision |
| --- | --- | --- |
| [GPT-6 Sol](https://developers.openai.com/api/docs/models/gpt-6-sol) | $2 / $0.20 / $10 | Same uncached/output price as Sol 6.1 and higher cache reads; retain only for a measured compatibility/quality benefit |
| [GPT-5.6 Sol](https://developers.openai.com/api/docs/models/gpt-5.6-sol) | $4 / $0.40 / $20 | Higher rates than Sol 6.1; no current economic reason for a standing route without a task-specific quality gain |
| [GPT-5.6 Terra](https://developers.openai.com/api/docs/models/gpt-5.6-terra) | $2 / $0.20 / $12 | No token-price advantage over Sol 6.1; benchmark only for a specific regression or capability need |
| [GPT-5.6 Luna](https://developers.openai.com/api/docs/models/gpt-5.6-luna) | $0.20 / $0.02 / $1.20 | Higher rates than GPT-6 Luna; no default worker route without measured benefit |

These are price comparisons, not proven quality dominance. Specialized audio,
image, cyber, and science models are outside this text/code role map. A full
historical catalog would not establish a better routing frontier.

## How to establish the measured frontier

Replay 20–50 representative repository tasks, including seeded review defects,
using the same harness/tool versions, scope, prompts, acceptance criteria, and
budgets. Compare neighboring settings rather than running an expensive full
model-by-effort grid. Include short and long prompt cohorts. Repeat close or
variable outcomes before changing defaults.

Record model/effort actually used, prompt size, uncached input, cache reads/writes,
billed output including reasoning, tool fees, retries/escalations, elapsed time,
accepted completion, missed defects, and false positives. Include the lead and
all workers in total cost. For each cohort compute:

```text
attempt_cost = (uncached_input * input_rate + cache_reads * read_rate
              + cache_writes * write_rate + billed_output * output_rate) / 1e6
              + tool_fees
cost_per_accepted_task = sum(all_attempt_and_coordination_costs) / accepted_tasks
```

Use the correct cache-write TTL rate and long-context tier on each request. GPT
output usage already includes reasoning: do not add reasoning tokens twice.
[OpenAI reasoning usage](https://developers.openai.com/api/docs/guides/reasoning)
Partition input into mutually exclusive uncached, cache-read, and cache-write
tokens according to provider billing; do not charge a cache write again as ordinary
uncached input. Include the cost of populating a cache in a full task replay.
If no task is accepted, cost per accepted task is undefined; the candidate fails
the quality gate. Filter by required quality/defect-recall first, then compare
cost and latency among qualifying settings. This prevents a cheap worker's
missed checks or expensive retries from masquerading as a Pareto improvement.
