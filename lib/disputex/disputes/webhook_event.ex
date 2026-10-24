defmodule Disputex.Disputes.WebhookEvent do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "webhook_events" do
    field :stripe_event_id, :string
    field :type, :string
    field :payload, :map
    field :processed_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:stripe_event_id, :type, :payload, :processed_at])
    |> validate_required([:stripe_event_id, :type, :payload])
    |> unique_constraint(:stripe_event_id)
  end
end
