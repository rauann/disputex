defmodule Disputex.Workers.IngestDisputeWorker do
  @moduledoc """
  Re-fetches a dispute from Stripe, upserts it, and moves a new dispute to `gathering`.
  """

  use Oban.Worker,
    queue: :default,
    max_attempts: 5,
    unique: [
      period: :infinity,
      states: :all,
      keys: [:event_id]
    ]

  alias Disputex.Disputes
  alias Disputex.Disputes.WebhookPayload
  alias Disputex.Payments

  @terminal [:live_mode_dispute, :missing_dispute_id, :unknown_event]

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"event_id" => event_id}}) do
    with {:ok, event} <- Disputes.fetch_webhook_event(event_id),
         {:ok, dispute_id} <- WebhookPayload.dispute_id(event.payload),
         {:ok, stripe_dispute} <- Payments.fetch_dispute(dispute_id),
         {:ok, _dispute} <- Disputes.ingest_stripe_dispute(stripe_dispute) do
      Disputes.mark_webhook_processed(event)
    else
      {:error, reason} when reason in @terminal ->
        maybe_mark(event_id)
        {:cancel, reason}

      {:error, %Ecto.Changeset{}} ->
        maybe_mark(event_id)
        {:cancel, :invalid_dispute}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp maybe_mark(event_id) do
    case Disputes.fetch_webhook_event(event_id) do
      {:ok, event} -> Disputes.mark_webhook_processed(event)
      _ -> :ok
    end
  end
end
