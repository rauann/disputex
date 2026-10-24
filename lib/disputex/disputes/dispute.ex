defmodule Disputex.Disputes.Dispute do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @states ~w(
    received gathering analyzing needs_review approved
    submitting submitted accepted closed failed
  )a
  @outcomes ~w(won lost)a

  @transitions %{
    received: [:gathering, :closed, :failed],
    gathering: [:analyzing, :closed, :failed],
    analyzing: [:needs_review, :approved, :closed, :failed],
    needs_review: [:approved, :accepted, :closed, :failed],
    approved: [:submitting, :closed, :failed],
    submitting: [:submitted, :failed, :closed],
    submitted: [:closed],
    accepted: [:closed],
    closed: [],
    failed: [:gathering, :closed]
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "disputes" do
    field :stripe_dispute_id, :string
    field :stripe_charge_id, :string
    field :payment_intent_id, :string
    field :amount, :integer
    field :currency, :string
    field :stripe_reason, :string
    field :stripe_status, :string
    field :evidence_due_by, :utc_datetime_usec
    field :state, Ecto.Enum, values: @states, default: :received
    field :outcome, Ecto.Enum, values: @outcomes
    field :case_summary, :string
    field :embedding, Pgvector.Ecto.Vector
    field :livemode, :boolean, default: false

    belongs_to :booking, Disputex.Domain.Booking
    has_many :agent_runs, Disputex.Disputes.AgentRun
    has_many :reviews, Disputex.Disputes.Review
    has_many :submissions, Disputex.Disputes.Submission
    has_many :vault_entries, Disputex.Privacy.VaultEntry

    timestamps(type: :utc_datetime_usec)
  end

  def states, do: @states
  def outcomes, do: @outcomes

  def create_changeset(dispute, attrs) do
    dispute
    |> cast(attrs, [
      :stripe_dispute_id,
      :stripe_charge_id,
      :payment_intent_id,
      :amount,
      :currency,
      :stripe_reason,
      :stripe_status,
      :evidence_due_by,
      :livemode,
      :state,
      :booking_id
    ])
    |> validate_required([:stripe_dispute_id, :amount, :currency, :stripe_status, :state])
    |> update_change(:currency, &downcase/1)
    |> validate_length(:currency, is: 3)
    |> validate_number(:amount, greater_than_or_equal_to: 0)
    |> validate_inclusion(:livemode, [false])
    |> truncate_due()
    |> unique_constraint(:stripe_dispute_id)
    |> check_constraint(:livemode, name: :disputes_livemode_is_false, message: "must be false")
  end

  def transition_changeset(dispute, new_state, extra \\ %{}) do
    allowed = Map.get(@transitions, dispute.state, [])

    changeset =
      dispute
      |> cast(extra, [:outcome])
      |> put_change(:state, new_state)
      |> maybe_require_outcome()

    if new_state in allowed do
      changeset
    else
      add_error(changeset, :state, "cannot transition from #{dispute.state} to #{new_state}")
    end
  end

  def case_summary_changeset(dispute, summary) do
    dispute
    |> change(case_summary: summary)
    |> validate_required([:case_summary])
  end

  defp maybe_require_outcome(changeset) do
    if get_field(changeset, :state) == :closed do
      validate_required(changeset, [:outcome])
    else
      changeset
    end
  end

  defp truncate_due(changeset) do
    case get_change(changeset, :evidence_due_by) do
      %DateTime{} = due ->
        put_change(changeset, :evidence_due_by, DateTime.truncate(due, :microsecond))

      _ ->
        changeset
    end
  end

  defp downcase(currency) when is_binary(currency), do: String.downcase(currency)
  defp downcase(other), do: other
end
