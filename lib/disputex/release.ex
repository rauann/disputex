defmodule Disputex.Release do
  @moduledoc """
  Tasks the release entrypoint runs before the server starts.
  """

  alias Disputex.Domain
  alias Disputex.Domain.Seeds

  @app :disputex

  @doc """
  Creates the `vector` extension and runs pending migrations.
  """
  @spec migrate() :: :ok
  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn repo ->
          repo.query!("CREATE EXTENSION IF NOT EXISTS vector", [])
          Ecto.Migrator.run(repo, :up, all: true)
        end)
    end

    :ok
  end

  @doc """
  Seeds the fake domain once, when it has no bookings and `DEMO_SEED=true`
  is handled by the caller.
  """
  @spec seed_if_empty() :: :ok
  def seed_if_empty do
    load_app()

    {:ok, _, _} =
      Ecto.Migrator.with_repo(Disputex.Repo, fn _repo ->
        if Domain.empty?() do
          {:ok, _} = Seeds.insert!()
        end

        :ok
      end)

    :ok
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
