defmodule Disputex.Health do
  @moduledoc """
  Release health check. `ok?/0` raises when Postgres is unreachable so
  `bin/disputex rpc` exits non-zero and the Docker healthcheck fails.
  """

  alias Disputex.Repo
  alias Ecto.Adapters.SQL

  @spec ok?() :: true
  def ok? do
    SQL.query!(Repo, "SELECT 1", [])
    true
  end
end
