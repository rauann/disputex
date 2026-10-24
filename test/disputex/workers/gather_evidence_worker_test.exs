defmodule Disputex.Workers.GatherEvidenceWorkerTest do
  use Disputex.DataCase, async: true

  alias Disputex.Disputes.Dispute
  alias Disputex.Privacy.Redactor
  alias Disputex.Privacy.VaultEntry
  alias Disputex.Workers.GatherEvidenceWorker

  test "builds a redacted case file and stays in gathering" do
    customer =
      customer_fixture(%{
        name: "Ada Lovelace",
        email: "ada@example.test",
        phone: "+1 415 555 0100"
      })

    booking = booking_fixture(%{customer: customer, stripe_charge_id: "ch_case"})

    dispute =
      dispute_fixture(%{
        stripe_dispute_id: "dp_case",
        stripe_charge_id: "ch_case",
        booking_id: booking.id,
        state: :gathering,
        evidence_due_by: ~U[2026-12-01 00:00:00Z]
      })

    assert :ok = perform_job(GatherEvidenceWorker, %{dispute_id: dispute.id})

    dispute = Repo.reload!(dispute)
    assert dispute.state == :gathering
    assert dispute.case_summary =~ "BK-"
    assert dispute.case_summary =~ "<NAME_1>"
    assert dispute.case_summary =~ "<EMAIL_1>"
    assert dispute.case_summary =~ "<PHONE_1>"
    refute dispute.case_summary =~ "Ada Lovelace"
    refute dispute.case_summary =~ "ada@example.test"
    refute dispute.case_summary =~ "+1 415 555 0100"
    refute dispute.case_summary =~ "203.0.113"
    assert dispute.embedding == nil

    assert Repo.aggregate(
             from(entry in VaultEntry, where: entry.dispute_id == ^dispute.id),
             :count
           ) >= 3

    assert {:ok, plain} = Redactor.rehydrate(dispute.case_summary, dispute.id)
    assert plain =~ "Ada Lovelace"
    assert plain =~ "ada@example.test"
    assert plain =~ "+1 415 555 0100"
  end

  test "does not gather a dispute that is not in gathering" do
    dispute = dispute_fixture(%{state: :received})

    assert {:cancel, :not_gathering} =
             perform_job(GatherEvidenceWorker, %{dispute_id: dispute.id})

    assert Repo.reload!(dispute).case_summary == nil
  end

  test "livemode true cannot be stored" do
    assert_raise Ecto.ConstraintError, ~r/disputes_livemode_is_false/, fn ->
      Repo.insert!(%Dispute{
        stripe_dispute_id: "dp_live_raw",
        amount: 100,
        currency: "usd",
        stripe_status: "needs_response",
        state: :received,
        livemode: true
      })
    end
  end
end
