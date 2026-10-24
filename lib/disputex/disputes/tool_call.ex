defmodule Disputex.Disputes.ToolCall do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "tool_calls" do
    field :step, :integer
    field :name, :string
    field :args, :map, default: %{}
    field :source_refs, {:array, :string}, default: []
    field :duration_ms, :integer
    field :ok, :boolean, default: false

    belongs_to :agent_run, Disputex.Disputes.AgentRun

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(call, attrs) do
    call
    |> cast(attrs, [:step, :name, :args, :source_refs, :duration_ms, :ok, :agent_run_id])
    |> validate_required([:step, :name, :agent_run_id])
  end
end
