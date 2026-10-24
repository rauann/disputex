# Multi-stage mix release. Versions verified on Hex and Docker Hub on 24 Oct 2026.
ARG ELIXIR_VERSION=1.20.4
ARG OTP_VERSION=29.1.2
ARG DEBIAN_VERSION=trixie-20261020-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS build

RUN apt-get update && apt-get install -y build-essential git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=prod

COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mkdir config

COPY config/config.exs config/prod.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets
COPY rel rel

# Colocated CSS and JS land in _build during compile. Tailwind and esbuild
# import them, so compile has to finish before assets.deploy.
RUN mix compile
RUN mix assets.deploy
COPY config/runtime.exs config/
RUN mix release

FROM ${RUNNER_IMAGE}

RUN apt-get update && apt-get install -y libstdc++6 openssl libncurses6 libsctp1 locales ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    MIX_ENV=prod

WORKDIR /app

RUN useradd --system --uid 1000 --home /app --shell /usr/sbin/nologin disputex

COPY --from=build --chown=disputex:disputex /app/_build/prod/rel/disputex ./

USER disputex

EXPOSE 4000

HEALTHCHECK --interval=15s --timeout=5s --start-period=60s --retries=5 \
  CMD ["/app/bin/disputex", "rpc", "Disputex.Health.ok?()"]

CMD ["/app/bin/start"]
