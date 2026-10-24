defmodule Disputex.Domain.Stay do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "stays" do
    field :checked_in_at, :utc_datetime_usec
    field :checked_out_at, :utc_datetime_usec
    field :id_verified, :boolean, default: false
    field :room_charges, :integer, default: 0

    belongs_to :booking, Disputex.Domain.Booking

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(stay, attrs) do
    stay
    |> cast(attrs, [:checked_in_at, :checked_out_at, :id_verified, :room_charges, :booking_id])
    |> validate_required([:id_verified, :room_charges, :booking_id])
    |> validate_number(:room_charges, greater_than_or_equal_to: 0)
    |> unique_constraint(:booking_id)
  end
end
