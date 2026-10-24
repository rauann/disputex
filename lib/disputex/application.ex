defmodule Disputex.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        DisputexWeb.Telemetry,
        Disputex.Repo,
        oban(),
        {DNSCluster, query: Application.get_env(:disputex, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: Disputex.PubSub},
        DisputexWeb.Endpoint
      ]
      |> List.flatten()

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Disputex.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DisputexWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  # `bin/start` sets this for migrate and seed. Oban queries its tables on
  # boot, and those tables do not exist until `Release.migrate/0` finishes.
  defp oban do
    if System.get_env("DISPUTEX_SKIP_OBAN") == "true" do
      []
    else
      [{Oban, Application.fetch_env!(:disputex, Oban)}]
    end
  end
end
