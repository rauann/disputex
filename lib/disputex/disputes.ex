defmodule Disputex.Disputes do
  @moduledoc """
  Dispute pipeline records: webhook intake, Stripe upsert, and case files.
  """

  alias Disputex.Disputes.{Dispute, WebhookEvent, WebhookPayload}
  alias Disputex.Domain.Booking
  alias Disputex.Repo
  alias Disputex.Workers.{GatherEvidenceWorker, IngestDisputeWorker}
  alias Ecto.Multi

  @replace_fields [
    :stripe_charge_id,
    :payment_intent_id,
    :amount,
    :currency,
    :stripe_reason,
    :stripe_status,
    :evidence_due_by,
    :updated_at
  ]

  @closed_statuses ~w(won lost)

  @doc """
  Insert a dispute webhook once and enqueue ingest in the same transaction.

  A retried delivery inserts nothing and enqueues nothing. Binary ids are
  generated in the changeset, so a conflict leaves `inserted.id` absent from
  the table; that mismatch is how a duplicate is recognized.
  """
  @spec accept_webhook(Stripe.Event.t()) :: {:ok, map()} | {:error, atom(), term(), map()}
  def accept_webhook(%Stripe.Event{type: "charge.dispute." <> _} = event) do
    changeset =
      WebhookEvent.changeset(%WebhookEvent{}, %{
        stripe_event_id: event.id,
        type: event.type,
        payload: WebhookPayload.to_map(event)
      })

    Multi.new()
    |> Multi.insert(:event, changeset, on_conflict: :nothing, conflict_target: :stripe_event_id)
    |> Multi.run(:job, fn repo, %{event: inserted} ->
      enqueue_if_new(repo, event.id, inserted)
    end)
    |> Repo.transaction()
  end

  def accept_webhook(%Stripe.Event{}), do: {:ok, %{job: :ignored}}

  @doc "Load the stored webhook row for an Oban job."
  @spec fetch_webhook_event(String.t()) :: {:ok, WebhookEvent.t()} | {:error, :unknown_event}
  def fetch_webhook_event(stripe_event_id) do
    case Repo.get_by(WebhookEvent, stripe_event_id: stripe_event_id) do
      nil -> {:error, :unknown_event}
      event -> {:ok, event}
    end
  end

  @doc "Upsert a normalized Stripe dispute, link the booking, and gather when new."
  @spec ingest_stripe_dispute(map()) :: {:ok, Dispute.t()} | {:error, term()}
  def ingest_stripe_dispute(attrs) when is_map(attrs) do
    with :ok <- ensure_test_mode(attrs) do
      Repo.transaction(fn ->
        attrs
        |> upsert_dispute!()
        |> link_booking()
        |> advance!(attrs.status)
        |> maybe_enqueue_gather!()
      end)
    end
  end

  @spec mark_webhook_processed(WebhookEvent.t()) :: :ok
  def mark_webhook_processed(%WebhookEvent{} = event) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    event
    |> Ecto.Changeset.change(processed_at: now)
    |> Repo.update!()

    :ok
  end

  @spec save_case_summary(Dispute.t(), String.t()) ::
          {:ok, Dispute.t()} | {:error, Ecto.Changeset.t()}
  def save_case_summary(%Dispute{} = dispute, summary) when is_binary(summary) do
    dispute
    |> Dispute.case_summary_changeset(summary)
    |> Repo.update()
  end

  defp enqueue_if_new(repo, stripe_event_id, inserted) do
    stored = repo.get_by(WebhookEvent, stripe_event_id: stripe_event_id)

    cond do
      match?(%WebhookEvent{id: id} when not is_nil(id), stored) and stored.id == inserted.id ->
        Oban.insert(IngestDisputeWorker.new(%{event_id: stripe_event_id}))

      match?(%WebhookEvent{}, stored) ->
        {:ok, :duplicate}

      true ->
        {:error, :event_not_persisted}
    end
  end

  defp ensure_test_mode(%{livemode: false}), do: :ok
  defp ensure_test_mode(_attrs), do: {:error, :live_mode_dispute}

  defp upsert_dispute!(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    changeset =
      %Dispute{}
      |> Dispute.create_changeset(%{
        stripe_dispute_id: attrs.id,
        stripe_charge_id: attrs.charge_id,
        payment_intent_id: attrs.payment_intent_id,
        amount: attrs.amount,
        currency: attrs.currency,
        stripe_reason: attrs.reason,
        stripe_status: attrs.status,
        evidence_due_by: attrs.evidence_due_by,
        livemode: false,
        state: :received
      })
      |> Ecto.Changeset.force_change(:updated_at, now)

    case Repo.insert(changeset,
           on_conflict: {:replace, @replace_fields},
           conflict_target: :stripe_dispute_id,
           returning: true
         ) do
      {:ok, dispute} -> dispute
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end

  defp link_booking(%Dispute{booking_id: id} = dispute) when not is_nil(id), do: dispute

  defp link_booking(%Dispute{stripe_charge_id: charge_id} = dispute) when is_binary(charge_id) do
    case Repo.get_by(Booking, stripe_charge_id: charge_id) do
      nil ->
        dispute

      booking ->
        dispute
        |> Ecto.Changeset.change(booking_id: booking.id)
        |> Repo.update!()
    end
  end

  defp link_booking(dispute), do: dispute

  defp advance!(%Dispute{state: :closed} = dispute, status) when status in @closed_statuses do
    outcome = String.to_existing_atom(status)

    if dispute.outcome == outcome do
      dispute
    else
      dispute
      |> Ecto.Changeset.change(outcome: outcome)
      |> Repo.update!()
    end
  end

  defp advance!(dispute, status) when status in @closed_statuses do
    transition!(dispute, :closed, %{outcome: String.to_existing_atom(status)})
  end

  defp advance!(%Dispute{state: :received} = dispute, _status) do
    transition!(dispute, :gathering, %{})
  end

  defp advance!(dispute, _status), do: dispute

  defp transition!(dispute, state, extra) do
    case dispute |> Dispute.transition_changeset(state, extra) |> Repo.update() do
      {:ok, dispute} -> dispute
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end

  defp maybe_enqueue_gather!(%Dispute{state: :gathering, case_summary: nil} = dispute) do
    case Oban.insert(GatherEvidenceWorker.new(%{dispute_id: dispute.id})) do
      {:ok, _job} -> dispute
      {:error, reason} -> Repo.rollback(reason)
    end
  end

  defp maybe_enqueue_gather!(dispute), do: dispute
end
