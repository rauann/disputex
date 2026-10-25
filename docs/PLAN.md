# Disputex plan

Build the app in `docs/SPEC.md` in four milestones, one PR each, merged in order. The spec is the source of truth. When this plan and the spec disagree, fix this plan.

This is a starting checklist taken from the spec's Milestones section. To get a full pstack plan, run:

```
/poteto-mode Write a multi-phase plan for docs/SPEC.md, one PR per milestone, saved to docs/PLAN.md, replacing this file. Don't implement. Scale verification to a solo project.
```

## How to read this

One box is one unit of work. Check a box only when its evidence exists, such as a test run, a log line, a screenshot, or a SHA. Tests alone are not enough. Each PR also needs a live run of the real app.

## PR 1. Skeleton and data

**Depends on.** None.

- [ ] Phoenix 1.8 app `:disputex` with binary ids.
- [ ] Docker multi-stage release image, `docker-compose.yml` with Postgres and pgvector, `.env.example`, `setup.sh`.
- [ ] `config/runtime.exs` reads secrets from env vars or `*_FILE` Docker secrets, and refuses live Stripe keys unless `ALLOW_LIVE=true`.
- [ ] Migrations and schemas for disputes, the pipeline tables, the fake domain, and `pii_vault`.
- [ ] Deterministic seeds.
- [ ] Signed Stripe webhook through `Stripe.WebhookPlug`, mounted before `Plug.Parsers`.
- [ ] Oban ingest and gather workers, idempotent on the Stripe event id.
- [ ] `Disputex.Privacy.Redactor` with an AES-GCM `pii_vault`, covering emails, US and international phones, and known names.
- [ ] CI runs format, compile with warnings as errors, credo, and tests.

**Verify.**

- [ ] Webhook tests cover a valid signature, a bad signature (400), and a duplicate event (no new rows).
- [ ] StreamData properties show no PII survives redaction and tokens are deterministic.
- [ ] Live run. `docker compose up`, send a signed `charge.dispute.created` with Stripe CLI, and watch the dispute reach `gathering`.

## PR 2. The agent

**Depends on.** PR 1.

- [ ] `Disputex.LLM` behaviour and the req_llm adapter, defaulting to `openrouter:<author>/<model>`, with a Mox mock for tests.
- [ ] Egress guard so only redacted text reaches the LLM.
- [ ] Provider smoke test behind a tag, run only with a real key.
- [ ] The eight LLM tools from the spec.
- [ ] Typed `Decision` schema validated with Ecto changesets.
- [ ] Agent runner with token and cost budgets.
- [ ] Analyze worker and routing gates (confidence plus hard gates).
- [ ] Minimal LiveView review queue.

**Verify.**

- [ ] Runner tests with the mock cover tool calls, a budget cutoff, and an invalid `Decision`.
- [ ] Routing tests cover each hard gate.
- [ ] Live run. A seeded dispute goes through analyze with a real OpenRouter key and shows up in the queue.

## PR 3. Close the loop and measure

**Depends on.** PR 2.

- [ ] Evidence mapper and idempotent submit to Stripe.
- [ ] Handle `charge.dispute.closed`.
- [ ] Embeddings and similar-dispute search with pgvector.
- [ ] OpenTelemetry tracing with token cost per run.
- [ ] 30 eval cases and `mix disputex.eval`.

**Verify.**

- [ ] A retried submit sends evidence once.
- [ ] `mix disputex.eval` prints a results table for at least two models.
- [ ] Live run. A trace shows the full pipeline with cost.

## PR 4. Ship

**Depends on.** PR 3.

- [ ] Run evals and pick the routing threshold.
- [ ] `/setup` checks page.
- [ ] MCP read tools through anubis_mcp.
- [ ] Review UI polish.
- [ ] README with the results table and a demo GIF.
- [ ] Tag a release.

**Verify.**

- [ ] A fresh clone runs with `./setup.sh && docker compose up` and a single key.
- [ ] An MCP client lists and reads disputes.

If time runs short, cut in this order: MCP writes, an LLM judge, a local-model column, the edit-draft UI. The eval table and the end-to-end demo stay.
