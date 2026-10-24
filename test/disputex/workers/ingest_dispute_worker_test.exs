defmodule Disputex.Workers.IngestDisputeWorkerTest do
  use Disputex.DataCase, async: true

  import Mox

  alias Disputex.Disputes
  alias Disputex.Disputes.Dispute
  alias Disputex.Workers.{GatherEvidenceWorker, IngestDisputeWorker}

  setup :verify_on_exit!

  test "fetches the dispute, links the booking, and moves to gathering" do
    booking = booking_fixture(%{stripe_charge_id: "ch_link"})
    event = stripe_event("evt_ingest", "dp_ingest", "ch_link")
    assert {:ok, _} = Disputes.accept_webhook(event)

    expect(Disputex.Payments.Mock, :fetch_dispute, fn "dp_ingest" ->
      {:ok, stripe_dispute("dp_ingest", "ch_link")}
    end)

    assert :ok = perform_job(IngestDisputeWorker, %{event_id: "evt_ingest"})

    dispute = Repo.get_by!(Dispute, stripe_dispute_id: "dp_ingest")
    assert dispute.state == :gathering
    assert dispute.booking_id == booking.id
    assert dispute.amount == 41_800
    assert dispute.livemode == false
    assert dispute.stripe_reason == "fraudulent"

    stored = Disputes.fetch_webhook_event("evt_ingest") |> elem(1)
    assert stored.processed_at

    assert_enqueued(worker: GatherEvidenceWorker, args: %{"dispute_id" => dispute.id})
  end

  test "a live-mode dispute is cancelled and not stored" do
    event = stripe_event("evt_live", "dp_live", "ch_live")
    assert {:ok, _} = Disputes.accept_webhook(event)

    expect(Disputex.Payments.Mock, :fetch_dispute, fn "dp_live" ->
      {:ok, stripe_dispute("dp_live", "ch_live", %{livemode: true})}
    end)

    assert {:cancel, :live_mode_dispute} =
             perform_job(IngestDisputeWorker, %{event_id: "evt_live"})

    refute Repo.get_by(Dispute, stripe_dispute_id: "dp_live")
  end

  test "a later event refreshes stripe fields without leaving gathering" do
    _booking = booking_fixture(%{stripe_charge_id: "ch_again"})
    assert {:ok, _} = Disputes.accept_webhook(stripe_event("evt_a", "dp_again", "ch_again"))

    expect(Disputex.Payments.Mock, :fetch_dispute, fn "dp_again" ->
      {:ok, stripe_dispute("dp_again", "ch_again")}
    end)

    assert :ok = perform_job(IngestDisputeWorker, %{event_id: "evt_a"})
    dispute = Repo.get_by!(Dispute, stripe_dispute_id: "dp_again")

    assert {:ok, _} =
             dispute
             |> Dispute.case_summary_changeset("already gathered")
             |> Repo.update()

    assert {:ok, _} =
             Disputes.accept_webhook(
               stripe_event("evt_b", "dp_again", "ch_again", "charge.dispute.updated")
             )

    expect(Disputex.Payments.Mock, :fetch_dispute, fn "dp_again" ->
      {:ok, stripe_dispute("dp_again", "ch_again", %{amount: 1200, status: "under_review"})}
    end)

    assert :ok = perform_job(IngestDisputeWorker, %{event_id: "evt_b"})

    dispute = Repo.get_by!(Dispute, stripe_dispute_id: "dp_again")
    assert dispute.state == :gathering
    assert dispute.amount == 1200
    assert dispute.stripe_status == "under_review"
    assert dispute.case_summary == "already gathered"

    assert [_] = all_enqueued(worker: GatherEvidenceWorker)
  end

  test "won disputes close instead of gathering" do
    event = stripe_event("evt_won", "dp_won", "ch_won", "charge.dispute.closed")
    assert {:ok, _} = Disputes.accept_webhook(event)

    expect(Disputex.Payments.Mock, :fetch_dispute, fn "dp_won" ->
      {:ok, stripe_dispute("dp_won", "ch_won", %{status: "won"})}
    end)

    assert :ok = perform_job(IngestDisputeWorker, %{event_id: "evt_won"})

    dispute = Repo.get_by!(Dispute, stripe_dispute_id: "dp_won")
    assert dispute.state == :closed
    assert dispute.outcome == :won
    refute_enqueued(worker: GatherEvidenceWorker)
  end
end
