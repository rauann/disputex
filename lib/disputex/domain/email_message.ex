defmodule Disputex.Domain.EmailMessage do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "email_messages" do
    field :direction, Ecto.Enum, values: [:inbound, :outbound]
    field :sent_at, :utc_datetime_usec
    field :subject, :string
    field :body, :string

    belongs_to :booking, Disputex.Domain.Booking

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:direction, :sent_at, :subject, :body, :booking_id])
    |> validate_required([:direction, :sent_at, :subject, :body, :booking_id])
  end
end
