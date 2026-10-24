defmodule Disputex.Privacy.VaultEntry do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "pii_vault" do
    field :token, :string
    field :ciphertext, :binary

    belongs_to :dispute, Disputex.Disputes.Dispute

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:token, :ciphertext, :dispute_id])
    |> validate_required([:token, :ciphertext, :dispute_id])
    |> unique_constraint([:dispute_id, :token])
  end
end
