import Config

# This file runs in every environment after compilation, including releases.
# Secrets come from the environment or a `*_FILE` Docker secret. Nothing here
# is a default credential.

if System.get_env("PHX_SERVER") do
  config :disputex, DisputexWeb.Endpoint, server: true
end

case Disputex.Config.load(System.get_env()) do
  {:ok, cfg} ->
    config :disputex, :llm,
      provider: cfg.llm_provider,
      api_key: Disputex.Config.llm_api_key(cfg),
      agent_model: cfg.agent_model,
      embedding_model: cfg.embedding_model

    if is_binary(cfg.stripe_secret_key) do
      config :disputex, :stripe_secret_key, cfg.stripe_secret_key
      config :stripity_stripe, api_key: cfg.stripe_secret_key
    end

    if is_binary(cfg.stripe_webhook_secret) do
      config :disputex, :stripe_webhook_secret, cfg.stripe_webhook_secret
    end

    if is_binary(cfg.vault_key) do
      config :disputex, :vault_key, cfg.vault_key
    end

    if is_binary(cfg.mcp_token) do
      config :disputex, :mcp_token, cfg.mcp_token
    end

    if is_binary(cfg.stripe_api_base_url) do
      config :stripity_stripe, api_base_url: cfg.stripe_api_base_url
    end

    if config_env() == :dev do
      config :disputex, DisputexWeb.Endpoint,
        live_reload: [
          web_console_logger: true,
          patterns: [
            ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$"E,
            ~r"priv/gettext/.*\.po$"E,
            ~r"lib/disputex_web/router\.ex$"E,
            ~r"lib/disputex_web/(controllers|live|components)/.*\.(ex|heex)$"E
          ]
        ]
    end

    if config_env() == :prod do
      Disputex.Config.validate_prod!(cfg)

      maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

      config :disputex, Disputex.Repo,
        url: cfg.database_url,
        pool_size: cfg.pool_size,
        socket_options: maybe_ipv6

      config :disputex, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

      config :disputex, DisputexWeb.Endpoint,
        url: [host: cfg.phx_host, port: 443, scheme: "https"],
        http: [ip: {0, 0, 0, 0}, port: cfg.port],
        secret_key_base: cfg.secret_key_base
    end

  {:error, :live_key_refused} ->
    raise "refusing to boot with a live Stripe key; set ALLOW_LIVE=true to override"

  {:error, {:secret_file, name, reason}} ->
    raise "could not read #{name}_FILE (#{inspect(reason)})"

  {:error, :invalid_port} ->
    raise "PORT must be an integer between 1 and 65535"
end
