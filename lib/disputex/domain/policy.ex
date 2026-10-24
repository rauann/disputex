defmodule Disputex.Domain.Policy do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "policies" do
    field :kind, Ecto.Enum, values: [:cancellation, :refund, :terms]
    field :version, :string
    field :body, :string

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(policy, attrs) do
    policy
    |> cast(attrs, [:kind, :version, :body])
    |> validate_required([:kind, :version, :body])
  end
end
