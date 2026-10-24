# Disputex

Disputex is a self-hosted Elixir app that will draft responses to Stripe chargeback disputes. You run it yourself, and you bring your own LLM key. Nothing in this repository is a hosted service, and no key is stored anywhere but on your machine.

**Status: milestone 1 of 4.** This milestone is the skeleton: Phoenix, Postgres with pgvector, a mix release, the dispute and booking schemas, deterministic demo data, a signed Stripe webhook, Oban ingest and evidence-gathering jobs, and PII redaction. The agent, LiveView review, evals, and MCP server come later. The design lives in [docs/SPEC.md](docs/SPEC.md).

## Quickstart

You need Docker, and a Stripe **test** key when you want live webhook forwarding. An OpenRouter key is not used yet.

```sh
./setup.sh
docker compose up
```

`setup.sh` copies `.env.example` to `.env` when `.env` is missing and fills `SECRET_KEY_BASE`, `VAULT_KEY`, and `MCP_TOKEN`. It leaves any value you already set. Put `sk_test_...` in `STRIPE_SECRET_KEY` and the Stripe CLI signing secret in `STRIPE_WEBHOOK_SECRET`. Boot refuses `sk_live_` and `rk_live_` unless `ALLOW_LIVE=true`.

The app listens on `http://127.0.0.1:4000`. On an empty database, `DEMO_SEED=true` loads about 200 bookings once, then the release starts. Postgres is `pgvector/pgvector:pg17`, published only on `127.0.0.1:5432`.

Forward test-mode dispute webhooks with the Stripe CLI profile:

```sh
docker compose --profile stripe up
```

Optional profiles `otel` (Jaeger on `127.0.0.1:16686`) and `local` (Ollama) are in the Compose file. They are unused until later milestones.

## Develop without Docker

Elixir 1.20 and OTP 29, plus Postgres with the `vector` extension (the `pgvector/pgvector:pg17` image is enough):

```sh
mix setup
mix phx.server
```

`mix setup` fetches dependencies, creates the dev database, migrates, and seeds. Tests use `mix test` against `disputex_test` (override the connection with `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_HOST`, and `POSTGRES_DB`).

## What this milestone does

A `charge.dispute.*` webhook is verified by `Stripe.WebhookPlug` before the body is parsed. The handler stores the event once and enqueues `IngestDisputeWorker` in the same transaction. That job re-fetches the dispute through the `Disputex.Payments` behaviour, upserts it, links a booking by charge id, and moves a new test-mode dispute to `gathering`. `GatherEvidenceWorker` writes a redacted case file. The `embedding` column stays empty until the LLM layer exists.

## What is not here yet

The LLM client (`req_llm` >= 1.29.0, OpenRouter by default), the agent loop, routing, review UI, evidence submission, evals, OpenTelemetry, and the MCP server. See the milestone list in the spec.

## License

MIT. See [LICENSE](LICENSE).
