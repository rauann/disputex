defmodule Disputex.Domain.Booking do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "bookings" do
    field :ref, :string
    field :hotel, :string
    field :check_in, :date
    field :check_out, :date
    field :amount, :integer
    field :status, Ecto.Enum, values: [:confirmed, :cancelled, :completed, :no_show]
    field :stripe_charge_id, :string
    field :refund_status, Ecto.Enum, values: [:none, :pending, :partial, :full]
    field :policy_accepted_at, :utc_datetime_usec

    belongs_to :customer, Disputex.Domain.Customer
    belongs_to :cancellation_policy, Disputex.Domain.Policy
    has_one :stay, Disputex.Domain.Stay
    has_many :email_messages, Disputex.Domain.EmailMessage
    has_many :disputes, Disputex.Disputes.Dispute

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(booking, attrs) do
    booking
    |> cast(attrs, [
      :ref,
      :hotel,
      :check_in,
      :check_out,
      :amount,
      :status,
      :stripe_charge_id,
      :refund_status,
      :policy_accepted_at,
      :customer_id,
      :cancellation_policy_id
    ])
    |> validate_required([
      :ref,
      :hotel,
      :check_in,
      :check_out,
      :amount,
      :status,
      :stripe_charge_id,
      :refund_status,
      :policy_accepted_at,
      :customer_id,
      :cancellation_policy_id
    ])
    |> validate_number(:amount, greater_than: 0)
    |> validate_dates()
    |> unique_constraint(:ref)
    |> unique_constraint(:stripe_charge_id)
  end

  defp validate_dates(changeset) do
    check_in = get_field(changeset, :check_in)
    check_out = get_field(changeset, :check_out)

    if check_in && check_out && Date.compare(check_out, check_in) != :gt do
      add_error(changeset, :check_out, "must be after check in")
    else
      changeset
    end
  end
end
