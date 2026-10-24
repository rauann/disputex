defmodule Disputex.Domain.Customer do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "customers" do
    field :name, :string
    field :email, :string
    field :phone, :string
    field :country, :string
    field :account_created_at, :utc_datetime_usec
    field :prior_bookings_count, :integer

    has_many :bookings, Disputex.Domain.Booking
    has_many :access_logs, Disputex.Domain.AccessLog

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(customer, attrs) do
    customer
    |> cast(attrs, [:name, :email, :phone, :country, :account_created_at, :prior_bookings_count])
    |> validate_required([
      :name,
      :email,
      :phone,
      :country,
      :account_created_at,
      :prior_bookings_count
    ])
    |> validate_number(:prior_bookings_count, greater_than_or_equal_to: 0)
  end
end
