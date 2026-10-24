defmodule Disputex.Domain.AccessLog do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "access_logs" do
    field :event, Ecto.Enum, values: [:login, :booking_created, :voucher_opened]
    field :ip, :string
    field :user_agent, :string
    field :device_fingerprint, :string
    field :at, :utc_datetime_usec

    belongs_to :customer, Disputex.Domain.Customer

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [:event, :ip, :user_agent, :device_fingerprint, :at, :customer_id])
    |> validate_required([:event, :ip, :user_agent, :device_fingerprint, :at, :customer_id])
  end
end
