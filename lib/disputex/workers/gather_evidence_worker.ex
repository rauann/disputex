defmodule Disputex.Workers.GatherEvidenceWorker do
  @moduledoc """
  Builds the case file for a dispute in `gathering` and stores the redacted summary.

  The embedding column stays empty. Milestone 2 fills it from the redacted summary.
  """

  use Oban.Worker,
    queue: :default,
    max_attempts: 5,
    unique: [
      period: :infinity,
      states: [:available, :scheduled, :executing, :retryable],
      keys: [:dispute_id]
    ]

  alias Disputex.Disputes
  alias Disputex.Disputes.{CaseFile, Dispute}
  alias Disputex.Privacy.Redactor
  alias Disputex.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"dispute_id" => dispute_id}}) do
    case Repo.get(Dispute, dispute_id) do
      nil ->
        {:cancel, :dispute_missing}

      %Dispute{state: state} when state != :gathering ->
        {:cancel, :not_gathering}

      dispute ->
        dispute = Repo.preload(dispute, booking: [:customer, :stay, :cancellation_policy])
        file = CaseFile.build(dispute)

        with {:ok, summary} <-
               Redactor.redact(file.text, dispute_id: dispute.id, names: file.names),
             {:ok, _dispute} <- Disputes.save_case_summary(dispute, summary) do
          # Milestone 2 embeds `summary` and writes disputes.embedding.
          :ok
        end
    end
  end
end
