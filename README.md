# Disputex

Self-hosted AI agent that fights Stripe chargebacks, built in Elixir

Phoenix 1.8 with LiveView, Ecto, PostgreSQL 18 with pgvector, Tailwind CSS, and esbuild.

## Start with Docker

Install Docker with Docker Compose and Make, then run:

```sh
make start
```

Open [localhost:4000](http://localhost:4000). Compose streams logs from both services
in your terminal. Press `Ctrl+C` to stop them.
The first build downloads dependencies and asset tools.
Startup waits for PostgreSQL, creates the development database, and runs migrations.

Source files mount into the container for code reloading. Dependencies and compiled
artifacts use Docker volumes so Linux and host builds stay separate.
PostgreSQL runs on the internal Docker network and stores data in a persistent volume.
The database uses `pgvector/pgvector:pg18-trixie`. An Ecto migration enables the `vector`
extension in the development and test databases.

Use `make logs` to follow logs from all services in another terminal.

## Run checks

```sh
make check
```

Both `make test` and `make check` run the Elixir tests in `app` against the separate
`disputex_test` database.

`make check` also validates the Compose configuration, compiles with warnings as
errors, and formats the code. Both commands start PostgreSQL when needed.

## Stop

```sh
make stop
```

Database data persists when the containers stop.
