defmodule Disputex.ConfigTest do
  use ExUnit.Case, async: true

  alias Disputex.Config

  test "refuses sk_live_ and rk_live_ keys" do
    assert {:error, :live_key_refused} = Config.load(%{"STRIPE_SECRET_KEY" => "sk_live_abc"})
    assert {:error, :live_key_refused} = Config.load(%{"STRIPE_SECRET_KEY" => "rk_live_abc"})
  end

  test "allows a live key only when ALLOW_LIVE=true" do
    assert {:ok, cfg} =
             Config.load(%{"STRIPE_SECRET_KEY" => "sk_live_abc", "ALLOW_LIVE" => "true"})

    assert cfg.stripe_secret_key == "sk_live_abc"
    assert cfg.allow_live
  end

  test "accepts a test key and leaves a blank key unset" do
    assert {:ok, cfg} = Config.load(%{"STRIPE_SECRET_KEY" => "sk_test_abc"})
    assert cfg.stripe_secret_key == "sk_test_abc"

    assert {:ok, empty} = Config.load(%{"STRIPE_SECRET_KEY" => "  "})
    assert empty.stripe_secret_key == nil
  end

  test "*_FILE wins over the env value and is trimmed" do
    path = tmp("vault-key")
    File.write!(path, "  from-file \n")

    assert {:ok, cfg} =
             Config.load(%{"VAULT_KEY_FILE" => path, "VAULT_KEY" => "from-env"})

    assert cfg.vault_key == "from-file"
  end

  test "a live key in a secret file is refused" do
    path = tmp("stripe-key")
    File.write!(path, "sk_live_from_file\n")

    assert {:error, :live_key_refused} = Config.load(%{"STRIPE_SECRET_KEY_FILE" => path})
  end

  test "a missing secret file is an error and does not include the secret" do
    assert {:error, {:secret_file, "VAULT_KEY", :enoent}} =
             Config.load(%{"VAULT_KEY_FILE" => "/tmp/disputex-missing-secret"})
  end

  test "rejects a bad PORT" do
    assert {:error, :invalid_port} = Config.load(%{"PORT" => "nope"})
  end

  test "picks the LLM key for the provider and inspect hides it" do
    assert {:ok, cfg} =
             Config.load(%{
               "LLM_PROVIDER" => "anthropic",
               "ANTHROPIC_API_KEY" => "ant-secret",
               "OPENROUTER_API_KEY" => "or-secret"
             })

    assert Config.llm_api_key(cfg) == "ant-secret"
    refute inspect(cfg) =~ "ant-secret"
    refute inspect(cfg) =~ "or-secret"
  end

  test "validate_prod! requires a 32-byte vault key" do
    assert {:ok, cfg} =
             Config.load(%{
               "DATABASE_URL" => "ecto://disputex:disputex@db/disputex",
               "SECRET_KEY_BASE" => String.duplicate("a", 64),
               "VAULT_KEY" => "not-valid",
               "STRIPE_SECRET_KEY" => "sk_test_x",
               "STRIPE_WEBHOOK_SECRET" => "whsec_x"
             })

    assert_raise RuntimeError, ~r/VAULT_KEY/, fn ->
      Config.validate_prod!(cfg)
    end
  end

  defp tmp(name) do
    path = Path.join(System.tmp_dir!(), "disputex-#{name}-#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm(path) end)
    path
  end
end
