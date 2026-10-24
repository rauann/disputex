defmodule Disputex.Repo.Migrations.CreateDisputePipeline do
  use Ecto.Migration

  def change do
    create table(:disputes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :stripe_dispute_id, :string, null: false
      add :stripe_charge_id, :string
      add :payment_intent_id, :string
      add :amount, :integer, null: false
      add :currency, :string, null: false
      add :stripe_reason, :string
      add :stripe_status, :string, null: false
      add :evidence_due_by, :utc_datetime_usec
      add :state, :string, null: false, default: "received"
      add :outcome, :string
      add :case_summary, :text
      add :embedding, :vector, size: 1536
      add :livemode, :boolean, null: false, default: false
      add :booking_id, references(:bookings, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:disputes, [:stripe_dispute_id])
    create index(:disputes, [:stripe_charge_id])
    create index(:disputes, [:state])
    create index(:disputes, [:booking_id])

    create constraint(:disputes, :disputes_livemode_is_false, check: "livemode = false")

    create index(:disputes, ["embedding vector_cosine_ops"],
             name: :disputes_embedding_hnsw,
             using: :hnsw
           )

    create table(:webhook_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :stripe_event_id, :string, null: false
      add :type, :string, null: false
      add :payload, :map, null: false
      add :processed_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:webhook_events, [:stripe_event_id])

    create table(:agent_runs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :model, :string, null: false
      add :prompt_version, :string
      add :status, :string, null: false
      add :steps, :integer, null: false, default: 0
      add :input_tokens, :integer, null: false, default: 0
      add :output_tokens, :integer, null: false, default: 0
      add :cost_usd, :decimal
      add :latency_ms, :integer
      add :route, :string
      add :route_reason, :string
      add :trace_id, :string
      add :error, :text
      add :decision, :map

      add :dispute_id, references(:disputes, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:agent_runs, [:dispute_id])

    create table(:tool_calls, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :step, :integer, null: false
      add :name, :string, null: false
      add :args, :map, null: false, default: %{}
      add :source_refs, {:array, :string}, null: false, default: []
      add :duration_ms, :integer
      add :ok, :boolean, null: false, default: false

      add :agent_run_id, references(:agent_runs, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:tool_calls, [:agent_run_id])

    create table(:reviews, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :reviewer, :string, null: false
      add :verdict, :string, null: false
      add :diff, :map
      add :notes, :text

      add :dispute_id, references(:disputes, type: :binary_id, on_delete: :delete_all),
        null: false

      add :agent_run_id, references(:agent_runs, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime_usec)
    end

    create index(:reviews, [:dispute_id])

    create table(:submissions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :idempotency_key, :string, null: false
      add :evidence_payload, :map
      add :stripe_response, :map
      add :submitted_at, :utc_datetime_usec

      add :dispute_id, references(:disputes, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:submissions, [:idempotency_key])
    create index(:submissions, [:dispute_id])
  end
end
