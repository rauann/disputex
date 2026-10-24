defmodule Disputex.Fixtures do
  @moduledoc false

  alias Disputex.Disputes.Dispute
  alias Disputex.Domain.{Booking, Customer, Policy}
  alias Disputex.Repo

  def policy_fixture(attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          kind: :cancellation,
          version: "v1",
          body: "Free cancellation until 48 hours before check-in."
        },
        attrs
      )

    %Policy{}
    |> Policy.changeset(attrs)
    |> Repo.insert!()
  end

  def customer_fixture(attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          name: "Ada Lovelace",
          email: "ada@example.test",
          phone: "+1 415 555 0100",
          country: "GB",
          account_created_at: ~U[2024-01-01 00:00:00.000000Z],
          prior_bookings_count: 2
        },
        attrs
      )

    %Customer{}
    |> Customer.changeset(attrs)
    |> Repo.insert!()
  end

  def booking_fixture(attrs \\ %{}) do
    customer = attrs[:customer] || customer_fixture()
    policy = attrs[:policy] || policy_fixture()

    defaults = %{
      ref: "BK-#{System.unique_integer([:positive])}",
      hotel: "Harbor House",
      check_in: ~D[2026-09-02],
      check_out: ~D[2026-09-05],
      amount: 41_800,
      status: :completed,
      stripe_charge_id: "ch_#{System.unique_integer([:positive])}",
      refund_status: :none,
      policy_accepted_at: ~U[2026-08-01 12:00:00.000000Z],
      customer_id: customer.id,
      cancellation_policy_id: policy.id
    }

    attrs = Map.merge(defaults, Map.drop(attrs, [:customer, :policy]))

    %Booking{}
    |> Booking.changeset(attrs)
    |> Repo.insert!()
    |> Repo.preload(:customer)
  end

  def dispute_fixture(attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          stripe_dispute_id: "dp_#{System.unique_integer([:positive])}",
          amount: 41_800,
          currency: "usd",
          stripe_reason: "fraudulent",
          stripe_status: "needs_response",
          state: :received,
          livemode: false
        },
        attrs
      )

    %Dispute{}
    |> Dispute.create_changeset(attrs)
    |> Repo.insert!()
  end

  def stripe_dispute(id, charge_id, overrides \\ %{}) do
    Map.merge(
      %{
        id: id,
        charge_id: charge_id,
        payment_intent_id: "pi_#{id}",
        amount: 41_800,
        currency: "usd",
        reason: "fraudulent",
        status: "needs_response",
        evidence_due_by: ~U[2026-12-01 00:00:00Z],
        livemode: false
      },
      overrides
    )
  end

  def stripe_event(event_id, dispute_id, charge_id, type \\ "charge.dispute.created") do
    %Stripe.Event{
      id: event_id,
      type: type,
      livemode: false,
      created: 1_700_000_000,
      data: %{
        object: %{
          id: dispute_id,
          object: "dispute",
          charge: charge_id,
          amount: 41_800,
          currency: "usd",
          reason: "fraudulent",
          status: "needs_response",
          livemode: false,
          evidence: %{"customer_email_address" => "secret-cardholder@example.com"}
        }
      }
    }
  end

  def sign_stripe(payload, secret \\ nil, timestamp \\ nil) do
    secret = secret || Application.get_env(:disputex, :stripe_webhook_secret)
    timestamp = timestamp || System.system_time(:second)
    digest = :crypto.mac(:hmac, :sha256, secret, "#{timestamp}.#{payload}")
    signature = Base.encode16(digest, case: :lower)
    "t=#{timestamp},v1=#{signature}"
  end
end
