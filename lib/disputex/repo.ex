defmodule Disputex.Repo do
  use Ecto.Repo,
    otp_app: :disputex,
    adapter: Ecto.Adapters.Postgres
end
