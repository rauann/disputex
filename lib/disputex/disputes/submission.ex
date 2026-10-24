defmodule Disputex.Disputes.Submission do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "submissions" do
    field :idempotency_key, :string
    field :evidence_payload, :map
    field :stripe_response, :map
    field :submitted_at, :utc_datetime_usec

    belongs_to :dispute, Disputex.Disputes.Dispute

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(submission, attrs) do
    submission
    |> cast(attrs, [
      :idempotency_key,
      :evidence_payload,
      :stripe_response,
      :submitted_at,
      :dispute_id
    ])
    |> validate_required([:idempotency_key, :dispute_id])
    |> unique_constraint(:idempotency_key)
  end
end
