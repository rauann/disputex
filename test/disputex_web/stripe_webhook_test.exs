defmodule DisputexWeb.StripeWebhookTest do
  use DisputexWeb.ConnCase, async: true

  alias Disputex.Disputes
  alias Disputex.Disputes.WebhookEvent
  alias Disputex.Workers.IngestDisputeWorker

  test "a signed dispute event is stored once and enqueues ingest", %{conn: conn} do
    payload = event_payload("evt_valid", "charge.dispute.created", "dp_valid")

    conn = post_signed(conn, payload)

    assert conn.status == 200
    assert Repo.aggregate(WebhookEvent, :count) == 1

    event = Repo.get_by!(WebhookEvent, stripe_event_id: "evt_valid")
    assert event.type == "charge.dispute.created"
    assert event.payload["data"]["object"]["id"] == "dp_valid"
    refute Jason.encode!(event.payload) =~ "secret-cardholder@example.com"

    assert [_] = all_enqueued(worker: IngestDisputeWorker, args: %{"event_id" => "evt_valid"})
  end

  test "an invalid signature is rejected and stores nothing", %{conn: conn} do
    payload = event_payload("evt_bad", "charge.dispute.created", "dp_bad")

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("stripe-signature", "t=#{System.system_time(:second)},v1=deadbeef")
      |> post("/webhooks/stripe", payload)

    assert conn.status == 400
    assert Repo.aggregate(WebhookEvent, :count) == 0
    refute_enqueued(worker: IngestDisputeWorker)
  end

  test "a duplicate event does not insert another row or job", %{conn: conn} do
    payload = event_payload("evt_dup", "charge.dispute.updated", "dp_dup")

    assert post_signed(conn, payload).status == 200
    assert post_signed(build_conn(), payload).status == 200

    assert Repo.aggregate(WebhookEvent, :count) == 1
    assert [_] = all_enqueued(worker: IngestDisputeWorker)

    event = stripe_event("evt_dup", "dp_dup", "ch_dup", "charge.dispute.updated")
    assert {:ok, %{job: :duplicate}} = Disputes.accept_webhook(event)
  end

  test "events outside charge.dispute.* are acknowledged and ignored", %{conn: conn} do
    payload = event_payload("evt_other", "charge.succeeded", "ch_other")

    assert post_signed(conn, payload).status == 200
    assert Repo.aggregate(WebhookEvent, :count) == 0
    refute_enqueued(worker: IngestDisputeWorker)
  end

  defp post_signed(conn, payload) do
    conn
    |> put_req_header("content-type", "application/json")
    |> put_req_header("stripe-signature", sign_stripe(payload))
    |> post("/webhooks/stripe", payload)
  end

  defp event_payload(id, type, object_id) do
    Jason.encode!(%{
      id: id,
      object: "event",
      type: type,
      api_version: "2024-06-20",
      created: System.system_time(:second),
      livemode: false,
      pending_webhooks: 1,
      request: %{id: nil, idempotency_key: nil},
      data: %{
        object: %{
          id: object_id,
          object: if(type == "charge.succeeded", do: "charge", else: "dispute"),
          amount: 41_800,
          currency: "usd",
          charge: "ch_from_payload",
          reason: "fraudulent",
          status: "needs_response",
          livemode: false,
          evidence: %{customer_email_address: "secret-cardholder@example.com"}
        }
      }
    })
  end
end
