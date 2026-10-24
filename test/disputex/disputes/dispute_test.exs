defmodule Disputex.Disputes.DisputeTest do
  use Disputex.DataCase, async: true

  alias Disputex.Disputes.Dispute

  test "state only moves along the pipeline" do
    dispute = dispute_fixture(%{state: :received})

    assert {:error, changeset} =
             dispute
             |> Dispute.transition_changeset(:submitted)
             |> Repo.update()

    assert "cannot transition from received to submitted" in errors_on(changeset).state
  end

  test "the embedding column accepts a 1536-d vector" do
    dispute = dispute_fixture()
    vector = Pgvector.new(List.duplicate(0.1, 1536))

    assert {:ok, updated} =
             dispute
             |> Ecto.Changeset.change(embedding: vector)
             |> Repo.update()

    assert Pgvector.to_list(updated.embedding) |> length() == 1536
  end
end
