defmodule Disputex.Disputes.Review do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "reviews" do
    field :reviewer, :string
    field :verdict, Ecto.Enum, values: [:approved, :edited, :rejected, :accepted_dispute]
    field :diff, :map
    field :notes, :string

    belongs_to :dispute, Disputex.Disputes.Dispute
    belongs_to :agent_run, Disputex.Disputes.AgentRun

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(review, attrs) do
    review
    |> cast(attrs, [:reviewer, :verdict, :diff, :notes, :dispute_id, :agent_run_id])
    |> validate_required([:reviewer, :verdict, :dispute_id])
  end
end
