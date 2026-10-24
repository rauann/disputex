defmodule Disputex.Config do
  @moduledoc """
  Runtime configuration loaded from an environment map.

  A `NAME_FILE` entry (Docker secrets) wins over `NAME`. Live Stripe keys
  (`sk_live_` and `rk_live_`) are refused unless `ALLOW_LIVE=true`.
  """

  @secret_names ~w(
    SECRET_KEY_BASE
    DATABASE_URL
    STRIPE_SECRET_KEY
    STRIPE_WEBHOOK_SECRET
    VAULT_KEY
    MCP_TOKEN
    OPENROUTER_API_KEY
    ANTHROPIC_API_KEY
    OPENAI_API_KEY
  )

  @derive {Inspect,
           except: [
             :secret_key_base,
             :database_url,
             :stripe_secret_key,
             :stripe_webhook_secret,
             :vault_key,
             :mcp_token,
             :openrouter_api_key,
             :anthropic_api_key,
             :openai_api_key
           ]}
  defstruct [
    :secret_key_base,
    :database_url,
    :stripe_secret_key,
    :stripe_webhook_secret,
    :vault_key,
    :mcp_token,
    :openrouter_api_key,
    :anthropic_api_key,
    :openai_api_key,
    :llm_provider,
    :agent_model,
    :embedding_model,
    :phx_host,
    :port,
    :pool_size,
    :demo_seed,
    :allow_live,
    :stripe_api_base_url
  ]

  @type t :: %__MODULE__{}

  @doc """
  Loads configuration from `env`, a map of string keys (as `System.get_env/0` returns).
  """
  @spec load(map()) :: {:ok, t()} | {:error, term()}
  def load(env) when is_map(env) do
    with {:ok, secrets} <- read_secrets(env),
         {:ok, stripe_key} <- reject_live_key(secrets.stripe_secret_key, env),
         {:ok, port} <- parse_port(env),
         {:ok, pool_size} <- parse_pool_size(env) do
      provider = env_string(env, "LLM_PROVIDER", "openrouter")

      {:ok,
       %__MODULE__{
         secret_key_base: secrets.secret_key_base,
         database_url: secrets.database_url,
         stripe_secret_key: stripe_key,
         stripe_webhook_secret: secrets.stripe_webhook_secret,
         vault_key: secrets.vault_key,
         mcp_token: secrets.mcp_token,
         openrouter_api_key: secrets.openrouter_api_key,
         anthropic_api_key: secrets.anthropic_api_key,
         openai_api_key: secrets.openai_api_key,
         llm_provider: provider,
         agent_model: env_string(env, "AGENT_MODEL", "openrouter:author/model"),
         embedding_model: env_string(env, "EMBEDDING_MODEL", "openrouter:author/embedding-model"),
         phx_host: env_string(env, "PHX_HOST", "localhost"),
         port: port,
         pool_size: pool_size,
         demo_seed: Map.get(env, "DEMO_SEED") == "true",
         allow_live: Map.get(env, "ALLOW_LIVE") == "true",
         stripe_api_base_url: blank_to_nil(Map.get(env, "STRIPE_API_BASE_URL"))
       }}
    end
  end

  @doc "The API key for the configured LLM provider. Ollama has none."
  @spec llm_api_key(t()) :: String.t() | nil
  def llm_api_key(%__MODULE__{llm_provider: "anthropic"} = cfg), do: cfg.anthropic_api_key
  def llm_api_key(%__MODULE__{llm_provider: "openai"} = cfg), do: cfg.openai_api_key
  def llm_api_key(%__MODULE__{llm_provider: "ollama"}), do: nil
  def llm_api_key(%__MODULE__{} = cfg), do: cfg.openrouter_api_key

  @doc "Raises unless production has the secrets milestone 1 needs to boot."
  @spec validate_prod!(t()) :: :ok
  def validate_prod!(%__MODULE__{} = cfg) do
    missing =
      [
        {"DATABASE_URL", cfg.database_url},
        {"SECRET_KEY_BASE", cfg.secret_key_base},
        {"VAULT_KEY", cfg.vault_key},
        {"STRIPE_SECRET_KEY", cfg.stripe_secret_key},
        {"STRIPE_WEBHOOK_SECRET", cfg.stripe_webhook_secret}
      ]
      |> Enum.filter(fn {_name, value} -> not is_binary(value) or value == "" end)
      |> Enum.map(&elem(&1, 0))

    if missing != [] do
      raise "missing required environment: #{Enum.join(missing, ", ")}"
    end

    if byte_size(cfg.secret_key_base) < 64 do
      raise "SECRET_KEY_BASE must be at least 64 bytes"
    end

    unless vault_key?(cfg.vault_key) do
      raise "VAULT_KEY must be base64-encoded 32 bytes"
    end

    :ok
  end

  @doc "True when `encoded` is base64 for exactly 32 bytes."
  @spec vault_key?(String.t() | nil) :: boolean()
  def vault_key?(encoded) when is_binary(encoded) do
    case Base.decode64(encoded) do
      {:ok, <<_::binary-size(32)>>} -> true
      _ -> false
    end
  end

  def vault_key?(_), do: false

  defp read_secrets(env) do
    Enum.reduce_while(@secret_names, {:ok, %{}}, fn name, {:ok, acc} ->
      case read_secret(env, name) do
        {:ok, value} -> {:cont, {:ok, Map.put(acc, secret_key(name), value)}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp secret_key("SECRET_KEY_BASE"), do: :secret_key_base
  defp secret_key("DATABASE_URL"), do: :database_url
  defp secret_key("STRIPE_SECRET_KEY"), do: :stripe_secret_key
  defp secret_key("STRIPE_WEBHOOK_SECRET"), do: :stripe_webhook_secret
  defp secret_key("VAULT_KEY"), do: :vault_key
  defp secret_key("MCP_TOKEN"), do: :mcp_token
  defp secret_key("OPENROUTER_API_KEY"), do: :openrouter_api_key
  defp secret_key("ANTHROPIC_API_KEY"), do: :anthropic_api_key
  defp secret_key("OPENAI_API_KEY"), do: :openai_api_key

  defp read_secret(env, name) do
    case blank_to_nil(Map.get(env, name <> "_FILE")) do
      nil ->
        {:ok, blank_to_nil(Map.get(env, name))}

      path ->
        case File.read(path) do
          {:ok, contents} -> {:ok, blank_to_nil(String.trim(contents))}
          {:error, reason} -> {:error, {:secret_file, name, reason}}
        end
    end
  end

  defp reject_live_key(nil, _env), do: {:ok, nil}

  defp reject_live_key(key, env) when is_binary(key) do
    live? = String.starts_with?(key, "sk_live_") or String.starts_with?(key, "rk_live_")

    if live? and Map.get(env, "ALLOW_LIVE") != "true" do
      {:error, :live_key_refused}
    else
      {:ok, key}
    end
  end

  defp parse_port(env) do
    case Map.get(env, "PORT", "4000") do
      port when is_binary(port) ->
        case Integer.parse(port) do
          {number, ""} when number > 0 and number < 65_536 -> {:ok, number}
          _ -> {:error, :invalid_port}
        end

      _ ->
        {:error, :invalid_port}
    end
  end

  defp parse_pool_size(env) do
    case Map.get(env, "POOL_SIZE", "10") do
      size when is_binary(size) ->
        case Integer.parse(size) do
          {number, ""} when number > 0 -> {:ok, number}
          _ -> {:ok, 10}
        end

      _ ->
        {:ok, 10}
    end
  end

  defp env_string(env, name, default) do
    case blank_to_nil(Map.get(env, name)) do
      nil -> default
      value -> value
    end
  end

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(_), do: nil
end
