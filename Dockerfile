FROM elixir:1.20.2-otp-29

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential ca-certificates curl git inotify-tools \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get && mix deps.compile

COPY . .
RUN mix assets.setup

EXPOSE 4000

CMD ["sh", "-c", "mix deps.get && mix assets.setup && mix assets.build && mix ecto.create && mix ecto.migrate && exec mix phx.server"]
