defmodule Disputex.Disputes.AgentRun do
  @moduledoc """
  One analysis attempt. The typed decision embed arrives with the agent in milestone 2;
  `decision` is a map until then.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "agent_runs" do
    field :model, :string
    field :prompt_version, :string
    field :status, :string
    field :steps, :integer, default: 0
    field :input_tokens, :integer, default: 0
    field :output_tokens, :integer, default: 0
    field :cost_usd, :decimal
    field :latency_ms, :integer
    field :route, :string
    field :route_reason, :string
    field :trace_id, :string
    field :error, :string
    field :decision, :map

    belongs_to :dispute, Disputex.Disputes.Dispute
    has_many :tool_calls, Disputex.Disputes.ToolCall
    has_many :reviews, Disputex.Disputes.Review

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(run, attrs) do
    run
    |> cast(attrs, [
      :model,
      :prompt_version,
      :status,
      :steps,
      :input_tokens,
      :output_tokens,
      :cost_usd,
      :latency_ms,
      :route,
      :route_reason,
      :trace_id,
      :error,
      :decision,
      :dispute_id
    ])
    |> validate_required([:model, :status, :dispute_id])
  end
end
