defmodule DisputexWeb.StripeHandler do
  @moduledoc """
  Persists `charge.dispute.*` events and enqueues ingest. Other events are acknowledged.
  """

  @behaviour Stripe.WebhookHandler

  require Logger

  alias Disputex.Disputes

  @doc "Webhook secret for `Stripe.WebhookPlug`. Empty rejects the signature instead of crashing."
  @spec webhook_secret() :: String.t()
  def webhook_secret do
    Application.get_env(:disputex, :stripe_webhook_secret) || ""
  end

  @impl Stripe.WebhookHandler
  def handle_event(%Stripe.Event{type: "charge.dispute." <> _} = event) do
    case Disputes.accept_webhook(event) do
      {:ok, %{job: :duplicate}} ->
        Logger.info("stripe webhook duplicate id=#{event.id}")
        :ok

      {:ok, _} ->
        Logger.info("stripe webhook accepted id=#{event.id} type=#{event.type}")
        :ok

      {:error, _step, %Ecto.Changeset{}, _} ->
        {:error, :invalid_event}

      {:error, _step, reason, _} when is_atom(reason) ->
        {:error, reason}

      {:error, _step, _reason, _} ->
        {:error, :persist_failed}
    end
  end

  def handle_event(%Stripe.Event{} = event) do
    Logger.debug("stripe webhook ignored type=#{event.type}")
    :ok
  end
end
