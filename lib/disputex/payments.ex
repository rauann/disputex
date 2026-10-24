defmodule Disputex.Payments do
  @moduledoc """
  Stripe dispute reads. Production uses `Disputex.Payments.Stripe`; tests swap in a Mox mock.

  `fetch_dispute/1` returns a normalized map so the rest of the pipeline does
  not depend on Stripe structs.
  """

  @type dispute :: %{
          required(:id) => String.t(),
          required(:charge_id) => String.t() | nil,
          required(:payment_intent_id) => String.t() | nil,
          required(:amount) => integer(),
          required(:currency) => String.t(),
          required(:reason) => String.t() | nil,
          required(:status) => String.t(),
          required(:evidence_due_by) => DateTime.t() | nil,
          required(:livemode) => boolean()
        }

  @callback fetch_dispute(String.t()) :: {:ok, dispute()} | {:error, term()}

  @spec fetch_dispute(String.t()) :: {:ok, dispute()} | {:error, term()}
  def fetch_dispute(id) when is_binary(id) do
    impl().fetch_dispute(id)
  end

  @spec impl() :: module()
  def impl do
    Application.get_env(:disputex, :payments, Disputex.Payments.Stripe)
  end
end
